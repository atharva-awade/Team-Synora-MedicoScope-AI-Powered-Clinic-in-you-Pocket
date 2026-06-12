import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// One nearby medical facility. Keeps the old name `Hospital` for backward
/// compat with the UI layer.
class Hospital {
  final String id;
  final String name;
  final LatLng location;
  final double distanceMeters;
  final String? phone;
  final String? address;
  final String? specialty;    // from name heuristics
  final List<String> tags;    // lowercased tokens used for ranking
  final double relevanceScore;

  const Hospital({
    required this.id,
    required this.name,
    required this.location,
    required this.distanceMeters,
    this.phone,
    this.address,
    this.specialty,
    this.tags = const [],
    this.relevanceScore = 0,
  });

  String get distanceLabel => distanceMeters < 1000
      ? '${distanceMeters.toStringAsFixed(0)} m away'
      : '${(distanceMeters / 1000).toStringAsFixed(1)} km away';
}

/// Hospital search service. Uses Nominatim (OpenStreetMap's geocoder) which
/// has far better coverage than raw Overpass tag queries — Nominatim's
/// free-text search hits any POI whose name / category contains the keyword
/// without requiring a specific OSM tag.
///
/// The service issues several parallel queries ("hospital", "clinic",
/// "medical", + the patient's top recommended specialty) around the user's
/// location, dedupes, scores, and returns the top results.
class OverpassHospitalsService {
  static const _endpoint = 'https://nominatim.openstreetmap.org/search';

  /// Keyword list used per recommended specialty. We also use these as
  /// free-text queries so a result that only has "Eye Clinic" in its name
  /// (no OSM `healthcare:speciality` tag) still ranks for ophthalmology.
  static const Map<String, List<String>> specialtyKeywords = {
    'Endocrinologist': ['endocrin', 'diabet'],
    'Diabetologist': ['diabet', 'endocrin'],
    'Ophthalmologist': ['ophthalm', 'eye', 'vision', 'retin', 'netra'],
    'Cardiologist': ['cardio', 'heart'],
    'Nephrologist': ['nephro', 'renal', 'kidney', 'dialysis'],
    'Hematologist': ['hemat', 'blood', 'haematolog'],
    'Gynecologist': ['gynae', 'gyneco', 'women', 'obstet', 'maternity'],
    'General Physician': ['general', 'family', 'physician', 'clinic'],
  };

  /// Fetch nearby medical facilities. Uses Nominatim's free-text search
  /// which reliably covers hospitals, clinics, nursing homes, doctors'
  /// offices, pharmacies, and any named medical POI in India + USA.
  static Future<List<Hospital>> fetchNearby({
    required LatLng center,
    int radiusMeters = 10000,
  }) async {
    final viewbox = _viewboxAround(center, radiusMeters);

    // Serialise the queries — Nominatim's public endpoint enforces a
    // 1 req/sec policy per IP, so parallel bursts get rate-limited.
    final queries = <String>[
      'hospital',
      'clinic',
      'medical',
      'doctors',
      'nursing home',
    ];

    final results = <List<_RawPlace>>[];
    for (final q in queries) {
      results.add(await _searchNominatim(q, viewbox: viewbox));
      // Tiny spacer between requests to stay within policy.
      await Future.delayed(const Duration(milliseconds: 250));
    }

    // Flatten + dedupe by osm_id.
    final seen = <String>{};
    final combined = <_RawPlace>[];
    for (final list in results) {
      for (final p in list) {
        final key = '${p.osmType}${p.osmId}';
        if (seen.add(key)) combined.add(p);
      }
    }

    // Convert to Hospital + compute distance.
    final distance = const Distance();
    final hospitals = <Hospital>[];
    for (final p in combined) {
      final dist = distance.as(LengthUnit.Meter, center, p.location).toDouble();
      if (dist > radiusMeters * 1.4) continue; // Nominatim viewbox is loose
      hospitals.add(Hospital(
        id: '${p.osmType}${p.osmId}',
        name: p.name,
        location: p.location,
        distanceMeters: dist,
        address: p.address,
        specialty: p.category,
        tags: [p.name, p.address ?? '', p.category]
            .join(' ')
            .toLowerCase()
            .split(RegExp(r'[\s,]+'))
            .where((t) => t.isNotEmpty)
            .toList(),
      ));
    }

    hospitals.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return hospitals;
  }

