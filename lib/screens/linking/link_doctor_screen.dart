import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/widgets/animated_button.dart';
import 'package:medicoscope/core/widgets/auth_text_field.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/core/providers/auth_provider.dart';
import 'package:medicoscope/core/locale/locale_provider.dart';
import 'package:medicoscope/core/locale/app_strings.dart';
import 'package:medicoscope/services/api_service.dart';
import 'package:medicoscope/core/constants/api_constants.dart';
import 'package:provider/provider.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';

class LinkDoctorScreen extends StatefulWidget {
  const LinkDoctorScreen({super.key});

  @override
  State<LinkDoctorScreen> createState() => _LinkDoctorScreenState();
}

class _LinkDoctorScreenState extends State<LinkDoctorScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _linkedDoctorName;

  @override
  void initState() {
    super.initState();
    _fetchLinkedDoctor();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _fetchLinkedDoctor() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) return;

    try {
      final api = ApiService(token: authProvider.token);
      final response = await api.get(ApiConstants.patientDoctor);
      if (response['doctor'] != null) {
        setState(() {
          _linkedDoctorName = response['doctor']['name'];
        });
      }
    } catch (_) {}
  }

  Future<void> _linkDoctor() async {
    final lang = Provider.of<LocaleProvider>(context, listen: false).languageCode;
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.get('enter_doctor_code', lang))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final api = ApiService(token: authProvider.token);
      final response = await api.post(ApiConstants.patientLink, {
        'doctorCode': code,
      });

      if (!mounted) return;

      setState(() {
        _linkedDoctorName = response['doctor']?['name'] ?? 'Doctor';
        _codeController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.format('linked_success', lang, {'name': _linkedDoctorName ?? ''})),
          backgroundColor: Colors.green.shade400,
        ),
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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
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

                  const SizedBox(height: AppTheme.spacingXLarge),

                  Text(
                    AppStrings.get('link_to_doctor', lang),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .slideY(begin: 0.3, end: 0),

                  const SizedBox(height: AppTheme.spacingSmall),

                  Text(
                    AppStrings.get('link_doctor_desc', lang),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 600.ms),

                  const SizedBox(height: AppTheme.spacingXLarge),

                  // Current linked doctor
                  if (_linkedDoctorName != null)
                    GlassCard(
                      padding: const EdgeInsets.all(AppTheme.spacingMedium),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            ),
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green.shade600,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingMedium),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.get('currently_linked', lang),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
                                ),
                              ),
                              Text(
                                'Dr. $_linkedDoctorName',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 300.ms, duration: 600.ms),

                  if (_linkedDoctorName != null)
                    const SizedBox(height: AppTheme.spacingLarge),

                  // Enter code
                  AuthTextField(
                    controller: _codeController,
                    label: AppStrings.get('doctor_code', lang),
                    hint: AppStrings.get('doctor_code_hint', lang),
                    prefixIcon: Icons.link,
                  )
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 600.ms)
                      .slideY(begin: 0.2, end: 0),

                  const SizedBox(height: AppTheme.spacingLarge),

                  AnimatedButton(
                    text: _isLoading ? AppStrings.get('linking', lang) : AppStrings.get('link_doctor_btn', lang),
                    icon: Icons.link,
                    onPressed: _isLoading ? () {} : _linkDoctor,
                    width: double.infinity,
                  )
                      .animate()
                      .fadeIn(delay: 500.ms, duration: 600.ms)
                      .slideY(begin: 0.2, end: 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
