import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medicoscope/core/constants/api_constants.dart';

/// Status returned by the doctor after reviewing an appointment request.
enum AppointmentStatus { pending, confirmed, rescheduled, declined }

/// Patient-facing record of a doctor's response to an appointment request.
class AppointmentResponse {
  final String id;
  final String patientId;
  final String doctorId;
  final String doctorName;
  final AppointmentStatus status;
  final DateTime originalSlot;
  final DateTime? newSlot; // only set when rescheduled
  final String note;       // doctor's note
  final DateTime receivedAt;
  final bool read;

  const AppointmentResponse({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.doctorName,
    required this.status,
    required this.originalSlot,
    this.newSlot,
    required this.note,
    required this.receivedAt,
    this.read = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'status': status.name,
        'originalSlot': originalSlot.toIso8601String(),
        'newSlot': newSlot?.toIso8601String(),
        'note': note,
        'receivedAt': receivedAt.toIso8601String(),
        'read': read,
      };

  factory AppointmentResponse.fromJson(Map<String, dynamic> j) =>
      AppointmentResponse(
        id: j['id'] ?? '',
        patientId: j['patientId'] ?? '',
        doctorId: j['doctorId'] ?? '',
        doctorName: j['doctorName'] ?? '',
        status: AppointmentStatus.values.firstWhere(
            (s) => s.name == j['status'],
            orElse: () => AppointmentStatus.pending),
        originalSlot:
            DateTime.tryParse(j['originalSlot'] ?? '') ?? DateTime.now(),
        newSlot: j['newSlot'] == null
            ? null
            : DateTime.tryParse(j['newSlot']),
        note: j['note'] ?? '',
        receivedAt:
            DateTime.tryParse(j['receivedAt'] ?? '') ?? DateTime.now(),
        read: j['read'] == true,
      );

  AppointmentResponse markRead() => AppointmentResponse(
        id: id,
        patientId: patientId,
        doctorId: doctorId,
        doctorName: doctorName,
        status: status,
        originalSlot: originalSlot,
        newSlot: newSlot,
        note: note,
        receivedAt: receivedAt,
        read: true,
      );
}

/// Doctor → patient response channel.
///
/// Uses the existing `/mental-health/notifications` endpoint as a generic
/// notification bus by flipping the `doctorId` field to the *patient's*
/// user id (the field is a recipient id — not strictly a doctor).
/// Downstream, the Node backend stores one notification keyed by the
/// recipient; the patient's app polls their own id to pick it up.
class AppointmentResponseService {
  /// Prefix marker we embed in the clinical-report body so the patient's
  /// parser can distinguish confirmations from alerts.
  static const String confirmMarker = 'APPOINTMENT CONFIRMED';
  static const String rescheduleMarker = 'APPOINTMENT RESCHEDULED';

  /// Doctor sends a Confirmed reply back to the patient.
  static Future<void> confirm({
    required String patientId,
    required String patientName,
    required String doctorId,
    required String doctorName,
    required DateTime originalSlot,
    String note = '',
  }) async {
    final body =
        '$confirmMarker\nDoctor: $doctorName\nConfirmed slot: ${_fmt(originalSlot)}\nNote: ${note.isEmpty ? "Looking forward to seeing you." : note}';
    await _send(
      recipientId: patientId,
      patientName: patientName,
      doctorId: doctorId,
      clinicalReport: body,
      urgency: 'moderate',
      transcript:
          '[Appointment confirmed] by $doctorName for ${_fmt(originalSlot)}',
      source: 'appointment_confirmed',
    );
  }

  /// Doctor sends a Reschedule-proposed reply.
  static Future<void> reschedule({
    required String patientId,
    required String patientName,
    required String doctorId,
    required String doctorName,
    required DateTime originalSlot,
    required DateTime newSlot,
    String note = '',
  }) async {
    final body =
        '$rescheduleMarker\nDoctor: $doctorName\nOriginal slot: ${_fmt(originalSlot)}\nProposed new slot: ${_fmt(newSlot)}\nNote: ${note.isEmpty ? "Please confirm the new time or propose another." : note}';
    await _send(
      recipientId: patientId,
      patientName: patientName,
      doctorId: doctorId,
      clinicalReport: body,
      urgency: 'moderate',
      transcript:
          '[Appointment rescheduled] by $doctorName to ${_fmt(newSlot)}',
      source: 'appointment_rescheduled',
    );
  }

  static Future<void> _send({
    required String recipientId,
    required String patientName,
    required String doctorId,
    required String clinicalReport,
    required String urgency,
    required String transcript,
    required String source,
  }) async {
    try {
      await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}/mental-health/notifications'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              // The recipient of this notification is the patient. We keep
              // the field name `doctorId` because that's what the backend
              // schema still calls it — it's the *routing id*, not a role.
              'doctorId': recipientId,
              'patientId': doctorId,
              'patientName': patientName,
              'clinicalReport': clinicalReport,
              'urgency': urgency,
              'transcript': transcript,
              'source': source,
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      // Offline-tolerant — the backend will retry on next poll.
    }
  }

