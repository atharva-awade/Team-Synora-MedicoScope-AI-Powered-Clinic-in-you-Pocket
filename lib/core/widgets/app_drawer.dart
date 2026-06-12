import 'package:flutter/material.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/providers/auth_provider.dart';
import 'package:medicoscope/core/locale/locale_provider.dart';
import 'package:medicoscope/core/locale/app_strings.dart';
import 'package:medicoscope/core/widgets/language_picker.dart';
import 'package:medicoscope/screens/profile/profile_screen.dart';
import 'package:medicoscope/screens/linking/my_code_screen.dart';
import 'package:medicoscope/screens/linking/link_doctor_screen.dart';
import 'package:medicoscope/screens/patients/patient_list_screen.dart';
import 'package:medicoscope/screens/chat/chat_history_screen.dart';
import 'package:medicoscope/screens/mental_health/mindspace_history_screen.dart';
import 'package:medicoscope/screens/rewards/claimed_rewards_screen.dart';
import 'package:medicoscope/screens/welcome/welcome_screen.dart';
import 'package:provider/provider.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).pop(); // Close drawer
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
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
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final lang = Provider.of<LocaleProvider>(context).languageCode;
    final user = authProvider.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor:
          isDark ? AppTheme.darkBackground : AppTheme.backgroundLight,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spacingLarge),
              decoration: BoxDecoration(
                gradient: AppTheme.orangeGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Text(
                      user?.name.isNotEmpty == true
                          ? user!.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),
                  Text(
                    user?.name ?? AppStrings.get('user', lang),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSmall),
                  // Role badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      authProvider.isAdmin
                          ? 'Admin'
                          : authProvider.isPatient
                              ? AppStrings.get('patient', lang)
                              : AppStrings.get('doctor', lang),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacingSmall),

            // Menu items
            _buildMenuItem(
              context,
              icon: Icons.person_outlined,
              title: AppStrings.get('profile', lang),
              onTap: () => _navigateTo(context, const ProfileScreen()),
            ),

            _buildMenuItem(
              context,
              icon: Icons.qr_code,
              title: AppStrings.get('my_code', lang),
              subtitle: user?.uniqueCode ?? '',
              onTap: () => _navigateTo(context, const MyCodeScreen()),
            ),

            if (authProvider.isPatient)
              _buildMenuItem(
                context,
                icon: Icons.link,
                title: AppStrings.get('link_to_doctor', lang),
                onTap: () => _navigateTo(context, const LinkDoctorScreen()),
              ),

            if (authProvider.isDoctor)
              _buildMenuItem(
                context,
                icon: Icons.people_outlined,
                title: AppStrings.get('my_patients', lang),
                onTap: () => _navigateTo(context, const PatientListScreen()),
              ),

            const Divider(height: 32),

            // History section
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Text(
                'History',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkTextDim : AppTheme.textLight,
                  letterSpacing: 1,
                ),
              ),
            ),

            _buildMenuItem(
              context,
              icon: Icons.chat_outlined,
              title: 'Chat History',
              onTap: () => _navigateTo(context, const ChatHistoryScreen()),
            ),

            if (authProvider.isPatient)
              _buildMenuItem(
                context,
                icon: Icons.spa_outlined,
                title: 'MindSpace History',
                onTap: () =>
                    _navigateTo(context, const MindSpaceHistoryScreen()),
              ),

            if (authProvider.isPatient)
              _buildMenuItem(
                context,
                icon: Icons.card_giftcard_outlined,
                title: 'My Rewards',
                onTap: () =>
                    _navigateTo(context, const ClaimedRewardsScreen()),
              ),

            const Divider(height: 32),

            // Language picker
            const LanguagePicker(),

            const Divider(height: 32),

            // Logout
            _buildMenuItem(
              context,
              icon: Icons.logout,
              title: AppStrings.get('logout', lang),
              isDestructive: true,
              onTap: () async {
                Navigator.of(context).pop(); // Close drawer
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const WelcomeScreen(),
                    ),
                    (route) => false,
                  );
                }
              },
            ),

            const Spacer(),

            // Version
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              child: Text(
                AppStrings.get('version', lang),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.darkTextDim : AppTheme.textLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red.shade400 : AppTheme.primaryOrange,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDestructive
              ? Colors.red.shade400
              : (isDark ? AppTheme.darkTextLight : AppTheme.textDark),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.darkTextDim : AppTheme.textLight,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: isDark ? AppTheme.darkTextDim : AppTheme.textLight,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}
