import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/locale/locale_provider.dart';
import 'package:medicoscope/core/locale/app_strings.dart';
import 'package:provider/provider.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';

class RewardContentScreen extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;
  final List<Color> gradient;

  const RewardContentScreen({
    super.key,
    required this.title,
    required this.content,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
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
                      color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                    ),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLarge),
                  child: Column(
                    children: [
                      // Title card with icon
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: gradient,
                          ),
                          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                          boxShadow: [
                            BoxShadow(
                              color: gradient[0].withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(icon, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    AppStrings.get('personalized_for_you', lang),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .slideY(begin: -0.1, end: 0),

                      const SizedBox(height: 20),

                      // Content sections
                      ..._buildContentSections(content, isDark),

                      const SizedBox(height: 32),

                      // Footer
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: gradient[0].withOpacity(0.6),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                AppStrings.get('ai_disclaimer_reward', lang),
                                style: TextStyle(
                                  fontSize: 10,
                                  height: 1.4,
                                  color: isDark ? AppTheme.darkTextDim : AppTheme.textLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 800.ms),

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

  List<Widget> _buildContentSections(String rawContent, bool isDark) {
    final lines = rawContent.split('\n');
    final widgets = <Widget>[];
    int sectionIndex = 0;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Check if it's a section header (all caps or starts with **bold**)
      final isSectionHeader = _isSectionHeader(trimmed);

      if (isSectionHeader) {
        sectionIndex++;
        final headerText = trimmed
            .replaceAll('**', '')
            .replaceAll(':', '')
            .trim();

        widgets.add(
          Padding(
            padding: EdgeInsets.only(
              top: sectionIndex > 1 ? 20 : 8,
              bottom: 8,
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: gradient,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    headerText,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: (300 + sectionIndex * 100).ms, duration: 400.ms),
        );
      } else {
        // Regular content line
        final isBullet = trimmed.startsWith('-') || trimmed.startsWith('•') || trimmed.startsWith('*');
        final displayText = isBullet
            ? trimmed.substring(1).trim().replaceAll('**', '')
            : trimmed.replaceAll('**', '');

        widgets.add(
          Padding(
            padding: EdgeInsets.only(
              left: isBullet ? 14 : 0,
              bottom: 6,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isBullet) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: gradient[0].withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return widgets;
  }

  bool _isSectionHeader(String line) {
    final cleaned = line.replaceAll('**', '').replaceAll(':', '').trim();
    // All caps with at least 3 characters
    if (cleaned.length >= 3 && cleaned == cleaned.toUpperCase() && cleaned.contains(RegExp(r'[A-Z]'))) {
      return true;
    }
    // Starts and ends with ** (markdown bold header)
    if (line.startsWith('**') && line.contains('**', 2)) {
      return true;
    }
    // Numbered section like "1." or "1)"
    if (RegExp(r'^\d+[\.\)]').hasMatch(line) && cleaned.toUpperCase() == cleaned) {
      return true;
    }
    return false;
  }
}
