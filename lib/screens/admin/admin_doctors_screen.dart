import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/core/providers/auth_provider.dart';
import 'package:medicoscope/core/constants/api_constants.dart';
import 'package:medicoscope/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';

class AdminDoctorsScreen extends StatefulWidget {
  const AdminDoctorsScreen({super.key});

  @override
  State<AdminDoctorsScreen> createState() => _AdminDoctorsScreenState();
}

class _AdminDoctorsScreenState extends State<AdminDoctorsScreen> {
  List<dynamic> _doctors = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      final api = ApiService(token: token);
      final response = await api.get(ApiConstants.adminDoctors);
      if (mounted) {
        setState(() {
          _doctors = response['doctors'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredDoctors {
    if (_searchQuery.isEmpty) return _doctors;
    return _doctors.where((d) {
      final user = d['userId'] as Map<String, dynamic>?;
      final name = (user?['name'] ?? '').toString().toLowerCase();
      final spec = (d['specialization'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) ||
          spec.contains(_searchQuery.toLowerCase());
    }).toList();
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
                    Text('All Doctors', style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800,
                      color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                    )),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search by name or specialization...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: isDark ? AppTheme.darkCard : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spacingMedium),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredDoctors.isEmpty
                        ? Center(child: Text('No doctors found',
                            style: TextStyle(color: isDark ? AppTheme.darkTextGray : AppTheme.textGray)))
                        : RefreshIndicator(
                            onRefresh: _loadDoctors,
                            child: ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
                              itemCount: _filteredDoctors.length,
                              itemBuilder: (context, index) {
                                final doctor = _filteredDoctors[index];
                                final user = doctor['userId'] as Map<String, dynamic>?;
                                return _buildDoctorCard(doctor, user, index);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctor, Map<String, dynamic>? user, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = user?['name'] ?? 'Unknown';
    final email = user?['email'] ?? '';
    final phone = user?['phone'] ?? 'N/A';
    final specialization = doctor['specialization'] ?? 'N/A';
    final hospital = doctor['hospital'] ?? 'N/A';
    final experience = doctor['yearsOfExperience'] ?? 0;
    final patientsCount = (doctor['linkedPatients'] as List?)?.length ?? 0;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF667EEA),
            child: Text(name[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
          ),
          const SizedBox(width: AppTheme.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dr. $name', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                )),
                const SizedBox(height: 2),
                Text(specialization, style: const TextStyle(
                  fontSize: 13, color: Color(0xFF667EEA), fontWeight: FontWeight.w600,
                )),
                const SizedBox(height: 4),
                Text('$email | $phone', style: TextStyle(
                  fontSize: 11, color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
                )),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildInfoChip('$hospital'),
                    const SizedBox(width: 6),
                    _buildInfoChip('${experience}y exp'),
                    const SizedBox(width: 6),
                    _buildInfoChip('$patientsCount patients'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 100 * index), duration: 400.ms);
  }

  Widget _buildInfoChip(String text) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF667EEA).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: const TextStyle(
          fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF667EEA),
        ), overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
