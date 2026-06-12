import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/widgets/app_drawer.dart';
import 'package:medicoscope/core/widgets/dashboard_tile.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/core/widgets/theme_toggle_button.dart';
import 'package:medicoscope/core/providers/auth_provider.dart';
import 'package:medicoscope/core/locale/locale_provider.dart';
import 'package:medicoscope/core/locale/app_strings.dart';
import 'package:medicoscope/core/constants/disease_constants.dart';
import 'package:medicoscope/core/providers/coins_provider.dart';
import 'package:medicoscope/screens/chat/chat_bottom_sheet.dart';
import 'package:medicoscope/screens/diseases/disease_deck_screen.dart';
import 'package:medicoscope/screens/diseases/unified_risk_dashboard.dart';
import 'package:medicoscope/screens/mental_health/mental_health_screen.dart';
import 'package:medicoscope/screens/rewards/rewards_screen.dart';
import 'package:medicoscope/screens/upload/image_upload_screen.dart';
import 'package:medicoscope/screens/vitals/vitals_screen.dart';
import 'package:medicoscope/screens/heart/heart_monitoring_screen.dart';
import 'package:medicoscope/screens/alerts/patient_alerts_screen.dart';
import 'package:medicoscope/screens/appointments/patient_appointments_screen.dart';
import 'package:medicoscope/screens/nearby_doctors/nearby_doctors_screen.dart';
import 'package:medicoscope/screens/steps/steps_screen.dart';
import 'package:provider/provider.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';

class PatientDashboardScreen extends StatelessWidget {
  const PatientDashboardScreen({super.key});

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final coinsProvider = Provider.of<CoinsProvider>(context);
    final lang = Provider.of<LocaleProvider>(context).languageCode;
    final isDark = themeProvider.isDarkMode;
    final user = authProvider.user;

