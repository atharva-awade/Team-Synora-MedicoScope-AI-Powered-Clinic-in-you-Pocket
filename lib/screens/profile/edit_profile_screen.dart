import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/core/providers/auth_provider.dart';
import 'package:medicoscope/core/locale/locale_provider.dart';
import 'package:medicoscope/core/locale/app_strings.dart';
import 'package:medicoscope/core/constants/api_constants.dart';
import 'package:medicoscope/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isFetchingProfile = true;

  // Common fields
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  // Patient fields
  late TextEditingController _dobController;
  late TextEditingController _bloodGroupController;
  late TextEditingController _emergencyNameController;
  late TextEditingController _emergencyPhoneController;
  late TextEditingController _emergencyRelationController;

  // Doctor fields
  late TextEditingController _specializationController;
  late TextEditingController _hospitalController;
  late TextEditingController _experienceController;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _nameController = TextEditingController(text: auth.user?.name ?? '');
    _phoneController = TextEditingController(text: auth.user?.phone ?? '');

    // Patient controllers
    _dobController = TextEditingController();
    _bloodGroupController = TextEditingController();
    _emergencyNameController = TextEditingController();
    _emergencyPhoneController = TextEditingController();
    _emergencyRelationController = TextEditingController();

    // Doctor controllers
    _specializationController = TextEditingController();
    _hospitalController = TextEditingController();
    _experienceController = TextEditingController();

    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;

    try {
      final api = ApiService(token: auth.token);
      final response = await api.get(ApiConstants.profile);
      final profile = response['profile'] as Map<String, dynamic>? ?? {};

      if (auth.isPatient) {
        _dobController.text = profile['dateOfBirth'] ?? '';
        _bloodGroupController.text = profile['bloodGroup'] ?? '';
        final emergency =
            profile['emergencyContact'] as Map<String, dynamic>? ?? {};
        _emergencyNameController.text = emergency['name'] ?? '';
        _emergencyPhoneController.text = emergency['phone'] ?? '';
        _emergencyRelationController.text = emergency['relationship'] ?? '';
      } else {
        _specializationController.text = profile['specialization'] ?? '';
        _hospitalController.text = profile['hospital'] ?? '';
        _experienceController.text =
            (profile['yearsOfExperience'] ?? '').toString();
        if (_experienceController.text == '0') _experienceController.text = '';
      }
    } catch (_) {}

    if (mounted) setState(() => _isFetchingProfile = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _bloodGroupController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationController.dispose();
    _specializationController.dispose();
    _hospitalController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) return;

    try {
      final api = ApiService(token: auth.token);
      final body = <String, dynamic>{
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      };

      if (auth.isPatient) {
        body['dateOfBirth'] = _dobController.text.trim();
        body['bloodGroup'] = _bloodGroupController.text.trim();
        body['emergencyContact'] = {
          'name': _emergencyNameController.text.trim(),
          'phone': _emergencyPhoneController.text.trim(),
          'relationship': _emergencyRelationController.text.trim(),
        };
      } else {
        body['specialization'] = _specializationController.text.trim();
        body['hospital'] = _hospitalController.text.trim();
        if (_experienceController.text.trim().isNotEmpty) {
          body['yearsOfExperience'] =
              int.tryParse(_experienceController.text.trim()) ?? 0;
        }
      }

      await api.put(ApiConstants.profile, body);

      // Refresh user data in AuthProvider
      await auth.refreshUser();

      if (mounted) {
        final lang = Provider.of<LocaleProvider>(context, listen: false)
            .languageCode;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('profile_updated', lang)),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final lang = Provider.of<LocaleProvider>(context).languageCode;
    final isDark = themeProvider.isDarkMode;

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
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCard : Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSmall),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color:
                              isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMedium),
                    Text(
                      AppStrings.get('edit_profile', lang),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color:
                            isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                      ),
                    ),
                    const Spacer(),
                    if (!_isFetchingProfile)
                      GestureDetector(
                        onTap: _isLoading ? null : _saveProfile,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: AppTheme.orangeGradient,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSmall),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  AppStrings.get('save', lang),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: _isFetchingProfile
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding:
                            const EdgeInsets.all(AppTheme.spacingLarge),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar
                              Center(
                                child: CircleAvatar(
                                  radius: 48,
                                  backgroundColor:
                                      AppTheme.primaryOrange.withOpacity(0.15),
                                  child: Text(
                                    _nameController.text.isNotEmpty
                                        ? _nameController.text[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryOrange,
                                    ),
                                  ),
                                ),
                              ).animate().fadeIn(duration: 400.ms),

                              const SizedBox(height: AppTheme.spacingXLarge),

                              // Basic Info Section
                              _sectionLabel(
                                  AppStrings.get('basic_info', lang), isDark),
                              const SizedBox(height: AppTheme.spacingSmall),

                              _buildField(
                                isDark: isDark,
                                controller: _nameController,
                                label: AppStrings.get('name', lang),
                                icon: Icons.person_outline,
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? AppStrings.get('field_required', lang)
                                    : null,
                                delay: 100,
                              ),

                              _buildField(
                                isDark: isDark,
                                controller: _phoneController,
                                label: AppStrings.get('phone', lang),
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                delay: 150,
                              ),

                              const SizedBox(height: AppTheme.spacingLarge),

                              // Role-specific fields
                              if (authProvider.isPatient) ...[
                                _sectionLabel(
                                    AppStrings.get('medical_info', lang),
                                    isDark),
                                const SizedBox(height: AppTheme.spacingSmall),

                                _buildField(
                                  isDark: isDark,
                                  controller: _dobController,
                                  label: AppStrings.get('date_of_birth', lang),
                                  icon: Icons.calendar_today_outlined,
                                  delay: 200,
                                ),

                                _buildField(
                                  isDark: isDark,
                                  controller: _bloodGroupController,
                                  label: AppStrings.get('blood_group', lang),
                                  icon: Icons.bloodtype_outlined,
                                  delay: 250,
                                ),

                                const SizedBox(height: AppTheme.spacingLarge),

                                _sectionLabel(
                                    AppStrings.get('emergency_contact', lang),
                                    isDark),
                                const SizedBox(height: AppTheme.spacingSmall),

                                _buildField(
                                  isDark: isDark,
                                  controller: _emergencyNameController,
                                  label: AppStrings.get('contact_name', lang),
                                  icon: Icons.person_outline,
                                  delay: 300,
                                ),

                                _buildField(
                                  isDark: isDark,
                                  controller: _emergencyPhoneController,
                                  label: AppStrings.get('contact_phone', lang),
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                  delay: 350,
                                ),

                                _buildField(
                                  isDark: isDark,
                                  controller: _emergencyRelationController,
                                  label: AppStrings.get('relationship', lang),
                                  icon: Icons.people_outline,
                                  delay: 400,
                                ),
                              ],

                              if (authProvider.isDoctor) ...[
                                _sectionLabel(
                                    AppStrings.get('professional_info', lang),
                                    isDark),
                                const SizedBox(height: AppTheme.spacingSmall),

                                _buildField(
                                  isDark: isDark,
                                  controller: _specializationController,
                                  label:
                                      AppStrings.get('specialization', lang),
                                  icon: Icons.medical_services_outlined,
                                  delay: 200,
                                ),

                                _buildField(
                                  isDark: isDark,
                                  controller: _hospitalController,
                                  label: AppStrings.get('hospital', lang),
                                  icon: Icons.local_hospital_outlined,
                                  delay: 250,
                                ),

                                _buildField(
                                  isDark: isDark,
                                  controller: _experienceController,
                                  label: AppStrings.get(
                                      'years_of_experience', lang),
                                  icon: Icons.work_outline,
                                  keyboardType: TextInputType.number,
                                  delay: 300,
                                ),
                              ],

                              const SizedBox(height: AppTheme.spacingXXLarge),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildField({
    required bool isDark,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    required int delay,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
          ),
          decoration: InputDecoration(
            prefixIcon:
                Icon(icon, color: AppTheme.primaryOrange, size: 20),
            labelText: label,
            labelStyle: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay), duration: 400.ms)
        .slideX(begin: 0.05, end: 0);
  }
}
