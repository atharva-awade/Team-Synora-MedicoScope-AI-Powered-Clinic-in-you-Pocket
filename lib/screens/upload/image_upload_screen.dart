import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/core/widgets/animated_button.dart';
import 'package:medicoscope/core/widgets/theme_toggle_button.dart';
import 'package:medicoscope/core/locale/locale_provider.dart';
import 'package:medicoscope/core/locale/app_strings.dart';
import 'package:medicoscope/services/tflite_service.dart';
import 'package:medicoscope/services/detection_service.dart';
import 'package:medicoscope/services/disease_alert_service.dart';
import 'package:medicoscope/services/disease_result_pipeline.dart';
import 'package:medicoscope/screens/results/detection_results_screen.dart';
import 'package:medicoscope/core/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';

class ImageUploadScreen extends StatefulWidget {
  final String category;
  final String? patientId;

  const ImageUploadScreen({
    super.key,
    required this.category,
    this.patientId,
  });

  @override
  State<ImageUploadScreen> createState() => _ImageUploadScreenState();
}

class _ImageUploadScreenState extends State<ImageUploadScreen> {
  final ImagePicker _picker = ImagePicker();
  final TFLiteService _tfliteService = TFLiteService();
  File? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      await _tfliteService.loadModel(widget.category);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading model: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;

    setState(() => _isLoading = true);

    try {
      final result = await _tfliteService.runInference(_selectedImage!);

      if (mounted) {
        if (result != null) {
          // Save detection result to MongoDB (no image, metadata only)
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          if (authProvider.isAuthenticated && authProvider.token != null) {
            final detectionService = DetectionService(authProvider.token!);
            detectionService.saveRecord(
              className: result.className,
              confidence: result.confidence,
              category: result.category,
              description: result.description,
              patientId: widget.patientId,
            );
          }

          // Fire a doctor alert for high-confidence malignant findings.
          final lowerName = result.className.toLowerCase();
          final isMalignant = lowerName.contains('melanoma') ||
              lowerName.contains('carcinoma') ||
              lowerName.contains('cancer') ||
              (lowerName.contains('actinic') && result.confidence > 0.6);
          if (isMalignant &&
              result.confidence > 0.5 &&
              authProvider.user != null) {
            final doctorId = await DiseaseResultPipeline.resolveDoctorIdFor(
                authProvider.token);
            if (doctorId != null && doctorId.isNotEmpty) {
              await DiseaseAlertService.sendGenericAlert(
                doctorId: doctorId,
                patientId: authProvider.user!.id,
                patientName: authProvider.user!.name,
                clinicalReport:
                    'Skin lesion scan: ${result.className} '
                    '(${(result.confidence * 100).toStringAsFixed(1)}% confidence).\n'
                    '${result.description}',
                urgency: result.confidence > 0.75 ? 'high' : 'moderate',
                source: 'skin_scan',
              );
            }
          }

          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  DetectionResultsScreen(
                result: result,
                imageFile: _selectedImage!,
              ),
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
          );
        } else {
          final snackLang = Provider.of<LocaleProvider>(context, listen: false).languageCode;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.get('no_condition_detected', snackLang)),
              backgroundColor: AppTheme.primaryOrange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error analyzing image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _tfliteService.dispose();
    super.dispose();
  }

  String _getCategoryTitle(String lang) {
    switch (widget.category) {
      case 'skin':
        return AppStrings.get('skin_scan', lang);
      case 'eye':
        return 'Eye / Fundus';
      default:
        return AppStrings.get('medical_image', lang);
    }
  }

  IconData _getCategoryIcon() {
    switch (widget.category) {
      case 'skin':
        return Icons.face_outlined;
      case 'eye':
        return Icons.remove_red_eye_outlined;
      default:
        return Icons.medical_services_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final lang = Provider.of<LocaleProvider>(context).languageCode;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBackgroundGradient : AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMedium),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios),
                      color: AppTheme.textDark,
                    ),
                    Expanded(
                      child: Text(
                        _getCategoryTitle(lang),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
              ),
              
              // Theme toggle button
              Padding(
                padding: const EdgeInsets.only(
                  top: AppTheme.spacingMedium,
                  right: AppTheme.spacingMedium,
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: const ThemeToggleButton(size: 36),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(AppTheme.spacingLarge),
                  child: Column(
                    children: [
                      // Category Icon
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.orangeGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryOrange.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          _getCategoryIcon(),
                          size: 50,
                          color: Colors.white,
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 600.ms)
                          .scale(begin: const Offset(0.8, 0.8)),

                      const SizedBox(height: AppTheme.spacingXLarge),

                      // Image Preview or Placeholder
                      GlassCard(
                        padding: EdgeInsets.zero,
                        child: _selectedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusLarge),
                                child: Image.file(
                                  _selectedImage!,
                                  height: 300,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Container(
                                height: 250,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusLarge),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 64,
                                      color: AppTheme.textLight,
                                    ),
                                    const SizedBox(height: AppTheme.spacingMedium),
                                    Text(
                                      AppStrings.get('no_image_selected', lang),
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: AppTheme.textGray,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      )
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 600.ms)
                          .slideY(begin: 0.2, end: 0),

                      const SizedBox(height: AppTheme.spacingXLarge),

                      // Upload Options
                      Text(
                        AppStrings.get('choose_image_source', lang),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 400.ms, duration: 600.ms),

                      const SizedBox(height: AppTheme.spacingLarge),

                      // Camera Button
                      AnimatedButton(
                        text: AppStrings.get('take_photo', lang),
                        icon: Icons.camera_alt_outlined,
                        onPressed: () => _pickImage(ImageSource.camera),
                        width: double.infinity,
                      )
                          .animate()
                          .fadeIn(delay: 500.ms, duration: 600.ms)
                          .slideX(begin: -0.2, end: 0),

                      const SizedBox(height: AppTheme.spacingMedium),

                      // Gallery Button
                      AnimatedButton(
                        text: AppStrings.get('upload_gallery', lang),
                        icon: Icons.photo_library_outlined,
                        onPressed: () => _pickImage(ImageSource.gallery),
                        width: double.infinity,
                        isOutlined: true,
                      )
                          .animate()
                          .fadeIn(delay: 600.ms, duration: 600.ms)
                          .slideX(begin: 0.2, end: 0),

                      if (_selectedImage != null) ...[
                        const SizedBox(height: AppTheme.spacingXLarge),

                        // Analyze Button
                        AnimatedButton(
                          text: _isLoading ? AppStrings.get('analyzing_image', lang) : AppStrings.get('analyze_image', lang),
                          icon: _isLoading ? null : Icons.analytics_outlined,
                          onPressed: _isLoading ? () {} : _analyzeImage,
                          width: double.infinity,
                          backgroundColor: Colors.green.shade600,
                        )
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.2, end: 0),
                      ],

                      if (_isLoading) ...[
                        const SizedBox(height: AppTheme.spacingLarge),
                        const CircularProgressIndicator(
                          color: AppTheme.primaryOrange,
                        ),
                      ],
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
}
