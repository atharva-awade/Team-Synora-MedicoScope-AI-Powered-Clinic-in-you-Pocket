import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/services/overpass_hospitals_service.dart';
import 'package:medicoscope/services/specialty_recommender.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class NearbyDoctorsScreen extends StatefulWidget {
  const NearbyDoctorsScreen({super.key});

  @override
  State<NearbyDoctorsScreen> createState() => _NearbyDoctorsScreenState();
}

class _NearbyDoctorsScreenState extends State<NearbyDoctorsScreen> {
  final MapController _mapController = MapController();

  LatLng? _userLocation;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _locationError = false;

  List<SpecialtyRecommendation> _recommendations = const [];
  List<Hospital> _hospitals = const [];
  Hospital? _selected;
  bool _listExpanded = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    setState(() {
      _isLoading = true;
      _locationError = false;
      _errorMessage = '';
    });

    try {
      // 1. Is the GPS hardware toggled on?
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _locationError = true;
          _errorMessage =
              'Location services are turned off on your device. Enable GPS and tap Try Again.';
          _isLoading = false;
        });
        return;
      }

      // 2. Ask the user for permission — this pops the Android dialog.
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _locationError = true;
          _errorMessage =
              'MedicoScope needs location access to find hospitals near you. '
              'Tap Try Again to grant it.';
          _isLoading = false;
        });
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _locationError = true;
          _errorMessage =
              'Location access was denied permanently. Open app settings and enable location, then come back.';
          _isLoading = false;
        });
        return;
      }

      // 3. Read a fresh fix. Use medium accuracy with a 15-second timeout so
      //    we don't hang forever when GPS is warming up.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      ).catchError((_) async {
        return await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition();
      });

      _userLocation = LatLng(position.latitude, position.longitude);
      _recommendations = await SpecialtyRecommender.recommend();

      // Move the map immediately to the user — loadHospitals will fit bounds.
      if (mounted) {
        setState(() {});
        try {
          _mapController.move(_userLocation!, 14);
        } catch (_) {}
      }

      await _loadHospitals();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = true;
        _errorMessage =
            'Could not determine your location. Check GPS + internet and tap Try Again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadHospitals() async {
    if (_userLocation == null) return;
    setState(() => _isLoading = true);

    try {
      final raw = await OverpassHospitalsService.fetchNearby(
        center: _userLocation!,
        radiusMeters: 20000,
      );
      final rankedSpecs = _recommendations.map((r) => r.specialty).toList();
      final ranked =
          OverpassHospitalsService.rankByRecommendation(raw, rankedSpecs);

      if (!mounted) return;
      setState(() {
        _hospitals = ranked;
        _isLoading = false;
      });

      // Recenter map to fit user + top hospital
      if (ranked.isNotEmpty && _userLocation != null) {
        _fitBounds(_userLocation!, ranked.take(10).map((h) => h.location));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Could not load hospitals from OpenStreetMap. Please try again.';
      });
    }
  }

  void _fitBounds(LatLng center, Iterable<LatLng> points) {
    if (points.isEmpty) {
      _mapController.move(center, 14);
      return;
    }
    final all = [center, ...points];
    double minLat = all.first.latitude;
    double maxLat = all.first.latitude;
    double minLng = all.first.longitude;
    double maxLng = all.first.longitude;
    for (final p in all) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(40, 80, 40, 260),
      ),
    );
  }

  /// Launch Google Maps turn-by-turn navigation to the selected hospital.
  /// Tries in order:
  ///   1. Android: `google.navigation:` — opens the Google Maps app directly
  ///      in navigation mode (driving, turn-by-turn).
  ///   2. iOS / universal: `comgooglemaps://` app URL scheme with a
  ///      "directions" action.
  ///   3. Fallback: the https://google.com/maps/dir?... web URL which opens
  ///      in the Google Maps app if installed, otherwise the browser.
  Future<void> _openDirections(Hospital h) async {
    final lat = h.location.latitude;
    final lng = h.location.longitude;

    // Android navigation deep link — starts turn-by-turn immediately.
    final androidNav = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    // iOS + web universal — opens the Maps app if installed.
    final iosApp = Uri.parse(
        'comgooglemaps://?daddr=$lat,$lng&directionsmode=driving');
    // HTTPS fallback — intent filter on Android forwards this to the
    // Maps app; on other platforms it opens in the browser.
    final httpsFallback = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');

    for (final uri in [androidNav, iosApp, httpsFallback]) {
      try {
        if (await canLaunchUrl(uri)) {
          final ok = await launchUrl(uri,
              mode: LaunchMode.externalApplication);
          if (ok) return;
        }
      } catch (_) {
        // Keep trying the next scheme.
      }
    }

    // Last-resort: force-launch the HTTPS URL even if canLaunchUrl failed.
    try {
      await launchUrl(httpsFallback, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _callHospital(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: _locationError
          ? Container(
              decoration: BoxDecoration(
                gradient: isDark
                    ? AppTheme.darkBackgroundGradient
                    : AppTheme.backgroundGradient,
              ),
              child: SafeArea(child: _buildLocationError(isDark)),
            )
          : Stack(
              children: [
                Positioned.fill(child: _buildMap(isDark)),
                SafeArea(child: _buildTopBar(isDark)),
                if (_isLoading) _buildLoadingOverlay(isDark),
                _buildBottomSheet(isDark),
              ],
            ),
    );
  }

  Widget _buildMap(bool isDark) {
    final user = _userLocation ?? const LatLng(28.6139, 77.2090); // Delhi fallback
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: user,
        initialZoom: 14,
        onTap: (_, __) => setState(() => _selected = null),
      ),
      children: [
        TileLayer(
          urlTemplate: isDark
              ? 'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}.png'
              : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.medicoscope.app',
        ),
        // User location marker
        if (_userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _userLocation!,
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ECDC4).withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ECDC4),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4ECDC4).withOpacity(0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        // Hospital markers with permanent name labels (top 25 by score)
        MarkerLayer(
          markers: _hospitals.take(25).map((h) {
            final isRecommended = h.relevanceScore >= 3;
            final isSelected = _selected?.id == h.id;
            final pinColor = isRecommended
                ? const Color(0xFFFF5252)
                : const Color(0xFF7C4DFF);
            return Marker(
              point: h.location,
              // Wider + taller marker so the name label fits beside the pin.
              width: 180,
              height: 72,
              alignment: Alignment.topCenter,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() => _selected = h);
                  _mapController.move(h.location, 16);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name chip
                    Container(
                      constraints: const BoxConstraints(maxWidth: 160),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: pinColor.withOpacity(0.4), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        h.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: pinColor,
                        ),
                      ),
                    ),
                    // Pointer triangle
                    CustomPaint(
                      size: const Size(10, 5),
                      painter: _TrianglePainter(color: pinColor),
                    ),
                    // Pin circle
                    Container(
                      width: isSelected ? 38 : (isRecommended ? 32 : 26),
                      height: isSelected ? 38 : (isRecommended ? 32 : 26),
                      decoration: BoxDecoration(
                        color: pinColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isRecommended
                            ? Icons.local_hospital_rounded
                            : Icons.medical_services_rounded,
                        color: Colors.white,
                        size: isSelected ? 20 : 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          children: [
            Row(
              children: [
                _circleButton(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.of(context).pop(),
                  isDark: isDark,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GlassCard(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            color: const Color(0xFF4ECDC4), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nearby Hospitals',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? AppTheme.darkTextLight
                                      : AppTheme.textDark,
                                ),
                              ),
                              Text(
                                _isLoading
                                    ? 'Scanning…'
                                    : '${_hospitals.length} places found on map',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark
                                      ? AppTheme.darkTextGray
                                      : AppTheme.textGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _circleButton(
                  icon: Icons.my_location,
                  onTap: _initLocation,
                  isDark: isDark,
                ),
              ],
            ),
            if (_recommendations.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildRecommendationChips(isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationChips(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: Color(0xFF7C4DFF), size: 15),
              const SizedBox(width: 6),
              Text(
                'Recommended based on your screenings',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _recommendations.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (ctx, i) {
                final r = _recommendations[i];
                final c = _riskColor(r.risk);
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration:
                            BoxDecoration(color: c, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        r.specialty,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: c,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(bool isDark) {
    final selected = _selected;
    if (selected != null) return _buildSelectedCard(selected, isDark);

    // Expandable bottom panel that doesn't block map gestures.
    // When collapsed (default) it's just a small header strip the user can
    // tap to expand into a full hospital list.
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: _listExpanded ? 380 : 62,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  setState(() => _listExpanded = !_listExpanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white24
                            : Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.local_hospital_rounded,
                            color: Color(0xFFFF5252), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Hospitals near you',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppTheme.darkTextLight
                                : AppTheme.textDark,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _hospitals.isEmpty
                              ? '—'
                              : '${_hospitals.length} places',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppTheme.darkTextGray
                                : AppTheme.textGray,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          _listExpanded
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_up_rounded,
                          color: isDark
                              ? AppTheme.darkTextGray
                              : AppTheme.textGray,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_listExpanded)
              Expanded(
                child: _hospitals.isEmpty && !_isLoading
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                        itemCount: _hospitals.length,
                        itemBuilder: (_, i) =>
                            _buildHospitalCard(_hospitals[i], i, isDark),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedCard(Hospital h, bool isDark) {
    final isRecommended = h.relevanceScore >= 3;
    return Positioned(
      bottom: 16,
      left: 12,
      right: 12,
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (isRecommended
                            ? const Color(0xFFFF5252)
                            : const Color(0xFF7C4DFF))
                        .withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.local_hospital_rounded,
                    color: isRecommended
                        ? const Color(0xFFFF5252)
                        : const Color(0xFF7C4DFF),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppTheme.darkTextLight
                              : AppTheme.textDark,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.place,
                              size: 12,
                              color: isDark
                                  ? AppTheme.darkTextGray
                                  : AppTheme.textGray),
                          const SizedBox(width: 3),
                          Text(
                            h.distanceLabel,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark
                                  ? AppTheme.darkTextGray
                                  : AppTheme.textGray,
                            ),
                          ),
                          if (isRecommended) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5252)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'RECOMMENDED',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFFF5252),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _selected = null),
                  icon: const Icon(Icons.close, size: 20),
                  color:
                      isDark ? AppTheme.darkTextGray : AppTheme.textGray,
                ),
              ],
            ),
            if (h.address != null) ...[
              const SizedBox(height: 6),
              Text(
                h.address!,
                style: TextStyle(
                  fontSize: 11.5,
                  color:
                      isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                ),
              ),
            ],
            if (h.specialty != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.medical_services_outlined,
                      size: 12,
                      color: isDark
                          ? AppTheme.darkTextGray
                          : AppTheme.textGray),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      h.specialty!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.darkTextGray
                            : AppTheme.textGray,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openDirections(h),
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text('Directions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4ECDC4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                if (h.phone != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _callHospital(h.phone!),
                      icon: const Icon(Icons.call, size: 18),
                      label: const Text('Call'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4ECDC4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF4ECDC4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildHospitalCard(Hospital h, int index, bool isDark) {
    final isRecommended = h.relevanceScore >= 3;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: GestureDetector(
        onTap: () {
          setState(() => _selected = h);
          _mapController.move(h.location, 16);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.grey.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: isRecommended
                ? Border.all(
                    color: const Color(0xFFFF5252).withOpacity(0.5), width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (isRecommended
                          ? const Color(0xFFFF5252)
                          : const Color(0xFF7C4DFF))
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.local_hospital_rounded,
                  color: isRecommended
                      ? const Color(0xFFFF5252)
                      : const Color(0xFF7C4DFF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            h.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppTheme.darkTextLight
                                  : AppTheme.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isRecommended)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5252).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'RECOMMENDED',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFF5252),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${h.distanceLabel}${h.specialty != null ? " • ${h.specialty}" : ""}',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            isDark ? AppTheme.darkTextGray : AppTheme.textGray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
              ),
            ],
          ),
        ),
      )
          .animate()
          .fadeIn(delay: Duration(milliseconds: 40 * index), duration: 250.ms)
          .slideY(begin: 0.05, end: 0),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined,
              size: 48,
              color: isDark ? AppTheme.darkTextDim : AppTheme.textLight),
          const SizedBox(height: 8),
          Text('No hospitals found in OSM',
              style: TextStyle(
                  fontSize: 13,
                  color:
                      isDark ? AppTheme.darkTextGray : AppTheme.textGray)),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay(bool isDark) {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 14,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Color(0xFF4ECDC4)),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Loading hospitals from OpenStreetMap…',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleButton(
      {required IconData icon,
      required VoidCallback onTap,
      required bool isDark}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Icon(
          icon,
          color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildLocationError(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off,
                size: 80,
                color: isDark ? AppTheme.darkTextDim : AppTheme.textLight),
            const SizedBox(height: 16),
            Text(
              'Location Required',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _initLocation,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ECDC4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Color _riskColor(dynamic r) {
    final label = r.toString();
    if (label.contains('critical')) return const Color(0xFFD32F2F);
    if (label.contains('high')) return const Color(0xFFFF5252);
    if (label.contains('moderate')) return const Color(0xFFFF9800);
    return const Color(0xFF4CAF50);
  }
}

/// Small downward triangle that visually connects the name chip to the pin.
class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
