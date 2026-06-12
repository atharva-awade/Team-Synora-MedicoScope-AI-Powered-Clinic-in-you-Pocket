import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/locale/locale_provider.dart';
import 'package:medicoscope/core/locale/app_strings.dart';
import 'package:medicoscope/core/widgets/animated_button.dart';
import 'package:medicoscope/core/widgets/auth_text_field.dart';
import 'package:medicoscope/core/widgets/theme_toggle_button.dart';
import 'package:medicoscope/core/providers/auth_provider.dart';
import 'package:medicoscope/screens/dashboard/patient_dashboard_screen.dart';
import 'package:medicoscope/screens/dashboard/doctor_dashboard_screen.dart';
import 'package:medicoscope/screens/admin/admin_dashboard_screen.dart';
import 'package:medicoscope/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';

class RegistrationScreen extends StatefulWidget {
  final String role;

  const RegistrationScreen({super.key, required this.role});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Patient fields
  final _dobController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  String _bloodGroup = '';
  String _emergencyRelationship = '';

  // Doctor fields
  final _specializationController = TextEditingController();
  final _licenseController = TextEditingController();
  final _hospitalController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  final _bloodGroups = ['', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final _relationships = [
    '',
    'Spouse',
    'Parent',
    'Child',
    'Sibling',
    'Friend',
    'Other'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dobController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _specializationController.dispose();
    _licenseController.dispose();
    _hospitalController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        role: widget.role,
        phone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        // Patient fields
        dateOfBirth:
            widget.role == 'patient' ? _dobController.text.trim() : null,
        bloodGroup: widget.role == 'patient' && _bloodGroup.isNotEmpty
            ? _bloodGroup
            : null,
        emergencyContactName: widget.role == 'patient'
            ? _emergencyNameController.text.trim()
            : null,
        emergencyContactPhone: widget.role == 'patient'
            ? _emergencyPhoneController.text.trim()
            : null,
        emergencyContactRelationship:
            widget.role == 'patient' && _emergencyRelationship.isNotEmpty
                ? _emergencyRelationship
                : null,
        // Doctor fields
        specialization: widget.role == 'doctor'
            ? _specializationController.text.trim()
            : null,
        licenseNumber:
            widget.role == 'doctor' ? _licenseController.text.trim() : null,
        hospital:
            widget.role == 'doctor' ? _hospitalController.text.trim() : null,
      );

      if (!mounted) return;

      final Widget screen;
      if (authProvider.isAdmin) {
        screen = const AdminDashboardScreen();
      } else if (authProvider.isPatient) {
        screen = const PatientDashboardScreen();
      } else {
        screen = const DoctorDashboardScreen();
      }

      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => screen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade400,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final lang = Provider.of<LocaleProvider>(context).languageCode;
    final isPatient = widget.role == 'patient';
    final isDoctor = widget.role == 'doctor';
    final isAdmin = widget.role == 'admin';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppTheme.darkBackgroundGradient
              : AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingXLarge),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppTheme.spacingMedium),

                        // Back button
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
                              color: isDark
                                  ? AppTheme.darkTextLight
                                  : AppTheme.textDark,
                            ),
                          ),
                        ),

                        const SizedBox(height: AppTheme.spacingLarge),

                        // Title
                        Text(
                          AppStrings.get('create_account', lang),
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
                            .slideY(begin: 0.3, end: 0),

                        const SizedBox(height: AppTheme.spacingXSmall),

                        // Role badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: isAdmin
                                ? const LinearGradient(colors: [
                                    Color(0xFFFF8C61),
                                    Color(0xFFFF6B35)
                                  ])
                                : isPatient
                                    ? const LinearGradient(colors: [
                                        Color(0xFF4ECDC4),
                                        Color(0xFF44A08D)
                                      ])
                                    : const LinearGradient(colors: [
                                        Color(0xFF667EEA),
                                        Color(0xFF764BA2)
                                      ]),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isAdmin
                                ? 'Admin'
                                : isPatient
                                    ? AppStrings.get('patient', lang)
                                    : AppStrings.get('doctor', lang),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ).animate().fadeIn(delay: 200.ms, duration: 600.ms),

                        const SizedBox(height: AppTheme.spacingXLarge),

                        // --- Common Fields ---
                        _sectionTitle(
                            AppStrings.get('personal_info', lang), isDark),
                        const SizedBox(height: AppTheme.spacingMedium),

                        AuthTextField(
                          controller: _nameController,
                          label: AppStrings.get('full_name', lang),
                          prefixIcon: Icons.person_outlined,
                          validator: (v) => v == null || v.isEmpty
                              ? AppStrings.get('name_required', lang)
                              : null,
                        ),
                        const SizedBox(height: AppTheme.spacingMedium),

                        AuthTextField(
                          controller: _emailController,
                          label: AppStrings.get('email', lang),
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return AppStrings.get('email_required', lang);
                            }
                            if (!v.contains('@')) {
                              return AppStrings.get('email_invalid', lang);
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppTheme.spacingMedium),

                        AuthTextField(
                          controller: _phoneController,
                          label: AppStrings.get('phone_optional', lang),
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: AppTheme.spacingMedium),

                        AuthTextField(
                          controller: _passwordController,
                          label: AppStrings.get('password', lang),
                          prefixIcon: Icons.lock_outlined,
                          obscureText: _obscurePassword,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppTheme.textGray,
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return AppStrings.get('password_required', lang);
                            }
                            if (v.length < 6) {
                              return AppStrings.get('min_6_chars', lang);
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppTheme.spacingMedium),

                        AuthTextField(
                          controller: _confirmPasswordController,
                          label: AppStrings.get('confirm_password', lang),
                          prefixIcon: Icons.lock_outlined,
                          obscureText: _obscureConfirm,
                          suffix: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppTheme.textGray,
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                          ),
                          validator: (v) {
                            if (v != _passwordController.text) {
                              return AppStrings.get('passwords_mismatch', lang);
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: AppTheme.spacingXLarge),

                        // --- Role-Specific Fields ---
                        if (isPatient) ..._buildPatientFields(isDark, lang),
                        if (isDoctor) ..._buildDoctorFields(isDark, lang),

                        const SizedBox(height: AppTheme.spacingXLarge),

                        // Register button
                        AnimatedButton(
                          text: _isLoading
                              ? AppStrings.get('creating_account', lang)
                              : AppStrings.get('create_account', lang),
                          icon: _isLoading ? null : Icons.person_add,
                          onPressed: _isLoading ? () {} : _register,
                          width: double.infinity,
                        ),

                        const SizedBox(height: AppTheme.spacingXLarge),
                      ],
                    ),
                  ),
                ),
              ),

              // Theme toggle
              Positioned(
                top: AppTheme.spacingMedium,
                right: AppTheme.spacingMedium,
                child: const ThemeToggleButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppTheme.primaryOrange,
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.primaryOrange,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  List<Widget> _buildPatientFields(bool isDark, String lang) {
    return [
      _sectionTitle(AppStrings.get('health_info', lang), isDark),
      const SizedBox(height: AppTheme.spacingMedium),

      GestureDetector(
        onTap: _pickDate,
        child: AbsorbPointer(
          child: AuthTextField(
            controller: _dobController,
            label: AppStrings.get('date_of_birth', lang),
            prefixIcon: Icons.calendar_today_outlined,
            hint: 'YYYY-MM-DD',
          ),
        ),
      ),
      const SizedBox(height: AppTheme.spacingMedium),

      // Blood Group dropdown
      DropdownButtonFormField<String>(
        value: _bloodGroup,
        decoration: InputDecoration(
          labelText: AppStrings.get('blood_group', lang),
          prefixIcon: const Icon(Icons.bloodtype_outlined,
              color: AppTheme.primaryOrange, size: 22),
          filled: true,
          fillColor: isDark
              ? AppTheme.darkCard.withOpacity(0.7)
              : Colors.white.withOpacity(0.7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.1),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.1),
            ),
          ),
        ),
        items: _bloodGroups.map((bg) {
          return DropdownMenuItem(
            value: bg,
            child: Text(
                bg.isEmpty ? AppStrings.get('select_blood_group', lang) : bg),
          );
        }).toList(),
        onChanged: (value) => setState(() => _bloodGroup = value ?? ''),
      ),
      const SizedBox(height: AppTheme.spacingXLarge),

      _sectionTitle(AppStrings.get('emergency_contact', lang), isDark),
      const SizedBox(height: AppTheme.spacingMedium),

      AuthTextField(
        controller: _emergencyNameController,
        label: AppStrings.get('contact_name', lang),
        prefixIcon: Icons.person_outline,
      ),
      const SizedBox(height: AppTheme.spacingMedium),

      AuthTextField(
        controller: _emergencyPhoneController,
        label: AppStrings.get('contact_phone', lang),
        prefixIcon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
      ),
      const SizedBox(height: AppTheme.spacingMedium),

      DropdownButtonFormField<String>(
        value: _emergencyRelationship,
        decoration: InputDecoration(
          labelText: AppStrings.get('relationship', lang),
          prefixIcon: const Icon(Icons.people_outlined,
              color: AppTheme.primaryOrange, size: 22),
          filled: true,
          fillColor: isDark
              ? AppTheme.darkCard.withOpacity(0.7)
              : Colors.white.withOpacity(0.7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.1),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.1),
            ),
          ),
        ),
        items: _relationships.map((r) {
          return DropdownMenuItem(
            value: r,
            child: Text(
                r.isEmpty ? AppStrings.get('select_relationship', lang) : r),
          );
        }).toList(),
        onChanged: (value) =>
            setState(() => _emergencyRelationship = value ?? ''),
      ),
    ];
  }

  List<Widget> _buildDoctorFields(bool isDark, String lang) {
    return [
      _sectionTitle(AppStrings.get('professional_info', lang), isDark),
      const SizedBox(height: AppTheme.spacingMedium),
      AuthTextField(
        controller: _specializationController,
        label: AppStrings.get('specialization', lang),
        prefixIcon: Icons.medical_services_outlined,
        validator: (v) => v == null || v.isEmpty
            ? AppStrings.get('specialization_required', lang)
            : null,
      ),
      const SizedBox(height: AppTheme.spacingMedium),
      AuthTextField(
        controller: _licenseController,
        label: AppStrings.get('license_number', lang),
        prefixIcon: Icons.badge_outlined,
        validator: (v) => v == null || v.isEmpty
            ? AppStrings.get('license_required', lang)
            : null,
      ),
      const SizedBox(height: AppTheme.spacingMedium),
      AuthTextField(
        controller: _hospitalController,
        label: AppStrings.get('hospital_name', lang),
        prefixIcon: Icons.local_hospital_outlined,
      ),
    ];
  }
}
