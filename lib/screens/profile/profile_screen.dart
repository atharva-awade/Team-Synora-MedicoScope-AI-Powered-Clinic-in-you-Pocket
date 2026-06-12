import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/core/providers/auth_provider.dart';
import 'package:medicoscope/core/locale/locale_provider.dart';
import 'package:medicoscope/core/locale/app_strings.dart';
import 'package:provider/provider.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';
import 'package:medicoscope/screens/profile/edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final lang = Provider.of<LocaleProvider>(context).languageCode;
    final isDark = themeProvider.isDarkMode;
    final user = authProvider.user;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppTheme.darkBackgroundGradient
              : AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingXLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button & Edit button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) =>
                                  const EditProfileScreen(),
                              transitionsBuilder:
                                  (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.1),
                                      end: Offset.zero,
                                    ).animate(CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOut,
                                    )),
                                    child: child,
                                  ),
                                );
                              },
                              transitionDuration: const Duration(milliseconds: 300),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: AppTheme.orangeGradient,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryOrange.withOpacity(0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit_outlined, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                AppStrings.get('edit_profile', lang),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppTheme.spacingXLarge),

                  // Profile header
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: AppTheme.primaryOrange.withOpacity(0.15),
                          child: Text(
                            user?.name.isNotEmpty == true
                                ? user!.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryOrange,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingMedium),
                        Text(
                          user?.name ?? AppStrings.get('user', lang),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: authProvider.isPatient
                                ? const LinearGradient(
                                    colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)])
                                : const LinearGradient(
                                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            authProvider.isPatient ? AppStrings.get('patient', lang) : AppStrings.get('doctor', lang),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .scale(
                        begin: const Offset(0.9, 0.9),
                        end: const Offset(1, 1),
                      ),

                  const SizedBox(height: AppTheme.spacingXXLarge),

                  // Info cards
                  _buildInfoCard(
                    isDark,
                    icon: Icons.email_outlined,
                    label: AppStrings.get('email', lang),
                    value: user?.email ?? '',
                    delay: 200,
                  ),

                  _buildInfoCard(
                    isDark,
                    icon: Icons.phone_outlined,
                    label: AppStrings.get('phone', lang),
                    value: user?.phone ?? AppStrings.get('not_provided', lang),
                    delay: 300,
                  ),

                  _buildInfoCard(
                    isDark,
                    icon: Icons.qr_code,
                    label: AppStrings.get('unique_code', lang),
                    value: user?.uniqueCode ?? '',
                    valueColor: AppTheme.primaryOrange,
                    delay: 400,
                  ),

                  _buildInfoCard(
                    isDark,
                    icon: Icons.calendar_today_outlined,
                    label: AppStrings.get('member_since', lang),
                    value: user?.createdAt != null
                        ? DateTime.tryParse(user!.createdAt!)
                                ?.toLocal()
                                .toString()
                                .split(' ')
                                .first ??
                            AppStrings.get('unknown', lang)
                        : AppStrings.get('unknown', lang),
                    delay: 500,
                  ),

                  const SizedBox(height: AppTheme.spacingXLarge),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    bool isDark, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    required int delay,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
      child: GlassCard(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(icon, color: AppTheme.primaryOrange, size: 20),
            ),
            const SizedBox(width: AppTheme.spacingMedium),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: valueColor ??
                        (isDark ? AppTheme.darkTextLight : AppTheme.textDark),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay), duration: 600.ms)
        .slideX(begin: 0.1, end: 0);
  }
}
