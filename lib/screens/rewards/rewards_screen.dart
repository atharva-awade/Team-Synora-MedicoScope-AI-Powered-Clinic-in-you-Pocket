import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/providers/auth_provider.dart';
import 'package:medicoscope/core/providers/coins_provider.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/core/locale/locale_provider.dart';
import 'package:medicoscope/core/locale/app_strings.dart';
import 'package:medicoscope/services/mental_health_service.dart';
import 'package:medicoscope/screens/rewards/reward_content_screen.dart';
import 'package:provider/provider.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _coinGlowController;

  @override
  void initState() {
    super.initState();
    _coinGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _coinGlowController.dispose();
    super.dispose();
  }

  void _showRedeemDialog({
    required String title,
    required int cost,
    required String description,
    required IconData icon,
    required String rewardType,
    required List<Color> gradient,
  }) {
    final coinsProvider = Provider.of<CoinsProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;
    final lang =
        Provider.of<LocaleProvider>(context, listen: false).languageCode;
    final canAfford = coinsProvider.totalCoins >= cost;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
        title: Row(
          children: [
            Icon(icon, color: const Color(0xFFFFA000), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                  )),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
                )),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.stars_rounded,
                    color: Color(0xFFFFD700), size: 18),
                const SizedBox(width: 6),
                Text(
                  '$cost ${AppStrings.get('coins', lang)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: canAfford ? const Color(0xFFFFA000) : Colors.red,
                  ),
                ),
                if (!canAfford) ...[
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.format('need_more', lang,
                        {'count': '${cost - coinsProvider.totalCoins}'}),
                    style: TextStyle(fontSize: 11, color: Colors.red.shade300),
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.get('cancel', lang),
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
                )),
          ),
          ElevatedButton(
            onPressed: canAfford
                ? () {
                    Navigator.pop(ctx);
                    _processRedemption(
                      title: title,
                      cost: cost,
                      rewardType: rewardType,
                      icon: icon,
                      gradient: gradient,
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFA000),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(AppStrings.get('redeem', lang)),
          ),
        ],
      ),
    );
  }

  Future<void> _processRedemption({
    required String title,
    required int cost,
    required String rewardType,
    required IconData icon,
    required List<Color> gradient,
  }) async {
    final coinsProvider = Provider.of<CoinsProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final lang =
        Provider.of<LocaleProvider>(context, listen: false).languageCode;
    final patientName = authProvider.user?.name ?? 'User';

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkCard
              : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              const SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFA000)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppStrings.format('generating_reward', lang, {'title': title}),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkTextLight
                      : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppStrings.get('personalized_for_you', lang),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkTextGray
                      : AppTheme.textGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final content = await MentalHealthService.redeemReward(
        rewardType: rewardType,
        patientName: patientName,
      );

      // Deduct coins only after successful generation
      await coinsProvider.spendCoins(cost);

      // Save claimed reward to DB for history
      await MentalHealthService.saveClaimedReward(
        token: authProvider.token ?? '',
        rewardType: rewardType,
        title: title,
        content: content,
        coinsCost: cost,
      );

      // Dismiss loading dialog
      if (mounted) Navigator.pop(context);

      // Navigate to content screen
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RewardContentScreen(
              title: title,
              content: content,
              icon: icon,
              gradient: gradient,
            ),
          ),
        );
      }
    } catch (e) {
      // Dismiss loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      'Failed to generate: ${e.toString().replaceAll('Exception: ', '')}')),
            ]),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final coinsProvider = Provider.of<CoinsProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final lang = Provider.of<LocaleProvider>(context).languageCode;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppTheme.darkBackgroundGradient
              : AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMedium),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios),
                      color:
                          isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                    ),
                    Text(
                      AppStrings.get('mind_rewards', lang),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color:
                            isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingLarge),
                  child: Column(
                    children: [
                      // Big coin display with glow
                      AnimatedBuilder(
                        animation: _coinGlowController,
                        builder: (context, child) {
                          final glow = 0.2 + 0.3 * _coinGlowController.value;
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFFFFD700).withOpacity(0.15),
                                  const Color(0xFFFFA000).withOpacity(0.08),
                                ],
                              ),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusLarge),
                              border: Border.all(
                                color:
                                    const Color(0xFFFFD700).withOpacity(glow),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700)
                                      .withOpacity(glow * 0.5),
                                  blurRadius: 30,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: child,
                          );
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFFFD700),
                                    Color(0xFFFFA000)
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x50FFD700),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.stars_rounded,
                                  color: Colors.white, size: 40),
                            ).animate().scale(
                                  begin: const Offset(0.5, 0.5),
                                  end: const Offset(1, 1),
                                  duration: 600.ms,
                                  curve: Curves.elasticOut,
                                ),
                            const SizedBox(height: 16),
                            Text(
                              '${coinsProvider.totalCoins}',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? const Color(0xFFFFD700)
                                    : const Color(0xFFFFA000),
                                letterSpacing: 2,
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 200.ms)
                                .slideY(begin: 0.3, end: 0),
                            Text(
                              AppStrings.get('mind_coins', lang),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppTheme.darkTextGray
                                    : AppTheme.textGray,
                                letterSpacing: 1,
                              ),
                            ).animate().fadeIn(delay: 300.ms),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Stats row
                      Row(
                        children: [
                          Expanded(
                              child: _buildStatCard(
                            icon: Icons.local_fire_department_rounded,
                            iconColor: const Color(0xFFFF5252),
                            label: AppStrings.get('streak', lang),
                            value:
                                '${coinsProvider.currentStreak} ${AppStrings.get('days', lang)}',
                            isDark: isDark,
                            delay: 400,
                          )),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _buildStatCard(
                            icon: Icons.emoji_events_rounded,
                            iconColor: const Color(0xFFFFD700),
                            label: AppStrings.get('best_streak', lang),
                            value:
                                '${coinsProvider.longestStreak} ${AppStrings.get('days', lang)}',
                            isDark: isDark,
                            delay: 500,
                          )),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _buildStatCard(
                            icon: Icons.mic_rounded,
                            iconColor: const Color(0xFF7C4DFF),
                            label: AppStrings.get('sessions', lang),
                            value: '${coinsProvider.totalSessions}',
                            isDark: isDark,
                            delay: 600,
                          )),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Ways to earn
                      _buildSectionTitle(
                          AppStrings.get('ways_to_earn', lang),
                          Icons.trending_up_rounded,
                          const Color(0xFF4CAF50),
                          isDark),
                      const SizedBox(height: 12),
                      _buildEarnCard(
                        icon: Icons.mic_rounded,
                        gradient: const [Color(0xFF7C4DFF), Color(0xFF536DFE)],
                        title: AppStrings.get('daily_checkin', lang),
                        subtitle: AppStrings.get('daily_checkin_desc', lang),
                        coins: 10,
                        isDark: isDark,
                        delay: 700,
                        earned: coinsProvider.checkedInToday,
                      ),
                      const SizedBox(height: 10),
                      _buildEarnCard(
                        icon: Icons.local_fire_department_rounded,
                        gradient: const [Color(0xFFFF5252), Color(0xFFFF8A80)],
                        title: AppStrings.get('streak_3_bonus', lang),
                        subtitle: coinsProvider.streak3Claimed
                            ? AppStrings.get('claimed_keep_going', lang)
                            : '${coinsProvider.currentStreak}/3 ${AppStrings.get('days', lang)} — ${AppStrings.get('keep_it_up', lang)}',
                        coins: 15,
                        isDark: isDark,
                        delay: 750,
                        earned: coinsProvider.streak3Claimed,
                      ),
                      const SizedBox(height: 10),
                      _buildEarnCard(
                        icon: Icons.emoji_events_rounded,
                        gradient: const [Color(0xFFFFD700), Color(0xFFFFA000)],
                        title: AppStrings.get('streak_7_bonus', lang),
                        subtitle: coinsProvider.streak7Claimed
                            ? AppStrings.get('claimed_star', lang)
                            : '${coinsProvider.currentStreak}/7 ${AppStrings.get('days', lang)} — ${AppStrings.get('almost_there', lang)}',
                        coins: 50,
                        isDark: isDark,
                        delay: 800,
                        earned: coinsProvider.streak7Claimed,
                      ),
                      const SizedBox(height: 10),
                      _buildEarnCard(
                        icon: Icons.chat_outlined,
                        gradient: const [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                        title: AppStrings.get('chat_medibot', lang),
                        subtitle: AppStrings.get('chat_medibot_desc', lang),
                        coins: 5,
                        isDark: isDark,
                        delay: 850,
                        earned: coinsProvider.chatRewardedToday,
                      ),

                      const SizedBox(height: 28),

                      // Redeem Rewards
                      _buildSectionTitle(
                          AppStrings.get('redeem_rewards', lang),
                          Icons.card_giftcard_rounded,
                          const Color(0xFFFFA000),
                          isDark),
                      const SizedBox(height: 12),

                      _buildRewardCard(
                        icon: Icons.self_improvement_rounded,
                        gradient: const [Color(0xFF7C4DFF), Color(0xFFB388FF)],
                        title: AppStrings.get('guided_meditation', lang),
                        subtitle:
                            AppStrings.get('guided_meditation_desc', lang),
                        cost: 30,
                        isDark: isDark,
                        delay: 900,
                        onTap: () => _showRedeemDialog(
                          title: AppStrings.get('guided_meditation', lang),
                          cost: 30,
                          rewardType: 'meditation',
                          description:
                              AppStrings.get('guided_meditation_desc', lang),
                          icon: Icons.self_improvement_rounded,
                          gradient: const [
                            Color(0xFF7C4DFF),
                            Color(0xFFB388FF)
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildRewardCard(
                        icon: Icons.insights_rounded,
                        gradient: const [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                        title: AppStrings.get('weekly_wellness', lang),
                        subtitle: AppStrings.get('weekly_wellness_desc', lang),
                        cost: 50,
                        isDark: isDark,
                        delay: 950,
                        onTap: () => _showRedeemDialog(
                          title: AppStrings.get('weekly_wellness', lang),
                          cost: 50,
                          rewardType: 'wellness_report',
                          description:
                              AppStrings.get('weekly_wellness_desc', lang),
                          icon: Icons.insights_rounded,
                          gradient: const [
                            Color(0xFF4ECDC4),
                            Color(0xFF44A08D)
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildRewardCard(
                        icon: Icons.workspace_premium_rounded,
                        gradient: const [Color(0xFFFFD700), Color(0xFFFFA000)],
                        title: AppStrings.get('premium_health_tips', lang),
                        subtitle: AppStrings.get('premium_health_desc', lang),
                        cost: 80,
                        isDark: isDark,
                        delay: 1000,
                        onTap: () => _showRedeemDialog(
                          title: AppStrings.get('premium_health_tips', lang),
                          cost: 80,
                          rewardType: 'health_tips',
                          description:
                              AppStrings.get('premium_health_desc', lang),
                          icon: Icons.workspace_premium_rounded,
                          gradient: const [
                            Color(0xFFFFD700),
                            Color(0xFFFFA000)
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Motivational footer
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            const Color(0xFF7C4DFF).withOpacity(0.1),
                            const Color(0xFF536DFE).withOpacity(0.05),
                          ]),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                          border: Border.all(
                              color: const Color(0xFF7C4DFF).withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.favorite_rounded,
                                color: const Color(0xFF7C4DFF).withOpacity(0.6),
                                size: 28),
                            const SizedBox(height: 10),
                            Text(
                              AppStrings.get(
                                  'your_mental_health_matters', lang),
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppTheme.darkTextLight
                                      : AppTheme.textDark),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppStrings.get('keep_sharing_growing', lang),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: isDark
                                      ? AppTheme.darkTextGray
                                      : AppTheme.textGray),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 1100.ms, duration: 600.ms),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
      {required IconData icon,
      required Color iconColor,
      required String label,
      required String value,
      required bool isDark,
      required int delay}) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      borderRadius: AppTheme.radiusMedium,
      child: Column(children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? AppTheme.darkTextLight : AppTheme.textDark)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: isDark ? AppTheme.darkTextDim : AppTheme.textLight)),
      ]),
    )
        .animate()
        .fadeIn(delay: delay.ms, duration: 400.ms)
        .slideY(begin: 0.2, end: 0);
  }

  Widget _buildSectionTitle(
      String title, IconData icon, Color color, bool isDark) {
    return Row(children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 10),
      Text(title,
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTheme.darkTextLight : AppTheme.textDark)),
    ]);
  }

  Widget _buildEarnCard(
      {required IconData icon,
      required List<Color> gradient,
      required String title,
      required String subtitle,
      required int coins,
      required bool isDark,
      required int delay,
      bool earned = false}) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: AppTheme.radiusMedium,
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: earned
                    ? [Colors.grey.shade400, Colors.grey.shade500]
                    : gradient),
            borderRadius: BorderRadius.circular(10),
          ),
          child: earned
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
              : Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkTextLight : AppTheme.textDark)),
          const SizedBox(height: 2),
          Text(
            earned
                ? AppStrings.get('earned_today',
                    Provider.of<LocaleProvider>(context).languageCode)
                : subtitle,
            style: TextStyle(
                fontSize: 11,
                color: earned
                    ? const Color(0xFF4CAF50)
                    : (isDark ? AppTheme.darkTextDim : AppTheme.textLight)),
          ),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: earned
                ? const Color(0xFF4CAF50).withOpacity(0.15)
                : const Color(0xFFFFD700).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: earned
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF4CAF50), size: 14),
                  const SizedBox(width: 4),
                  Text(
                      AppStrings.get('done',
                          Provider.of<LocaleProvider>(context).languageCode),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4CAF50))),
                ])
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.stars_rounded,
                      color: Color(0xFFFFA000), size: 14),
                  const SizedBox(width: 4),
                  Text('+$coins',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFFA000))),
                ]),
        ),
      ]),
    )
        .animate()
        .fadeIn(delay: delay.ms, duration: 400.ms)
        .slideX(begin: 0.05, end: 0);
  }

  Widget _buildRewardCard(
      {required IconData icon,
      required List<Color> gradient,
      required String title,
      required String subtitle,
      required int cost,
      required bool isDark,
      required int delay,
      required VoidCallback onTap}) {
    final coinsProvider = Provider.of<CoinsProvider>(context);
    final canAfford = coinsProvider.totalCoins >= cost;

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderRadius: AppTheme.radiusMedium,
        child: Row(children: [
          Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: canAfford
                          ? gradient
                          : [Colors.grey.shade400, Colors.grey.shade500]),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: Colors.white, size: 20)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppTheme.darkTextLight
                            : AppTheme.textDark)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.darkTextDim
                            : AppTheme.textLight)),
              ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: canAfford
                  ? const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA000)])
                  : null,
              color: canAfford
                  ? null
                  : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.stars_rounded,
                  color: canAfford ? Colors.white : Colors.grey, size: 14),
              const SizedBox(width: 4),
              Text('$cost',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: canAfford ? Colors.white : Colors.grey)),
            ]),
          ),
        ]),
      ),
    )
        .animate()
        .fadeIn(delay: delay.ms, duration: 400.ms)
        .slideX(begin: 0.05, end: 0);
  }
}