  /// Boost hospitals whose name / tags match a recommended specialty.
  static List<Hospital> rankByRecommendation(
    List<Hospital> hospitals,
    List<String> rankedSpecialties,
  ) {
    if (hospitals.isEmpty) return hospitals;

    final scored = hospitals.map((h) {
      double score = 0;
      final haystack = '${h.name} ${h.tags.join(' ')}'.toLowerCase();
      for (int i = 0; i < rankedSpecialties.length; i++) {
        final spec = rankedSpecialties[i];
        final keywords = specialtyKeywords[spec] ?? [spec.toLowerCase()];
        for (final kw in keywords) {
          if (haystack.contains(kw.toLowerCase())) {
            score += math.max(5 - i, 1).toDouble();
            break;
          }
        }
      }
      if (h.distanceMeters < 1000) {
        score += 2;
      } else if (h.distanceMeters < 3000) {
        score += 1;
      }
      return Hospital(
        id: h.id,
        name: h.name,
        location: h.location,
        distanceMeters: h.distanceMeters,
        phone: h.phone,
        address: h.address,
        specialty: h.specialty,
        tags: h.tags,
        relevanceScore: score,
      );
    }).toList();

    scored.sort((a, b) {
      final cmp = b.relevanceScore.compareTo(a.relevanceScore);
      if (cmp != 0) return cmp;
      return a.distanceMeters.compareTo(b.distanceMeters);
    });

    return scored;
  }

  static String _viewboxAround(LatLng center, int radiusMeters) {
    // Rough conversion: 1° lat ≈ 111 km, 1° lng ≈ 111*cos(lat) km
    final degLat = radiusMeters / 111000;
    final degLng = radiusMeters / (111000 * math.cos(center.latitude * math.pi / 180).abs());
    final left = center.longitude - degLng;
    final right = center.longitude + degLng;
    final top = center.latitude + degLat;
    final bottom = center.latitude - degLat;
    return '$left,$top,$right,$bottom';
  }

  static Future<List<_RawPlace>> _searchNominatim(
    String query, {
    required String viewbox,
  }) async {
    final uri = Uri.parse('$_endpoint?q=${Uri.encodeQueryComponent(query)}'
        '&format=json&limit=30&viewbox=$viewbox&bounded=1&addressdetails=1');
    try {
      final resp = await http.get(
        uri,
        headers: {
          // Nominatim usage policy requires a descriptive User-Agent.
          'User-Agent': 'MedicoScopeApp/1.0 (hackathon)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return const [];
      final list = jsonDecode(resp.body) as List;
      return list
          .map((e) => _RawPlace.fromJson(e as Map<String, dynamic>))
          .whereType<_RawPlace>()
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

class _RawPlace {
  final String osmType;
  final String osmId;
  final String name;
  final LatLng location;
  final String category;
  final String? address;

  const _RawPlace({
    required this.osmType,
    required this.osmId,
    required this.name,
    required this.location,
    required this.category,
    this.address,
  });

  static _RawPlace? fromJson(Map<String, dynamic> j) {
    final lat = double.tryParse(j['lat']?.toString() ?? '');
    final lon = double.tryParse(j['lon']?.toString() ?? '');
    if (lat == null || lon == null) return null;

    final name = j['name']?.toString() ??
        (j['display_name']?.toString().split(',').first ?? '').trim();
    if (name.isEmpty) return null;

    final cls = j['class']?.toString() ?? '';
    final type = j['type']?.toString() ?? '';
    // Filter out non-medical hits (Nominatim free-text can return schools
    // that happen to have "medical" in the name — we keep only the relevant
    // amenity classes).
    const medicalTypes = {
      'hospital',
      'clinic',
      'doctors',
      'pharmacy',
      'dentist',
      'nursing_home',
      'veterinary',
      'healthcare',
    };
    final isMedical = medicalTypes.contains(type) ||
        cls == 'healthcare' ||
        name.toLowerCase().contains('hospital') ||
        name.toLowerCase().contains('clinic') ||
        name.toLowerCase().contains('medical') ||
        name.toLowerCase().contains('doctor') ||
        name.toLowerCase().contains('nursing') ||
        name.toLowerCase().contains('eye') ||
        name.toLowerCase().contains('dental') ||
        name.toLowerCase().contains('maternity');
    if (!isMedical) return null;

    return _RawPlace(
      osmType: j['osm_type']?.toString() ?? 'node',
      osmId: j['osm_id']?.toString() ?? '0',
      name: name,
      location: LatLng(lat, lon),
      category: type.replaceAll('_', ' '),
      address: _formatAddress(j['address'] as Map<String, dynamic>?) ??
          j['display_name']?.toString(),
    );
  }

  static String? _formatAddress(Map<String, dynamic>? addr) {
    if (addr == null) return null;
    final parts = <String>[];
    for (final k in ['road', 'suburb', 'city', 'state', 'postcode']) {
      final v = addr[k];
      if (v != null) parts.add(v.toString());
    }
    return parts.isEmpty ? null : parts.join(', ');
  }
}
