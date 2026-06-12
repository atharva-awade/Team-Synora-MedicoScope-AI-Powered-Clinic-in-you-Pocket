import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/widgets/auth_text_field.dart';
import 'package:medicoscope/core/widgets/animated_button.dart';
import 'package:medicoscope/core/providers/auth_provider.dart';
import 'package:medicoscope/core/constants/api_constants.dart';
import 'package:medicoscope/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';
import 'package:geolocator/geolocator.dart';

class AddNearbyDoctorScreen extends StatefulWidget {
  const AddNearbyDoctorScreen({super.key});

  @override
  State<AddNearbyDoctorScreen> createState() => _AddNearbyDoctorScreenState();
}

class _AddNearbyDoctorScreenState extends State<AddNearbyDoctorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  String _selectedSpecialization = 'General Physician';
  bool _isLoading = false;
  bool _isFetchingLocation = false;

  static const List<String> specializations = [
    'General Physician',
    'Cardiologist',
    'Dermatologist',
    'Orthopedic',
    'Pediatrician',
    'Neurologist',
    'Psychiatrist',
    'Ophthalmologist',
    'ENT Specialist',
    'Gynecologist',
    'Urologist',
    'Dentist',
    'Pulmonologist',
    'Gastroenterologist',
    'Oncologist',
    'Endocrinologist',
    'Nephrologist',
    'Rheumatologist',
    'Surgeon',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _hospitalController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permission denied');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showError('Location permission permanently denied. Enable it in settings.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _latController.text = position.latitude.toStringAsFixed(6);
        _lngController.text = position.longitude.toStringAsFixed(6);
      });
    } catch (e) {
      _showError('Failed to get location: $e');
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      final api = ApiService(token: token);
      await api.post(ApiConstants.adminNearbyDoctors, {
        'name': _nameController.text.trim(),
        'hospitalName': _hospitalController.text.trim(),
        'contactNumber': _contactController.text.trim(),
        'specialization': _selectedSpecialization,
        'latitude': double.parse(_latController.text.trim()),
        'longitude': double.parse(_lngController.text.trim()),
        'address': _addressController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Nearby doctor added successfully!'),
            backgroundColor: Colors.green.shade400,
          ),
        );
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Failed to add doctor');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade400),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

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
              // App Bar
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMedium),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Icon(Icons.arrow_back,
                          color: isDark ? AppTheme.darkTextLight : AppTheme.textDark),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMedium),
                    Text('Add Nearby Doctor', style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800,
                      color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                    )),
                  ],
                ),
              ),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(AppTheme.spacingXLarge),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AuthTextField(
                          controller: _nameController,
                          label: 'Doctor Name',
                          hint: 'Enter doctor\'s full name',
                          prefixIcon: Icons.person_outlined,
                          validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
                        ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                        const SizedBox(height: AppTheme.spacingMedium),

                        AuthTextField(
                          controller: _hospitalController,
                          label: 'Hospital Name',
                          hint: 'Enter hospital/clinic name',
                          prefixIcon: Icons.local_hospital_outlined,
                          validator: (v) => v == null || v.isEmpty ? 'Hospital name is required' : null,
                        ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                        const SizedBox(height: AppTheme.spacingMedium),

                        AuthTextField(
                          controller: _contactController,
                          label: 'Contact Number',
                          hint: 'Enter phone number',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (v) => v == null || v.isEmpty ? 'Contact number is required' : null,
                        ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

                        const SizedBox(height: AppTheme.spacingMedium),

                        // Specialization dropdown
                        Text('Specialization', style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                        )),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedSpecialization,
                              isExpanded: true,
                              dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
                              items: specializations.map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s),
                              )).toList(),
                              onChanged: (v) => setState(() => _selectedSpecialization = v!),
                            ),
                          ),
                        ).animate().fadeIn(delay: 500.ms, duration: 400.ms),

                        const SizedBox(height: AppTheme.spacingMedium),

                        AuthTextField(
                          controller: _addressController,
                          label: 'Address (Optional)',
                          hint: 'Enter clinic/hospital address',
                          prefixIcon: Icons.location_on_outlined,
                        ).animate().fadeIn(delay: 600.ms, duration: 400.ms),

                        const SizedBox(height: AppTheme.spacingMedium),

                        // Location fields
                        Row(
                          children: [
                            Text('Location', style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                            )),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _isFetchingLocation ? null : _getCurrentLocation,
                              icon: _isFetchingLocation
                                  ? const SizedBox(width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.my_location, size: 18),
                              label: Text(_isFetchingLocation ? 'Getting...' : 'Use Current Location'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: AuthTextField(
                                controller: _latController,
                                label: 'Latitude',
                                hint: 'e.g. 17.6784',
                                prefixIcon: Icons.explore_outlined,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Required';
                                  final n = double.tryParse(v);
                                  if (n == null || n < -90 || n > 90) return 'Invalid';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AuthTextField(
                                controller: _lngController,
                                label: 'Longitude',
                                hint: 'e.g. 75.3312',
                                prefixIcon: Icons.explore_outlined,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Required';
                                  final n = double.tryParse(v);
                                  if (n == null || n < -180 || n > 180) return 'Invalid';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: 700.ms, duration: 400.ms),

                        const SizedBox(height: AppTheme.spacingXLarge),

                        AnimatedButton(
                          text: _isLoading ? 'Adding...' : 'Add Doctor',
                          icon: _isLoading ? null : Icons.add_location_alt,
                          onPressed: _isLoading ? () {} : _submit,
                          width: double.infinity,
                        ).animate().fadeIn(delay: 800.ms, duration: 400.ms),

                        const SizedBox(height: AppTheme.spacingXLarge),
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
}