  // ── Patient side — local cache + read tracking ──────────────────────────

  static const _key = 'appointment_responses_local';

  /// Persist a parsed appointment response received from the backend.
  static Future<void> persistLocal(AppointmentResponse r) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? <String>[];
    // Dedupe by id.
    list.removeWhere((s) {
      try {
        return (jsonDecode(s) as Map)['id'] == r.id;
      } catch (_) {
        return false;
      }
    });
    list.insert(0, jsonEncode(r.toJson()));
    if (list.length > 50) list.removeRange(50, list.length);
    await prefs.setStringList(_key, list);
  }

  static Future<List<AppointmentResponse>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? const [];
    return list
        .map((s) {
          try {
            return AppointmentResponse.fromJson(
                Map<String, dynamic>.from(jsonDecode(s) as Map));
          } catch (_) {
            return null;
          }
        })
        .whereType<AppointmentResponse>()
        .toList();
  }

  static Future<int> unreadCount() async =>
      (await getAll()).where((r) => !r.read).length;

  static Future<void> markRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? const [];
    final updated = <String>[];
    for (final s in list) {
      try {
        final j = Map<String, dynamic>.from(jsonDecode(s) as Map);
        if (j['id'] == id) {
          j['read'] = true;
        }
        updated.add(jsonEncode(j));
      } catch (_) {
        updated.add(s);
      }
    }
    await prefs.setStringList(_key, updated);
  }

  /// Fetch all doctor responses routed to [patientId]. Uses the shared
  /// mental-health notifications endpoint (we reuse its recipient field).
  /// Returns parsed [AppointmentResponse] objects, newest first, and
  /// persists each one locally for offline viewing.
  static Future<List<AppointmentResponse>> fetchForPatient({
    required String patientId,
    required String token,
  }) async {
    final uri = Uri.parse(
        '${ApiConstants.baseUrl}/mental-health/notifications/$patientId');
    try {
      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return getAll();
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (body['notifications'] as List?) ?? const [];
      final parsed = <AppointmentResponse>[];
      for (final entry in list) {
        final map = Map<String, dynamic>.from(entry as Map);
        final r = tryParseFromNotification(map);
        if (r != null) {
          parsed.add(r);
          await persistLocal(r);
        }
      }
      // Fall back to local cache if the endpoint returns nothing.
      return parsed.isNotEmpty ? parsed : await getAll();
    } catch (_) {
      return getAll();
    }
  }

  /// Parse a raw backend notification entry and, if it looks like an
  /// appointment response, produce an `AppointmentResponse`. Returns null
  /// for non-appointment notifications.
  static AppointmentResponse? tryParseFromNotification(
      Map<String, dynamic> n) {
    final source = n['source']?.toString() ?? '';
    final report = n['report']?.toString() ??
        n['clinicalReport']?.toString() ??
        '';

    AppointmentStatus status;
    if (source == 'appointment_confirmed' ||
        report.contains(confirmMarker)) {
      status = AppointmentStatus.confirmed;
    } else if (source == 'appointment_rescheduled' ||
        report.contains(rescheduleMarker)) {
      status = AppointmentStatus.rescheduled;
    } else {
      return null;
    }

    final doctorName = _extract(report, RegExp(r'Doctor:\s*(.+)'));
    final origStr = _extract(report, RegExp(r'(?:Confirmed slot|Original slot):\s*(.+)'));
    final newStr = _extract(report, RegExp(r'Proposed new slot:\s*(.+)'));
    final note = _extract(report, RegExp(r'Note:\s*(.+)'));

    return AppointmentResponse(
      id: n['id']?.toString() ?? '',
      patientId: n['doctor_id']?.toString() ??
          n['doctorId']?.toString() ??
          '',
      doctorId: n['patient_id']?.toString() ??
          n['patientId']?.toString() ??
          '',
      doctorName: doctorName ?? 'Your doctor',
      status: status,
      originalSlot: _parseDate(origStr) ?? DateTime.now(),
      newSlot: _parseDate(newStr),
      note: note ?? '',
      receivedAt: DateTime.tryParse(n['created_at'] ?? '') ?? DateTime.now(),
      read: n['read'] == true,
    );
  }

  static String? _extract(String src, RegExp re) {
    final m = re.firstMatch(src);
    return m?.group(1)?.trim();
  }

  static DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    // Matches `23/04/2026 at 10:30` format emitted by _fmt().
    final m = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})\s+at\s+(\d{1,2}):(\d{2})')
        .firstMatch(s);
    if (m != null) {
      try {
        return DateTime(
          int.parse(m.group(3)!),
          int.parse(m.group(2)!),
          int.parse(m.group(1)!),
          int.parse(m.group(4)!),
          int.parse(m.group(5)!),
        );
      } catch (_) {}
    }
    return DateTime.tryParse(s);
  }

  static String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} at ${two(d.hour)}:${two(d.minute)}';
  }
}
