import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/core/providers/auth_provider.dart';
import 'package:medicoscope/core/locale/locale_provider.dart';
import 'package:medicoscope/core/locale/app_strings.dart';
import 'package:provider/provider.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';

class MyCodeScreen extends StatelessWidget {
  const MyCodeScreen({super.key});

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
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingXLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button
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

                const SizedBox(height: AppTheme.spacingXXLarge),

                Center(
                  child: Column(
                    children: [
                      Text(
                        AppStrings.get('your_unique_code', lang),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 600.ms)
                          .slideY(begin: 0.3, end: 0),

                      const SizedBox(height: AppTheme.spacingSmall),

                      Text(
                        authProvider.isPatient
                            ? AppStrings.get('share_code_patient', lang)
                            : AppStrings.get('share_code_doctor', lang),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 600.ms),

                      const SizedBox(height: AppTheme.spacingXXLarge),

                      // Code card
                      GlassCard(
                        padding: const EdgeInsets.all(AppTheme.spacingXLarge),
                        child: Column(
                          children: [
                            Icon(
                              Icons.qr_code_2,
                              size: 64,
                              color: AppTheme.primaryOrange,
                            ),
                            const SizedBox(height: AppTheme.spacingLarge),
                            Text(
                              user?.uniqueCode ?? AppStrings.get('na', lang),
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryOrange,
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingLarge),
                            // Copy button
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: user?.uniqueCode ?? ''),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(AppStrings.get('code_copied', lang)),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.orangeGradient,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.copy, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppStrings.get('copy_code', lang),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 400.ms, duration: 600.ms)
                          .scale(
                            begin: const Offset(0.9, 0.9),
                            end: const Offset(1, 1),
                            curve: Curves.easeOut,
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
