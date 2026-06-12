import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/widgets/app_drawer.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/core/widgets/theme_toggle_button.dart';
import 'package:medicoscope/core/providers/auth_provider.dart';
import 'package:medicoscope/screens/admin/admin_patients_screen.dart';
import 'package:medicoscope/screens/admin/admin_doctors_screen.dart';
import 'package:medicoscope/screens/admin/add_nearby_doctor_screen.dart';
import 'package:medicoscope/screens/admin/admin_nearby_doctors_screen.dart';
import 'package:medicoscope/services/api_service.dart';
import 'package:medicoscope/core/constants/api_constants.dart';
import 'package:provider/provider.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _totalPatients = 0;
  int _totalDoctors = 0;
  int _totalNearbyDoctors = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      final api = ApiService(token: token);
      final response = await api.get(ApiConstants.adminStats);
      if (mounted) {
        setState(() {
          _totalPatients = response['totalPatients'] ?? 0;
          _totalDoctors = response['totalDoctors'] ?? 0;
          _totalNearbyDoctors = response['totalNearbyDoctors'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
                  Padding(
                    padding: const EdgeInsets.only(right: AppTheme.spacingMedium),
                    child: const ThemeToggleButton(),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacingXLarge, 80,
                      AppTheme.spacingXLarge, AppTheme.spacingMedium,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Hello, ${user?.name.split(' ').first ?? 'Admin'}',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                          ),
                        ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1, end: 0),
                        const SizedBox(height: 2),
                        Text(
                          'Admin Dashboard',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
                          ),
                        ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
                      ],
                    ),
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.all(AppTheme.spacingXLarge),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Stats Row
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Patients', _totalPatients.toString(),
                              Icons.people_outlined,
                              const [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Doctors', _totalDoctors.toString(),
                              Icons.medical_services_outlined,
                              const [Color(0xFF667EEA), Color(0xFF764BA2)],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Nearby', _totalNearbyDoctors.toString(),
                              Icons.location_on_outlined,
                              const [Color(0xFFFF8C61), Color(0xFFFF6B35)],
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 300.ms, duration: 600.ms).slideY(begin: 0.2, end: 0),

                    const SizedBox(height: AppTheme.spacingXLarge),

                    Text(
                      'Management',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                      ),
                    ).animate().fadeIn(delay: 400.ms, duration: 600.ms),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // View All Patients
                    _buildActionTile(
                      context,
                      icon: Icons.people_outlined,
                      title: 'View All Patients',
                      description: 'See all registered patients and their details',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                      ),
                      onTap: () => _navigateTo(context, const AdminPatientsScreen()),
                      delay: 500,
                    ),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // View All Doctors
                    _buildActionTile(
                      context,
                      icon: Icons.medical_services_outlined,
                      title: 'View All Doctors',
                      description: 'See all registered doctors and their specializations',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      ),
                      onTap: () => _navigateTo(context, const AdminDoctorsScreen()),
                      delay: 600,
                    ),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // Add Nearby Doctor
                    _buildActionTile(
                      context,
                      icon: Icons.add_location_alt_outlined,
                      title: 'Add Nearby Doctor',
                      description: 'Add a doctor with location for patient search',
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF8C61), Color(0xFFFF6B35)],
                      ),
                      onTap: () async {
                        await Navigator.of(context).push(
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) =>
                                const AddNearbyDoctorScreen(),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                            transitionDuration: const Duration(milliseconds: 400),
                          ),
                        );
                        _loadStats();
                      },
                      delay: 700,
                    ),

                    const SizedBox(height: AppTheme.spacingMedium),

                    // View Nearby Doctors List
                    _buildActionTile(
                      context,
                      icon: Icons.location_on_outlined,
                      title: 'Nearby Doctors List',
                      description: 'View and manage all nearby doctors you have added',
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF093FB), Color(0xFFF5576C)],
                      ),
                      onTap: () => _navigateTo(context, const AdminNearbyDoctorsScreen()),
                      delay: 800,
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

  Widget _buildStatCard(String label, String value, IconData icon, List<Color> colors) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required LinearGradient gradient,
    required VoidCallback onTap,
    required int delay,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
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
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Icon(icon, size: 28, color: Colors.white),
            ),
            const SizedBox(width: AppTheme.spacingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white,
                  )),
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(
                    fontSize: 12, color: Colors.white.withOpacity(0.85),
                  )),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.7), size: 16),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay), duration: 600.ms).slideX(begin: 0.15, end: 0);
  }
}
