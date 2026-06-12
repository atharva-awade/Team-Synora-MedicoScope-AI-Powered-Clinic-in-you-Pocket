import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/providers/auth_provider.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/services/mental_health_service.dart';
import 'package:medicoscope/screens/rewards/reward_content_screen.dart';
import 'package:provider/provider.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';

class ClaimedRewardsScreen extends StatefulWidget {
  const ClaimedRewardsScreen({super.key});

  @override
  State<ClaimedRewardsScreen> createState() => _ClaimedRewardsScreenState();
}

class _ClaimedRewardsScreenState extends State<ClaimedRewardsScreen> {
  List<Map<String, dynamic>> _rewards = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchRewards();
  }

  Future<void> _fetchRewards() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final rewards =
          await MentalHealthService.getClaimedRewards(auth.token ?? '');
      if (mounted) {
        setState(() {
          _rewards = rewards;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _rewardIcon(String type) {
    switch (type) {
      case 'meditation':
      case 'guided_meditation':
        return Icons.self_improvement_rounded;
      case 'wellness_report':
      case 'weekly_wellness':
        return Icons.insights_rounded;
      case 'health_tips':
      case 'premium_health_tips':
        return Icons.workspace_premium_rounded;
      default:
        return Icons.card_giftcard_rounded;
    }
  }

  List<Color> _rewardGradient(String type) {
    switch (type) {
      case 'meditation':
      case 'guided_meditation':
        return const [Color(0xFF7C4DFF), Color(0xFFB388FF)];
      case 'wellness_report':
      case 'weekly_wellness':
        return const [Color(0xFF4ECDC4), Color(0xFF44A08D)];
      case 'health_tips':
      case 'premium_health_tips':
        return const [Color(0xFFFFD700), Color(0xFFFFA000)];
      default:
        return const [Color(0xFF667EEA), Color(0xFF764BA2)];
    }
  }

  String _timeAgo(String iso) {
    try {
      final d = DateTime.parse(iso);
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 30) return '${diff.inDays}d ago';
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

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
                      'My Rewards',
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

              // Content
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _rewards.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.card_giftcard_outlined,
                                    size: 64,
                                    color: isDark
                                        ? AppTheme.darkTextDim
                                        : AppTheme.textLight),
                                const SizedBox(height: 12),
                                Text(
                                  'No rewards claimed yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppTheme.darkTextGray
                                        : AppTheme.textGray,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Earn coins and redeem rewards!',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? AppTheme.darkTextDim
                                        : AppTheme.textLight,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchRewards,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacingLarge),
                              itemCount: _rewards.length,
                              itemBuilder: (context, index) {
                                final r = _rewards[index];
                                final type = r['rewardType'] as String? ?? '';
                                final title = r['title'] as String? ?? 'Reward';
                                final content = r['content'] as String? ?? '';
                                final cost = r['coinsCost'] as int? ?? 0;
                                final createdAt =
                                    r['createdAt'] as String? ?? '';
                                final gradient = _rewardGradient(type);
                                final icon = _rewardIcon(type);

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: GlassCard(
                                    borderRadius: AppTheme.radiusMedium,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(
                                          AppTheme.radiusMedium),
                                      onTap: () {
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
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: gradient,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: Icon(icon,
                                                  color: Colors.white,
                                                  size: 24),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    title,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: isDark
                                                          ? AppTheme
                                                              .darkTextLight
                                                          : AppTheme.textDark,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    content.length > 80
                                                        ? '${content.substring(0, 80)}...'
                                                        : content,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isDark
                                                          ? AppTheme
                                                              .darkTextGray
                                                          : AppTheme.textGray,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.stars_rounded,
                                                        size: 14,
                                                        color: const Color(
                                                            0xFFFFD700),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '$cost coins',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: const Color(
                                                              0xFFFFA000),
                                                        ),
                                                      ),
                                                      const Spacer(),
                                                      Text(
                                                        _timeAgo(createdAt),
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: isDark
                                                              ? AppTheme
                                                                  .darkTextDim
                                                              : AppTheme
                                                                  .textLight,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              color: isDark
                                                  ? AppTheme.darkTextDim
                                                  : AppTheme.textLight,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ).animate().fadeIn(
                                    delay: Duration(milliseconds: index * 80),
                                    duration:
                                        const Duration(milliseconds: 400));
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