    return Scaffold(
      drawer: const AppDrawer(),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4ECDC4).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          heroTag: null,
          onPressed: () => showChatBottomSheet(context),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.chat_rounded, color: Colors.white),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppTheme.darkBackgroundGradient
              : AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // App Bar
              SliverAppBar(
                expandedHeight: 160,
                floating: false,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: Icon(
                      Icons.menu,
                      color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                    ),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                actions: [
                  // Compact coins badge
                  GestureDetector(
                    onTap: () => _navigateTo(context, const RewardsScreen()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars_rounded,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${coinsProvider.totalCoins}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(right: AppTheme.spacingMedium),
                    child: ThemeToggleButton(),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacingXLarge,
                      80,
                      AppTheme.spacingXLarge,
                      AppTheme.spacingMedium,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppStrings.format('hello_name', lang, {'name': user?.name.split(' ').first ?? AppStrings.get('patient', lang)}),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 600.ms)
                            .slideX(begin: -0.1, end: 0),
                        const SizedBox(height: 2),
                        Text(
                          AppStrings.get('welcome_to_medicoscope', lang),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 200.ms, duration: 600.ms),
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              SliverPadding(
                padding: const EdgeInsets.all(AppTheme.spacingXLarge),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Patient code card
                    GlassCard(
                      padding: const EdgeInsets.all(AppTheme.spacingMedium),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: AppTheme.orangeGradient,
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            ),
                            child: const Icon(Icons.qr_code, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: AppTheme.spacingMedium),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.get('your_patient_code', lang),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.uniqueCode ?? 'N/A',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryOrange,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            AppStrings.get('share_with_doctor', lang),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.darkTextDim : AppTheme.textLight,
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 300.ms, duration: 600.ms)
                        .slideY(begin: 0.2, end: 0),

                    const SizedBox(height: AppTheme.spacingLarge),

                    // Section title
                    Text(
                      AppStrings.get('quick_actions', lang),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 400.ms, duration: 600.ms),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // Skin Scan tile
                    DashboardTile(
                      icon: Icons.face_outlined,
                      title: AppStrings.get('skin_scan', lang),
                      description: AppStrings.get('skin_scan_desc', lang),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFF8C61), Color(0xFFFF6B35)],
                      ),
                      onTap: () => _navigateTo(
                        context,
                        const ImageUploadScreen(category: 'skin'),
                      ),
                      animationDelay: 500,
                    ),

                    const SizedBox(height: AppTheme.spacingMedium),

                    DashboardTile(
                      icon: Icons.dashboard_customize_outlined,
                      title: 'Risk Dashboard',
                      description: 'Diabetes • Hypertension • Anemia overview',
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                      ),
                      onTap: () => _navigateTo(
                        context,
                        const UnifiedRiskDashboard(),
                      ),
                      animationDelay: 510,
                    ),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // Diabetes deck
                    DashboardTile(
                      icon: DiseaseRegistry.of(DiseaseType.diabetes).icon,
                      title: 'Diabetes Screening',
                      description:
                          DiseaseRegistry.of(DiseaseType.diabetes).shortDesc,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors:
                            DiseaseRegistry.of(DiseaseType.diabetes).gradient,
                      ),
                      onTap: () => _navigateTo(
                        context,
                        const DiseaseDeckScreen(disease: DiseaseType.diabetes),
                      ),
                      animationDelay: 520,
                    ),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // Hypertension deck
                    DashboardTile(
                      icon: DiseaseRegistry.of(DiseaseType.hypertension).icon,
                      title: 'Hypertension Screening',
                      description:
                          DiseaseRegistry.of(DiseaseType.hypertension).shortDesc,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: DiseaseRegistry.of(DiseaseType.hypertension)
                            .gradient,
                      ),
                      onTap: () => _navigateTo(
                        context,
                        const DiseaseDeckScreen(
                            disease: DiseaseType.hypertension),
                      ),
                      animationDelay: 540,
                    ),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // Anemia deck
                    DashboardTile(
                      icon: DiseaseRegistry.of(DiseaseType.anemia).icon,
                      title: 'Anemia Screening',
                      description:
                          DiseaseRegistry.of(DiseaseType.anemia).shortDesc,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors:
                            DiseaseRegistry.of(DiseaseType.anemia).gradient,
                      ),
                      onTap: () => _navigateTo(
                        context,
                        const DiseaseDeckScreen(disease: DiseaseType.anemia),
                      ),
                      animationDelay: 560,
                    ),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // Vitals tile
                    DashboardTile(
                      icon: Icons.monitor_heart_outlined,
                      title: AppStrings.get('vitals', lang),
                      description: AppStrings.get('vitals_desc', lang),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      ),
                      onTap: () => _navigateTo(
                        context,
                        const VitalsScreen(),
                      ),
                      animationDelay: 600,
                    ),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // MindSpace tile
                    DashboardTile(
                      icon: Icons.mic_rounded,
                      title: AppStrings.get('mind_space', lang),
                      description: AppStrings.get('mind_space_desc', lang),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF7C4DFF), Color(0xFF536DFE)],
                      ),
                      onTap: () => _navigateTo(
                        context,
                        const MentalHealthScreen(),
                      ),
                      animationDelay: 750,
                    ),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // Heart Monitoring tile
                    DashboardTile(
                      icon: Icons.favorite_outline,
                      title: AppStrings.get('heart_monitoring', lang),
                      description: AppStrings.get('heart_monitoring_desc', lang),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFF6B6B), Color(0xFFEE5A24)],
                      ),
                      onTap: () => _navigateTo(
                        context,
                        const HeartMonitoringScreen(),
                      ),
                      animationDelay: 775,
                    ),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // Alerts tile
                    DashboardTile(
                      icon: Icons.notifications_active_outlined,
                      title: AppStrings.get('alerts', lang),
                      description: AppStrings.get('alerts_desc', lang),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF093FB), Color(0xFFF5576C)],
                      ),
                      onTap: () => _navigateTo(
                        context,
                        const PatientAlertsScreen(),
                      ),
                      animationDelay: 800,
                    ),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // My Appointments tile — tracks doctor confirmations
                    // and reschedule proposals.
                    DashboardTile(
                      icon: Icons.event_available_outlined,
                      title: 'My Appointments',
                      description:
                          'Doctor confirmations & reschedule proposals',
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      ),
                      onTap: () => _navigateTo(
                        context,
                        const PatientAppointmentsScreen(),
                      ),
                      animationDelay: 810,
                    ),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // Activity Tracker tile (Steps via Health Connect)
                    DashboardTile(
                      icon: Icons.directions_walk_rounded,
                      title: 'Activity Tracker',
                      description:
                          'Steps, calories & distance from your smartwatch',
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF43E97B), Color(0xFF38F9D7)],
                      ),
                      onTap: () => _navigateTo(
                        context,
                        const StepsScreen(),
                      ),
                      animationDelay: 825,
                    ),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // Find Nearby Doctors tile
                    DashboardTile(
                      icon: Icons.location_on_outlined,
                      title: 'Find Nearby Doctors',
                      description: 'Search specialists near your location',
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                      ),
                      onTap: () => _navigateTo(
                        context,
                        const NearbyDoctorsScreen(),
                      ),
                      animationDelay: 850,
                    ),

                    const SizedBox(height: AppTheme.spacingXLarge),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
