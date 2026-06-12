import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/providers/auth_provider.dart';
import 'package:medicoscope/core/providers/coins_provider.dart';
import 'package:medicoscope/core/constants/api_constants.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/services/api_service.dart';
import 'package:medicoscope/services/appointment_service.dart';
import 'package:medicoscope/services/chat_service.dart';
import 'package:medicoscope/services/disease_result_pipeline.dart';
import 'package:medicoscope/services/disease_risk_store.dart';
import 'package:provider/provider.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';
import 'package:medicoscope/core/locale/locale_provider.dart';

/// Shows the floating chat bottom sheet.
void showChatBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ChatBottomSheet(),
  );
}

class _ChatBottomSheet extends StatefulWidget {
  const _ChatBottomSheet();

  @override
  State<_ChatBottomSheet> createState() => _ChatBottomSheetState();
}

class _ChatBottomSheetState extends State<_ChatBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMsg> _messages = [];
  bool _isLoading = false;
  String _medicalProfile = '';
  bool _profileLoaded = false;
  bool _hasHealthData = false;
  String _streamingText = '';

  @override
  void initState() {
    super.initState();
    _loadMedicalSummary();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMedicalSummary() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null || auth.user == null) return;

    final parts = <String>[
      'Name: ${auth.user!.name}',
      'Role: ${auth.user!.role}',
    ];
    if (auth.user!.phone != null && auth.user!.phone!.isNotEmpty) {
      parts.add('Phone: ${auth.user!.phone}');
    }

    try {
      final api = ApiService(token: auth.token);
      final data = await api
          .get(ApiConstants.patientMedicalSummary)
          .timeout(const Duration(seconds: 10));

      // Patient profile
      final patient = data['patient'] as Map<String, dynamic>? ?? {};
      final conditions = List<String>.from(patient['conditions'] ?? []);
      final medications = List<String>.from(patient['medications'] ?? []);
      final bloodGroup = patient['bloodGroup'] ?? '';
      final dob = patient['dateOfBirth'];

      if (bloodGroup.isNotEmpty) parts.add('Blood Group: $bloodGroup');
      if (dob != null) parts.add('Date of Birth: $dob');
      if (conditions.isNotEmpty) {
        parts.add('Medical Conditions: ${conditions.join(', ')}');
      }
      if (medications.isNotEmpty) {
        parts.add('Current Medications: ${medications.join(', ')}');
      }

      // Recent detections
      final detections =
          List<Map<String, dynamic>>.from(data['detections'] ?? []);
      if (detections.isNotEmpty) {
        _hasHealthData = true;
        parts.add('\n--- Recent Detection Results ---');
        for (final d in detections) {
          final cat = d['category'] ?? '';
          final cls = d['className'] ?? '';
          final conf = d['confidence'];
          final date = d['date'] ?? '';
          final desc = d['description'] ?? '';
          final confStr = cat == 'heart_sound'
              ? '${conf?.toStringAsFixed(0)} BPM'
              : '${((conf ?? 0) * 100).toStringAsFixed(1)}% confidence';
          parts.add('- [$cat] $cls ($confStr) on ${_formatDate(date)}');
          if (desc.isNotEmpty) {
            parts.add('  Description: $desc');
          }
        }
      }

      // Recent vitals
      final vitals = List<Map<String, dynamic>>.from(data['vitals'] ?? []);
      if (vitals.isNotEmpty) {
        _hasHealthData = true;
        parts.add('\n--- Recent Vitals Sessions ---');
        for (final v in vitals) {
          final date = v['date'] ?? '';
          parts.add(
            '- HR: avg ${v['avgHeartRate']?.toStringAsFixed(0)}'
            ' (${v['minHeartRate']?.toStringAsFixed(0)}-${v['maxHeartRate']?.toStringAsFixed(0)})'
            ', BP: ${v['avgSystolic']?.toStringAsFixed(0)}/${v['avgDiastolic']?.toStringAsFixed(0)}'
            ', SpO2: ${v['avgSpO2']?.toStringAsFixed(1)}%'
            ' on ${_formatDate(date)}',
          );
          final alerts = List<Map<String, dynamic>>.from(v['alerts'] ?? []);
          for (final a in alerts) {
            parts.add('  ALERT: ${a['message']}');
          }
        }
      }

    } catch (e) {
      debugPrint('Medical summary fetch failed: $e');
      // Continue with basic profile — the chatbot will still work
    }

    // Pull in the on-device disease screening summary so the chatbot always
    // has the freshest risk scores even if the server context fetch failed.
    try {
      final diseaseSummary = await DiseaseRiskStore.chatbotSummary();
      if (diseaseSummary.isNotEmpty) {
        _hasHealthData = true;
        parts.add('\n--- Disease Screening Results ---');
        parts.add(diseaseSummary);
      }
    } catch (_) {}

    _medicalProfile = parts.join('\n');
    _profileLoaded = true;

    if (mounted) {
      setState(() {
        final greeting = _hasHealthData
            ? "Hello! I'm your MedicoScope assistant. I can see your recent scans, vitals and disease-screening results. Ask me anything — or say \"book an appointment with my doctor\" and I'll send the request."
            : "Hello! I'm your MedicoScope assistant. Run a screening — diabetes, hypertension, anemia lab scan, vitals, or a skin/retinal photo — and I'll have data to reason about. I can also book appointments with your linked doctor (just say \"book an appointment tomorrow 10 am\").";
        _messages.add(_ChatMsg(text: greeting, isUser: false));
      });
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return date.toString();
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final sessionId = auth.user?.id ?? 'anonymous';

    // Wait for profile if not yet loaded
    if (!_profileLoaded) {
      await _loadMedicalSummary();
    }

    // Always refresh the on-device disease context so the LLM sees the
    // latest screening readings (user may have just run a detection in the
    // background before opening the chat).
    try {
      final fresh = await DiseaseRiskStore.chatbotSummary();
      if (fresh.isNotEmpty) {
        if (!_medicalProfile.contains(fresh)) {
          _medicalProfile =
              '$_medicalProfile\n--- Disease Screening Results (live) ---\n$fresh';
          _hasHealthData = true;
        }
      }
    } catch (_) {}

    setState(() {
      _messages.add(_ChatMsg(text: text, isUser: true));
      _streamingText = '';
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    // Intent: does the user want to book an appointment? If yes, handle
    // locally and skip the LLM round-trip — faster, more reliable, and
    // actually produces an action (LLM can't book anything itself).
    if (_matchesAppointmentIntent(text)) {
      await _handleAppointmentIntent(text, auth);
      return;
    }

    final lang =
        Provider.of<LocaleProvider>(context, listen: false).languageCode;

    String? streamError;
    try {
      // Use streaming endpoint for real-time token delivery
      final stream = ChatService.sendMessageStream(
        message: text,
        sessionId: sessionId,
        patientProfile: _medicalProfile,
        language: lang,
        medicalContext: _medicalProfile,
      );

      await for (final token in stream) {
        if (mounted) {
          setState(() => _streamingText += token);
          _scrollToBottom();
        }
      }

      // Streaming complete — move streamed text to messages list
      if (mounted) {
        final finalText = _streamingText;
        setState(() {
          if (finalText.isNotEmpty) {
            _messages.add(_ChatMsg(text: finalText, isUser: false));
          }
          _streamingText = '';
          _isLoading = false;
        });
      }

      // Award chat coins
      final coinsProvider = Provider.of<CoinsProvider>(context, listen: false);
      await coinsProvider.addChatCoins();
      _scrollToBottom();
      return;
    } catch (e) {
      streamError = e.toString();
      debugPrint('Chat stream failed: $streamError');
    }

    // Streaming failed — try the non-streaming endpoint as a fallback.
    try {
      final reply = await ChatService.sendMessage(
        message: text,
        sessionId: sessionId,
        patientProfile: _medicalProfile,
        language: lang,
        medicalContext: _medicalProfile,
      );
      if (mounted) {
        setState(() {
          if (_streamingText.isNotEmpty) {
            _messages.add(_ChatMsg(text: _streamingText, isUser: false));
          }
          _streamingText = '';
          _messages.add(_ChatMsg(text: reply, isUser: false));
          _isLoading = false;
        });
      }
      final coinsProvider = Provider.of<CoinsProvider>(context, listen: false);
      await coinsProvider.addChatCoins();
    } catch (e) {
      final errorMsg = e.toString();
      String displayMsg;
      if (errorMsg.contains('quota') || errorMsg.contains('rate_limit') ||
          errorMsg.contains('Rate limit')) {
        displayMsg =
            'The AI service has hit its daily free-tier quota. It will reset shortly — please try again in a few minutes.';
      } else if (errorMsg.contains('warming up') ||
          errorMsg.contains('503')) {
        displayMsg = 'The chatbot is warming up. Please try again in a moment.';
      } else if (errorMsg.contains('TimeoutException') ||
          errorMsg.contains('timed out')) {
        displayMsg =
            'The request timed out — the server may be waking from sleep. Please try again in ~30 seconds.';
      } else {
        displayMsg =
            'Sorry, I couldn\'t reach the AI service right now. Please try again.';
      }
      if (mounted) {
        setState(() {
          if (_streamingText.isNotEmpty) {
            _messages.add(_ChatMsg(text: _streamingText, isUser: false));
          }
          _streamingText = '';
          _messages.add(_ChatMsg(text: displayMsg, isUser: false));
          _isLoading = false;
        });
      }
    }

    _scrollToBottom();
  }

  /// Heuristic booking-intent detection. Matches phrases like:
  ///   "book an appointment"
  ///   "schedule a visit"
  ///   "I want to see my doctor"
  ///   "fix a consult"
  bool _matchesAppointmentIntent(String raw) {
    final t = raw.toLowerCase();
    final bookVerbs = ['book', 'schedule', 'fix', 'set up', 'arrange', 'make'];
    final appointmentNouns = [
      'appointment',
      'appt',
      'visit',
      'consult',
      'consultation',
      'meeting with doctor',
      'see my doctor',
      'see a doctor',
      'see the doctor',
      'doctor visit',
    ];
    for (final v in bookVerbs) {
      for (final n in appointmentNouns) {
        if (t.contains(v) && t.contains(n.toLowerCase())) return true;
      }
    }
    // Explicit phrases
    if (t.contains('appointment') &&
        (t.contains('with') || t.contains('please') || t.contains('want') ||
            t.contains('can you'))) return true;
    return false;
  }

  Future<void> _handleAppointmentIntent(
      String text, AuthProvider auth) async {
    final user = auth.user;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMsg(
          text: 'Please sign in first so I can book the appointment for you.',
          isUser: false,
        ));
        _isLoading = false;
      });
      return;
    }
    final doctorId =
        await DiseaseResultPipeline.resolveDoctorIdFor(auth.token);
    if (doctorId == null || doctorId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMsg(
          text:
              'I couldn\'t find a doctor linked to your account yet. Open the MedicoScope drawer → Link Doctor, then try again.',
          isUser: false,
        ));
        _isLoading = false;
      });
      return;
    }

    final slot = AppointmentService.parseSlot(text);
    final slotStr = _fmtSlot(slot);

    try {
      await AppointmentService.book(
        doctorId: doctorId,
        patientId: user.id,
        patientName: user.name,
        preferredSlot: slot,
        modality: 'general',
        reason: 'Requested via MedicoScope chat: "$text"',
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMsg(
          text:
              'Done ✅\nI\'ve sent an appointment request to your linked doctor for $slotStr. You\'ll see a confirmation once they respond from their dashboard.',
          isUser: false,
        ));
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMsg(
          text:
              'Sorry, I couldn\'t reach the booking service just now. Please try again in a moment, or use the "Book appointment" button on a disease deck.',
          isUser: false,
        ));
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  String _fmtSlot(DateTime d) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = d.hour == 0
        ? 12
        : (d.hour > 12 ? d.hour - 12 : d.hour);
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    final mi = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month]}, $h:$mi $ap';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkBackground : const Color(0xFFF5F5F5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.smart_toy_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Medical Assistant',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppTheme.darkTextLight
                                  : AppTheme.textDark,
                            ),
                          ),
                          Text(
                            'AI-powered health guidance',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppTheme.darkTextGray
                                  : AppTheme.textGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Online indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ECDC4).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4ECDC4),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Online',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4ECDC4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(
                        Icons.close_rounded,
                        color:
                            isDark ? AppTheme.darkTextGray : AppTheme.textGray,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),

              Divider(
                height: 1,
                color: isDark ? Colors.white10 : Colors.grey.shade300,
              ),

              // Messages
              Expanded(
                child: _messages.isEmpty && !_profileLoaded
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Loading your health data...',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppTheme.darkTextGray
                                    : AppTheme.textGray,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        itemCount: _messages.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length && _isLoading) {
                            // Show streaming text if we have it, otherwise typing dots
                            if (_streamingText.isNotEmpty) {
                              return _buildBubble(
                                _ChatMsg(text: _streamingText, isUser: false),
                                isDark,
                              );
                            }
                            return _buildTypingIndicator(isDark);
                          }
                          return _buildBubble(_messages[index], isDark);
                        },
                      ),
              ),

              // Input
              Container(
                padding: EdgeInsets.fromLTRB(14, 10, 14, 10 + bottomPadding),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkCard.withOpacity(0.7)
                      : Colors.white.withOpacity(0.8),
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.white10 : Colors.grey.shade300,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: TextField(
                          controller: _controller,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? AppTheme.darkTextLight
                                : AppTheme.textDark,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Ask about your health...',
                            hintStyle: TextStyle(
                              color: isDark
                                  ? AppTheme.darkTextDim
                                  : AppTheme.textLight,
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _isLoading ? null : _sendMessage,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.send_rounded,
                          color: _isLoading ? Colors.white54 : Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBubble(_ChatMsg message, bool isDark) {
    if (message.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 48),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(
              message.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ),
      ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 48),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                borderRadius: 14,
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 48),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              borderRadius: 14,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dot(0),
                  const SizedBox(width: 4),
                  _dot(1),
                  const SizedBox(width: 4),
                  _dot(2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(int index) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: Color(0xFF4ECDC4),
        shape: BoxShape.circle,
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .fadeIn(delay: (index * 200).ms)
        .then()
        .fadeOut(delay: 400.ms)
        .then()
        .fadeIn(delay: 200.ms);
  }
}

class _ChatMsg {
  final String text;
  final bool isUser;
  _ChatMsg({required this.text, required this.isUser});
}
