import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:medicoscope/core/constants/api_constants.dart';
import 'package:medicoscope/services/api_service.dart';

class VitalsService {
  /// Save a vitals session summary to MongoDB via Node.js backend.
  static Future<void> saveSessionSummary({
    required String token,
    required Map<String, dynamic> sessionData,
  }) async {
    final api = ApiService(token: token);
    await api.post(ApiConstants.vitalsSummary, sessionData);
  }

  static Future<Map<String, dynamic>> startSession({
    required String patientId,
    required String patientName,
    required String doctorId,
    String emergencyContactName = '',
    String emergencyContactPhone = '',
    String location = 'Unknown',
    double latitude = 0.0,
    double longitude = 0.0,
  }) async {
    final url = Uri.parse(
      '${ApiConstants.chatbotBaseUrl}${ApiConstants.vitalsStart}',
    );

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'patient_id': patientId,
            'patient_name': patientName,
            'doctor_id': doctorId,
            'emergency_contact_name': emergencyContactName,
            'emergency_contact_phone': emergencyContactPhone,
            'location': location,
            'latitude': latitude,
            'longitude': longitude,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 503) {
      throw Exception('Service is warming up. Please try again in a moment.');
    } else {
      throw Exception('Failed to start session: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> tick({
    required String sessionId,
  }) async {
    final url = Uri.parse(
      '${ApiConstants.chatbotBaseUrl}${ApiConstants.vitalsTick}',
    );

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'session_id': sessionId}),
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 404) {
      throw Exception('Session expired or not found.');
    } else {
      throw Exception('Tick failed: ${response.statusCode}');
    }
  }

  static Future<void> stopSession({required String sessionId}) async {
    final url = Uri.parse(
      '${ApiConstants.chatbotBaseUrl}${ApiConstants.vitalsSession}/$sessionId',
    );

    await http.delete(url).timeout(const Duration(seconds: 10));
  }

  static Future<List<Map<String, dynamic>>> getDoctorAlerts({
    required String doctorId,
  }) async {
    final url = Uri.parse(
      '${ApiConstants.chatbotBaseUrl}${ApiConstants.vitalsDoctorAlerts}/$doctorId',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['alerts'] ?? []);
    } else {
      throw Exception('Failed to fetch alerts: ${response.statusCode}');
    }
  }

  static Future<List<Map<String, dynamic>>> getPatientAlerts({
    required String patientId,
  }) async {
    final url = Uri.parse(
      '${ApiConstants.chatbotBaseUrl}${ApiConstants.vitalsPatientAlerts}/$patientId',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['alerts'] ?? []);
    } else {
      throw Exception('Failed to fetch alerts: ${response.statusCode}');
    }
  }

  static Future<void> markAlertRead({required String alertId}) async {
    final url = Uri.parse(
      '${ApiConstants.chatbotBaseUrl}/vitals/alerts/$alertId/read',
    );

    await http.put(url).timeout(const Duration(seconds: 10));
  }

  static Future<void> deleteAlert({required String alertId}) async {
    final url = Uri.parse(
      '${ApiConstants.chatbotBaseUrl}/vitals/alerts/$alertId',
    );

    await http.delete(url).timeout(const Duration(seconds: 10));
  }
}
