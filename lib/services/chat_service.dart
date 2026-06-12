import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:medicoscope/core/constants/api_constants.dart';
import 'package:medicoscope/services/api_service.dart';
import 'package:medicoscope/services/disease_risk_store.dart';

class ChatService {
  /// Trim the medical context so we don't blow up on Groq's token limit.
  /// Keeps the most useful recent data and truncates the tail.
  static String _trimContext(String? context, {int maxChars = 3500}) {
    if (context == null || context.isEmpty) return '';
    if (context.length <= maxChars) return context;
    // Keep the head (profile) + tail (most recent entries).
    final head = context.substring(0, maxChars ~/ 3);
    final tail = context.substring(context.length - (maxChars * 2 ~/ 3));
    return '$head\n…\n$tail';
  }

  /// Non-streaming call — uses the smaller streaming-capable model via
  /// `/chat` but awaits the full JSON response. Used as a fallback when
  /// the streaming endpoint fails.
  static Future<String> sendMessage({
    required String message,
    required String sessionId,
    required String patientProfile,
    String language = 'en',
    String? medicalContext,
  }) async {
    final url = Uri.parse('${ApiConstants.chatbotBaseUrl}/chat');
    final trimmedContext = _trimContext(medicalContext);
    final trimmedProfile = _trimContext(patientProfile, maxChars: 1500);

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'message': message,
            'session_id': sessionId,
            'patient_profile': trimmedProfile,
            'language': language,
            if (trimmedContext.isNotEmpty) 'medical_context': trimmedContext,
          }),
        )
        // Render free-tier cold start can take up to ~60 s. 90 s handles it.
        .timeout(const Duration(seconds: 90));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response'] as String;
    }
    // Try to parse a helpful error out of the FastAPI "detail" field.
    String? reason;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      reason = body['detail']?.toString();
    } catch (_) {}
    if (response.statusCode == 429 ||
        (reason?.contains('rate_limit') ?? false) ||
        (reason?.contains('Rate limit') ?? false)) {
      throw Exception(
          'The AI service has hit its daily free-tier quota. Please try again later or upgrade the backend plan.');
    }
    if (response.statusCode == 503) {
      throw Exception('Chatbot is warming up. Please try again in a moment.');
    }
    throw Exception('Chatbot error (${response.statusCode})');
  }

  /// Streaming method — yields token chunks as they arrive via SSE.
  /// Uses the smaller 8B model on the backend (separate quota from the 70B
  /// used by the non-streaming endpoint), so it survives 70B rate limits.
  static Stream<String> sendMessageStream({
    required String message,
    required String sessionId,
    required String patientProfile,
    String language = 'en',
    String? medicalContext,
  }) async* {
    final url = Uri.parse('${ApiConstants.chatbotBaseUrl}/chat/stream');
    final trimmedContext = _trimContext(medicalContext);
    final trimmedProfile = _trimContext(patientProfile, maxChars: 1500);
    final request = http.Request('POST', url);
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'message': message,
      'session_id': sessionId,
      'patient_profile': trimmedProfile,
      'language': language,
      if (trimmedContext.isNotEmpty) 'medical_context': trimmedContext,
    });

    final client = http.Client();
    try {
      // Render free-tier cold start + first LLM token can exceed 30 s.
      final response =
          await client.send(request).timeout(const Duration(seconds: 90));

      if (response.statusCode == 503) {
        throw Exception('Chatbot is warming up. Please try again in a moment.');
      }
      if (response.statusCode == 429) {
        throw Exception(
            'Rate limit reached. Please try again later.');
      }
      if (response.statusCode != 200) {
        // Try to read the body for a helpful error.
        final bodyBytes = await response.stream.toBytes();
        String? detail;
        try {
          final body = jsonDecode(utf8.decode(bodyBytes)) as Map<String, dynamic>;
          detail = body['detail']?.toString();
        } catch (_) {
          detail = utf8.decode(bodyBytes);
        }
        if (detail != null &&
            (detail.contains('rate_limit') ||
                detail.contains('Rate limit') ||
                detail.contains('429'))) {
          throw Exception(
              'The AI service has hit its daily free-tier quota. Please try again later.');
        }
        throw Exception('Chatbot error (${response.statusCode})');
      }

      String buffer = '';
      bool gotAny = false;
      // Per-chunk read timeout — if the stream stalls > 60 s, abort.
      await for (final chunk in response.stream
          .transform(utf8.decoder)
          .timeout(const Duration(seconds: 60))) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast(); // keep incomplete line in buffer

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('data: ')) {
            final data = trimmed.substring(6).trim();
            if (data == '[DONE]') {
              return;
            }
            try {
              final parsed = jsonDecode(data) as Map<String, dynamic>;
              if (parsed.containsKey('error')) {
                throw Exception(parsed['error']);
              }
              final tok = parsed['token'];
              if (tok != null) {
                gotAny = true;
                yield tok as String;
              }
            } catch (e) {
              if (e is Exception && e.toString().contains('Chatbot')) {
                rethrow;
              }
              // Skip malformed SSE lines.
            }
          }
        }
      }
      if (!gotAny) {
        throw Exception('Chatbot returned an empty response.');
      }
    } finally {
      client.close();
    }
  }

  /// Save chat message pair to DB
  static Future<void> saveMessageToDb({
    required String token,
    required String sessionId,
    required String userMessage,
    required String assistantMessage,
  }) async {
    try {
      final api = ApiService(token: token);
      await api.post(ApiConstants.chatMessage, {
        'sessionId': sessionId,
        'userMessage': userMessage,
        'assistantMessage': assistantMessage,
      });
    } catch (_) {
      // Silently fail — don't block chat UX
    }
  }

  /// Get chat history list
  static Future<List<Map<String, dynamic>>> getChatHistory(String token) async {
    final api = ApiService(token: token);
    final response = await api.get(ApiConstants.chatHistory);
    return List<Map<String, dynamic>>.from(response['sessions'] ?? []);
  }

  /// Get full chat session
  static Future<Map<String, dynamic>> getChatSession(
      String token, String sessionId) async {
    final api = ApiService(token: token);
    final response = await api.get('${ApiConstants.chatSession}/$sessionId');
    return response['chat'] as Map<String, dynamic>;
  }

  /// Delete a chat session
  static Future<void> deleteChatSession(String token, String sessionId) async {
    final api = ApiService(token: token);
    await api.delete('${ApiConstants.chatSession}/$sessionId');
  }

  /// Fetch the patient's full medical summary for chatbot context.
  /// Includes: conditions, medications, vitals, detections, mindspace sessions.
  static Future<String> fetchMedicalContext(String token) async {
    try {
      final api = ApiService(token: token);
      final data = await api.get(ApiConstants.patientMedicalSummary);

      final parts = <String>[];

      // Patient profile
      final patient = data['patient'] as Map<String, dynamic>? ?? {};
      if (patient.isNotEmpty) {
        final conditions = List<String>.from(patient['conditions'] ?? []);
        final medications = List.from(patient['medications'] ?? []);
        final bloodGroup = patient['bloodGroup'] ?? '';
        final dob = patient['dateOfBirth'] ?? '';

        if (bloodGroup.isNotEmpty) parts.add('Blood Group: $bloodGroup');
        if (dob.isNotEmpty) parts.add('Date of Birth: $dob');
        if (conditions.isNotEmpty) {
          parts.add('Known Conditions: ${conditions.join(", ")}');
        }
        if (medications.isNotEmpty) {
          final medStr = medications
              .map((m) => '${m['name']} (${m['dosage']}, ${m['frequency']})')
              .join('; ');
          parts.add('Current Medications: $medStr');
        }
      }

      // Recent detections (AI scans)
      final detections =
          List<Map<String, dynamic>>.from(data['detections'] ?? []);
      if (detections.isNotEmpty) {
        parts.add('\n--- Recent AI Scan Results ---');
        for (final d in detections) {
          final conf = ((d['confidence'] as num?) ?? 0) * 100;
          parts.add(
            '• ${d['category']}: ${d['className']} '
            '(${conf.toStringAsFixed(1)}% confidence) '
            'on ${d['date'] ?? 'unknown date'}'
            '${d['description'] != null && d['description'].toString().isNotEmpty ? " - ${d['description']}" : ""}',
          );
        }
      }

      // Recent vitals
      final vitals = List<Map<String, dynamic>>.from(data['vitals'] ?? []);
      if (vitals.isNotEmpty) {
        parts.add('\n--- Recent Vitals Monitoring Sessions ---');
        for (final v in vitals) {
          final alerts = List.from(v['alerts'] ?? []);
          parts.add(
            '• Session on ${v['date'] ?? 'unknown'}: '
            'HR avg ${v['avgHeartRate']} (${v['minHeartRate']}-${v['maxHeartRate']}), '
            'BP ${v['avgSystolic']}/${v['avgDiastolic']}, '
            'SpO2 avg ${v['avgSpO2']} (min ${v['minSpO2']})'
            '${alerts.isNotEmpty ? ", Alerts: ${alerts.length}" : ""}',
          );
        }
      }

      // MindSpace sessions
      final mindspace =
          List<Map<String, dynamic>>.from(data['mindspace'] ?? []);
      if (mindspace.isNotEmpty) {
        parts.add('\n--- Recent MindSpace Mental Health Check-ins ---');
        for (final s in mindspace) {
          parts.add(
            '• Check-in on ${s['date'] ?? 'unknown'} '
            '(urgency: ${s['urgency'] ?? 'low'}):\n'
            '  Patient said: "${s['transcript'] ?? ''}"'
            '${s['aiResponse'] != null && s['aiResponse'].toString().isNotEmpty ? "\n  AI Response: ${s['aiResponse']}" : ""}',
          );
        }
      }

      // Disease screening results (diabetes / hypertension / anemia)
      final diseaseSummary = await DiseaseRiskStore.chatbotSummary();
      if (diseaseSummary.isNotEmpty) {
        parts.add('\n--- Chronic Disease Screenings ---');
        parts.add(diseaseSummary);
      }

      if (parts.isEmpty) return '';
      return parts.join('\n');
    } catch (_) {
      // Even if server context fails, still return local disease summary so
      // the chatbot can reason about offline screening results.
      return await DiseaseRiskStore.chatbotSummary();
    }
  }

  /// One-shot helper: ask the LLM for a short natural-language interpretation
  /// of a numeric/clinical screening result. Used across all disease methods.
  /// Fails silently and returns null if the chatbot is unavailable.
  static Future<String?> explainRisk({
    required String disease,
    required String method,
    required String riskLevel,
    required String headline,
    required List<String> findings,
    String language = 'en',
  }) async {
    try {
      final prompt =
          'A $method screening for $disease produced $riskLevel risk. '
          'Headline: $headline. '
          'Key findings: ${findings.join("; ")}. '
          'In 2-3 sentences, give the patient a clear, empathetic explanation '
          'and a single most-important next step. Do not diagnose.';
      final reply = await sendMessage(
        message: prompt,
        sessionId: 'disease-explain-${DateTime.now().millisecondsSinceEpoch}',
        patientProfile: '',
        language: language,
      ).timeout(const Duration(seconds: 15));
      return reply.trim();
    } catch (_) {
      return null;
    }
  }
}
