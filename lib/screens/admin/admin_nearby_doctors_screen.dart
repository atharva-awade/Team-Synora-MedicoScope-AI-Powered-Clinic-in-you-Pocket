import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/core/providers/auth_provider.dart';
import 'package:medicoscope/core/constants/api_constants.dart';
import 'package:medicoscope/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';

class AdminNearbyDoctorsScreen extends StatefulWidget {
  const AdminNearbyDoctorsScreen({super.key});

  @override
  State<AdminNearbyDoctorsScreen> createState() => _AdminNearbyDoctorsScreenState();
}

class _AdminNearbyDoctorsScreenState extends State<AdminNearbyDoctorsScreen> {
  List<dynamic> _nearbyDoctors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      final api = ApiService(token: token);
      final response = await api.get(ApiConstants.adminNearbyDoctors);
      if (mounted) {
        setState(() {
          _nearbyDoctors = response['nearbyDoctors'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteDoctor(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Doctor'),
        content: const Text('Are you sure you want to remove this nearby doctor?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      final api = ApiService(token: token);
      await api.delete('${ApiConstants.adminNearbyDoctors}/$id');
      _loadDoctors();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Doctor removed'), backgroundColor: Colors.green.shade400),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Failed to delete'), backgroundColor: Colors.red.shade400),
        );
      }
    }
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
                    Text('Nearby Doctors List', style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800,
                      color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                    )),
                  ],
                ),
              ),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _nearbyDoctors.isEmpty
                        ? Center(child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_off, size: 64,
                                color: isDark ? AppTheme.darkTextDim : AppTheme.textLight),
                              const SizedBox(height: 12),
                              Text('No nearby doctors added yet',
                                style: TextStyle(color: isDark ? AppTheme.darkTextGray : AppTheme.textGray)),
                            ],
                          ))
                        : RefreshIndicator(
                            onRefresh: _loadDoctors,
                            child: ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
                              itemCount: _nearbyDoctors.length,
                              itemBuilder: (context, index) {
                                final doc = _nearbyDoctors[index];
                                return _buildDoctorCard(doc, index);
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

  Widget _buildDoctorCard(Map<String, dynamic> doc, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coords = doc['location']?['coordinates'] as List?;
    final lat = coords != null && coords.length > 1 ? coords[1] : 0;
    final lng = coords != null && coords.isNotEmpty ? coords[0] : 0;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFFF8C61),
                child: const Icon(Icons.person, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc['name'] ?? '', style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                    )),
                    Text(doc['specialization'] ?? '', style: const TextStyle(
                      fontSize: 13, color: Color(0xFFFF6B35), fontWeight: FontWeight.w600,
                    )),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                onPressed: () => _deleteDoctor(doc['_id']),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.local_hospital_outlined, doc['hospitalName'] ?? ''),
          _buildInfoRow(Icons.phone_outlined, doc['contactNumber'] ?? ''),
          if ((doc['address'] ?? '').isNotEmpty)
            _buildInfoRow(Icons.location_on_outlined, doc['address']),
          _buildInfoRow(Icons.explore_outlined, 'Lat: $lat, Lng: $lng'),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 100 * index), duration: 400.ms);
  }

  Widget _buildInfoRow(IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isDark ? AppTheme.darkTextDim : AppTheme.textLight),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(
            fontSize: 12, color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
          ))),
        ],
      ),
    );
  }
}
