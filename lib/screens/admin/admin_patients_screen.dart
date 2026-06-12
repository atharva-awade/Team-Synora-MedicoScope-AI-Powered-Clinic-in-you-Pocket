import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/core/providers/auth_provider.dart';
import 'package:medicoscope/core/constants/api_constants.dart';
import 'package:medicoscope/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';

class AdminPatientsScreen extends StatefulWidget {
  const AdminPatientsScreen({super.key});

  @override
  State<AdminPatientsScreen> createState() => _AdminPatientsScreenState();
}

class _AdminPatientsScreenState extends State<AdminPatientsScreen> {
  List<dynamic> _patients = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      final api = ApiService(token: token);
      final response = await api.get(ApiConstants.adminPatients);
      if (mounted) {
        setState(() {
          _patients = response['patients'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredPatients {
    if (_searchQuery.isEmpty) return _patients;
    return _patients.where((p) {
      final user = p['userId'] as Map<String, dynamic>?;
      final name = (user?['name'] ?? '').toString().toLowerCase();
      final email = (user?['email'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) ||
          email.contains(_searchQuery.toLowerCase());
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
                    Text('All Patients', style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800,
                      color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                    )),
                  ],
                ),
              ),

              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search patients...',
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

              // List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredPatients.isEmpty
                        ? Center(child: Text('No patients found',
                            style: TextStyle(color: isDark ? AppTheme.darkTextGray : AppTheme.textGray)))
                        : RefreshIndicator(
                            onRefresh: _loadPatients,
                            child: ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
                              itemCount: _filteredPatients.length,
                              itemBuilder: (context, index) {
                                final patient = _filteredPatients[index];
                                final user = patient['userId'] as Map<String, dynamic>?;
                                return _buildPatientCard(patient, user, index);
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

  Widget _buildPatientCard(Map<String, dynamic> patient, Map<String, dynamic>? user, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = user?['name'] ?? 'Unknown';
    final email = user?['email'] ?? '';
    final phone = user?['phone'] ?? 'N/A';
    final bloodGroup = patient['bloodGroup'] ?? 'N/A';
    final conditions = (patient['conditions'] as List?)?.join(', ') ?? 'None';

    return GlassCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF4ECDC4),
            child: Text(name[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
          ),
          const SizedBox(width: AppTheme.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                )),
                const SizedBox(height: 2),
                Text(email, style: TextStyle(
                  fontSize: 12, color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
                )),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildInfoChip('Blood: $bloodGroup'),
                    const SizedBox(width: 6),
                    _buildInfoChip('Ph: $phone'),
                  ],
                ),
                if (conditions != 'None') ...[
                  const SizedBox(height: 4),
                  Text('Conditions: $conditions', style: TextStyle(
                    fontSize: 11, color: isDark ? AppTheme.darkTextDim : AppTheme.textLight,
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 100 * index), duration: 400.ms);
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(
        fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.primaryOrange,
      )),
    );
  }
}
