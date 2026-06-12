import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medicoscope/core/constants/api_constants.dart';
import 'package:medicoscope/core/constants/disease_constants.dart';

/// A booked appointment request. Stored locally so the patient sees their
/// upcoming appointments even if the backend hasn't acknowledged yet.
class Appointment {
  final String id;
  final String doctorId;
  final String patientId;
  final String patientName;
  final DateTime requestedAt;
  final DateTime preferredSlot;
  final String modality;    // "diabetes", "hypertension", "anemia", "general", ...
  final String reason;      // free-form note from the patient
  final String status;      // "pending", "confirmed", "declined"

  const Appointment({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    required this.requestedAt,
    required this.preferredSlot,
    required this.modality,
    required this.reason,
    this.status = 'pending',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'doctorId': doctorId,
        'patientId': patientId,
        'patientName': patientName,
        'requestedAt': requestedAt.toIso8601String(),
        'preferredSlot': preferredSlot.toIso8601String(),
        'modality': modality,
        'reason': reason,
        'status': status,
      };

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
        id: j['id'] ?? '',
        doctorId: j['doctorId'] ?? '',
        patientId: j['patientId'] ?? '',
        patientName: j['patientName'] ?? '',
        requestedAt: DateTime.tryParse(j['requestedAt'] ?? '') ??
            DateTime.now(),
        preferredSlot:
            DateTime.tryParse(j['preferredSlot'] ?? '') ?? DateTime.now(),
        modality: j['modality'] ?? 'general',
        reason: j['reason'] ?? '',
        status: j['status'] ?? 'pending',
      );
}

/// AppointmentService — books an appointment with the patient's linked doctor.
///
/// Backend strategy: we reuse the existing `/mental-health/notifications`
/// endpoint (already wired for disease alerts) with `source: 'appointment_request'`
/// so the doctor's notification center shows it without any server-side
/// code changes. The clinical report body contains the preferred-slot ISO
/// string + reason, which the doctor UI can parse on render.
class AppointmentService {
  static const _key = 'appointments_local';
  static const _maxStored = 50;

  /// Book an appointment. Writes locally + fires a doctor notification.
  static Future<Appointment> book({
    required String doctorId,
    required String patientId,
    required String patientName,
    required DateTime preferredSlot,
    String modality = 'general',
    String reason = '',
  }) async {
    final appt = Appointment(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      doctorId: doctorId,
      patientId: patientId,
      patientName: patientName,
      requestedAt: DateTime.now(),
      preferredSlot: preferredSlot,
      modality: modality,
      reason: reason,
    );

    await _persistLocally(appt);

    // Notify the doctor via the shared notification bus.
    try {
      final report = _buildClinicalReport(appt);
      await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}/mental-health/notifications'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'doctorId': doctorId,
              'patientId': patientId,
              'patientName': patientName,
              'clinicalReport': report,
              'urgency': 'moderate',
              'transcript':
                  '[Appointment] ${modality.isEmpty ? "General" : modality} '
                  'consultation requested for ${_fmtDate(preferredSlot)}',
              'source': 'appointment_request',
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      // Offline-friendly — local copy is already saved.
    }

    return appt;
  }

  static Future<void> _persistLocally(Appointment appt) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? <String>[];
    list.insert(0, jsonEncode(appt.toJson()));
    if (list.length > _maxStored) list.removeRange(_maxStored, list.length);
    await prefs.setStringList(_key, list);
  }

  static Future<List<Appointment>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? const [];
    return list
        .map((s) {
          try {
            return Appointment.fromJson(
                Map<String, dynamic>.from(jsonDecode(s) as Map));
          } catch (_) {
            return null;
          }
        })
        .whereType<Appointment>()
        .toList();
  }

  static String _buildClinicalReport(Appointment a) {
    final slot = _fmtDate(a.preferredSlot);
    return 'APPOINTMENT REQUEST\n'
        'Patient: ${a.patientName}\n'
        'Modality: ${a.modality}\n'
        'Preferred slot: $slot\n'
        'Reason: ${a.reason.isEmpty ? "Follow-up from MedicoScope screening" : a.reason}\n\n'
        'Please confirm or propose an alternative time via the MedicoScope doctor dashboard.';
  }

  static String _fmtDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year} at $hh:$mi';
  }

  /// Convenience: natural-language request from the chatbot.
  /// The chatbot passes a free-text preferred-time string (e.g. "tomorrow 10 am").
  /// We parse a few common patterns, fall back to "+1 day same time".
  static DateTime parseSlot(String raw) {
    final lower = raw.toLowerCase().trim();
    final now = DateTime.now();

    // "today" / "tonight"
    if (lower.contains('today') || lower.contains('tonight')) {
      return _withTime(now, _extractHour(lower) ?? 18);
    }
    // "tomorrow"
    if (lower.contains('tomorrow')) {
      final t = now.add(const Duration(days: 1));
      return _withTime(t, _extractHour(lower) ?? 10);
    }
    // "next week"
    if (lower.contains('next week')) {
      return _withTime(now.add(const Duration(days: 7)),
          _extractHour(lower) ?? 10);
    }
    // "in X days"
    final inDays =
        RegExp(r'in\s+(\d+)\s+day').firstMatch(lower);
    if (inDays != null) {
      final days = int.tryParse(inDays.group(1)!) ?? 1;
      return _withTime(now.add(Duration(days: days)),
          _extractHour(lower) ?? 10);
    }
    // Weekday name
    const weekdays = {
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'saturday': 6,
      'sunday': 7,
    };
    for (final entry in weekdays.entries) {
      if (lower.contains(entry.key)) {
        final target = entry.value;
        int diff = (target - now.weekday) % 7;
        if (diff == 0) diff = 7;
        return _withTime(now.add(Duration(days: diff)),
            _extractHour(lower) ?? 10);
      }
    }
    // Default: +1 day at 10 AM
    return _withTime(now.add(const Duration(days: 1)), 10);
  }

  static DateTime _withTime(DateTime d, int hour) =>
      DateTime(d.year, d.month, d.day, hour, 0);

  static int? _extractHour(String s) {
    // Match "10 am", "2pm", "14:00"
    final m = RegExp(r'(\d{1,2})(?::\d{2})?\s*(am|pm)?').firstMatch(s);
    if (m == null) return null;
    var h = int.tryParse(m.group(1)!);
    if (h == null) return null;
    final ap = m.group(2);
    if (ap == 'pm' && h < 12) h += 12;
    if (ap == 'am' && h == 12) h = 0;
    if (h < 0 || h > 23) return null;
    return h;
  }
}
