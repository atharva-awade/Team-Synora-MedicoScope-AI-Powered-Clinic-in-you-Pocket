import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:medicoscope/core/locale/locale_provider.dart';
import 'package:medicoscope/core/locale/app_strings.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/screens/welcome/welcome_screen.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class UserGuideScreen extends StatefulWidget {
  const UserGuideScreen({super.key});

  @override
  State<UserGuideScreen> createState() => _UserGuideScreenState();
}

class _UserGuideScreenState extends State<UserGuideScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<GuideItem> _getGuideItems(String lang) => [
    GuideItem(
      icon: Icons.medical_services_outlined,
      title: AppStrings.get('onboarding_title_1', lang),
      description: AppStrings.get('onboarding_desc_1', lang),
    ),
    GuideItem(
      icon: Icons.camera_alt_outlined,
      title: AppStrings.get('onboarding_title_2', lang),
      description: AppStrings.get('onboarding_desc_2', lang),
    ),
    GuideItem(
      icon: Icons.view_in_ar_outlined,
      title: AppStrings.get('onboarding_title_3', lang),
      description: AppStrings.get('onboarding_desc_3', lang),
    ),
    GuideItem(
      icon: Icons.health_and_safety_outlined,
      title: AppStrings.get('onboarding_title_4', lang),
      description: AppStrings.get('onboarding_desc_4', lang),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static const int _guideItemCount = 4;

  void _nextPage() {
    if (_currentPage < _guideItemCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _navigateToWelcome();
    }
  }

  void _navigateToWelcome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const WelcomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LocaleProvider>(context).languageCode;
    final guideItems = _getGuideItems(lang);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingLarge),
                child: Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _navigateToWelcome,
                    child: Text(
                      AppStrings.get('skip', lang),
                      style: TextStyle(
                        color: AppTheme.textGray,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

              // Page view
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemCount: guideItems.length,
                  itemBuilder: (context, index) {
                    return _buildGuidePage(guideItems[index], index);
                  },
                ),
              ),

              // Page indicator
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spacingLarge,
                ),
                child: SmoothPageIndicator(
                  controller: _pageController,
                  count: guideItems.length,
                  effect: ExpandingDotsEffect(
                    activeDotColor: AppTheme.primaryOrange,
                    dotColor: AppTheme.textLight,
                    dotHeight: 8,
                    dotWidth: 8,
                    expansionFactor: 4,
                  ),
                ),
              ),

              // Next button
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingXLarge),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLarge),
                      ),
                    ),
                    child: Text(
                      _currentPage == guideItems.length - 1
                          ? AppStrings.get('get_started', lang)
                          : AppStrings.get('next', lang),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 400.ms)
                    .slideY(begin: 0.2, end: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuidePage(GuideItem item, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXLarge),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          GlassCard(
            width: 120,
            height: 120,
            padding: const EdgeInsets.all(AppTheme.spacingXLarge),
            child: Icon(
              item.icon,
              size: 56,
              color: AppTheme.primaryOrange,
            ),
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: 600.ms)
              .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),

          const SizedBox(height: AppTheme.spacingXXLarge),

          // Title
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          )
              .animate()
              .fadeIn(delay: 400.ms, duration: 600.ms)
              .slideY(begin: 0.3, end: 0),

          const SizedBox(height: AppTheme.spacingMedium),

          // Description
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: AppTheme.textGray,
            ),
          )
              .animate()
              .fadeIn(delay: 600.ms, duration: 600.ms)
              .slideY(begin: 0.3, end: 0),
        ],
      ),
    );
  }
}

class GuideItem {
  final IconData icon;
  final String title;
  final String description;

  GuideItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
