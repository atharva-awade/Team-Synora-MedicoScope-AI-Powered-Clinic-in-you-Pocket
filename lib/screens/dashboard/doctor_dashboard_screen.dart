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
import 'package:medicoscope/screens/diseases/disease_deck_screen.dart';
import 'package:medicoscope/screens/appointments/doctor_appointments_screen.dart';
import 'package:medicoscope/screens/patients/patient_list_screen.dart';
import 'package:medicoscope/screens/notifications/notifications_screen.dart';
import 'package:medicoscope/screens/reports/doctor_reports_screen.dart';
import 'package:medicoscope/services/vitals_service.dart';
import 'package:medicoscope/services/mental_health_service.dart';
import 'package:provider/provider.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  int _unreadVitalsAlerts = 0;

  @override
  void initState() {
    super.initState();
    _fetchAlertCount();
  }

  Future<void> _fetchAlertCount() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id ?? '';
    final token = authProvider.token ?? '';
    if (userId.isEmpty) return;

    int totalUnread = 0;

    // Vitals alerts
    try {
      final alerts = await VitalsService.getDoctorAlerts(doctorId: userId);
      totalUnread += alerts.where((a) => !(a['read'] ?? false)).length;
    } catch (_) {}

    // Mental health notifications
    try {
      final notifications = await MentalHealthService.getNotifications(
        doctorId: userId,
        token: token,
      );
      totalUnread += notifications.where((n) => !(n['read'] ?? false)).length;
    } catch (_) {}

    if (mounted) {
      setState(() => _unreadVitalsAlerts = totalUnread);
    }
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context)
        .push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => screen,
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
            transitionDuration: const Duration(milliseconds: 400),
          ),
        )
        .then((_) => _fetchAlertCount());
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final lang = Provider.of<LocaleProvider>(context).languageCode;
    final isDark = themeProvider.isDarkMode;
    final user = authProvider.user;

    return Scaffold(
      drawer: const AppDrawer(),
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
                      color:
                          isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                    ),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                actions: [
                  // Bell icon with badge
                  Stack(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.notifications_outlined,
                          color: isDark
                              ? AppTheme.darkTextLight
                              : AppTheme.textDark,
                        ),
                        onPressed: () =>
                            _navigateTo(context, const NotificationsScreen()),
                      ),
                      if (_unreadVitalsAlerts > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF5252),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Center(
                              child: Text(
                                _unreadVitalsAlerts > 9
                                    ? '9+'
                                    : '$_unreadVitalsAlerts',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
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
                      children: [
                        Text(
                          AppStrings.format('dr_name', lang, {
                            'name': user?.name.split(' ').last ??
                                AppStrings.get('doctor', lang)
                          }),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppTheme.darkTextLight
                                : AppTheme.textDark,
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 600.ms)
                            .slideX(begin: -0.1, end: 0),
                        const SizedBox(height: 4),
                        Text(
                          AppStrings.get('medicoscope_dashboard', lang),
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark
                                ? AppTheme.darkTextGray
                                : AppTheme.textGray,
                          ),
                        ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
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
                    // Doctor code card
                    GlassCard(
                      padding: const EdgeInsets.all(AppTheme.spacingMedium),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                              ),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSmall),
                            ),
                            child: const Icon(Icons.qr_code,
                                color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: AppTheme.spacingMedium),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.get('your_doctor_code', lang),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppTheme.darkTextGray
                                      : AppTheme.textGray,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.uniqueCode ?? 'N/A',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF667EEA),
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            AppStrings.get('share_with_patients', lang),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppTheme.darkTextDim
                                  : AppTheme.textLight,
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 300.ms, duration: 600.ms)
                        .slideY(begin: 0.2, end: 0),

                    const SizedBox(height: AppTheme.spacingLarge),

                    Text(
                      AppStrings.get('diagnostics', lang),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                      ),
                    ).animate().fadeIn(delay: 400.ms, duration: 600.ms),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // My Patients tile
                    DashboardTile(
                      icon: Icons.people_outlined,
                      title: AppStrings.get('my_patients', lang),
                      description: AppStrings.get('my_patients_desc', lang),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                      ),
                      onTap: () =>
                          _navigateTo(context, const PatientListScreen()),
                      animationDelay: 500,
                    ),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // My Appointments tile — doctor can see every pending
                    // appointment request + confirm / reschedule history.
                    DashboardTile(
                      icon: Icons.event_available_outlined,
                      title: 'My Appointments',
                      description:
                          'Pending patient requests & confirmations',
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      ),
                      onTap: () => _navigateTo(
                        context,
                        const DoctorAppointmentsScreen(),
                      ),
                      animationDelay: 550,
                    ),

                    const SizedBox(height: AppTheme.spacingMedium),

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
                      animationDelay: 600,
                    ),

                    const SizedBox(height: AppTheme.spacingMedium),

                    DashboardTile(
                      icon: DiseaseRegistry.of(DiseaseType.hypertension).icon,
                      title: 'Hypertension Screening',
                      description: DiseaseRegistry.of(DiseaseType.hypertension)
                          .shortDesc,
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
                      animationDelay: 650,
                    ),

                    const SizedBox(height: AppTheme.spacingMedium),

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
                      animationDelay: 700,
                    ),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // Reports tile
                    DashboardTile(
                      icon: Icons.description_outlined,
                      title: AppStrings.get('reports', lang),
                      description: AppStrings.get('reports_desc', lang),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFF8C61), Color(0xFFFF6B35)],
                      ),
                      onTap: () =>
                          _navigateTo(context, const DoctorReportsScreen()),
                      animationDelay: 800,
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
