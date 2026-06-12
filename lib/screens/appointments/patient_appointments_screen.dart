import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:medicoscope/core/providers/auth_provider.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/services/appointment_response_service.dart';
import 'package:medicoscope/services/appointment_service.dart';

/// Patient-facing appointments inbox. Shows the doctor's Confirm /
/// Reschedule responses to requests the patient previously sent.
class PatientAppointmentsScreen extends StatefulWidget {
  const PatientAppointmentsScreen({super.key});

  @override
  State<PatientAppointmentsScreen> createState() =>
      _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState
    extends State<PatientAppointmentsScreen> {
  List<AppointmentResponse> _responses = const [];
  List<Appointment> _pending = const [];
  bool _loading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _pollTimer = Timer.periodic(
        const Duration(seconds: 15), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null || auth.token == null) {
      if (!silent && mounted) setState(() => _loading = false);
      return;
    }

    final responses = await AppointmentResponseService.fetchForPatient(
      patientId: user.id,
      token: auth.token!,
    );
    final pending = await AppointmentService.getAll();

    if (!mounted) return;
    setState(() {
      _responses = responses..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
      _pending = pending
          .where((p) => p.status == 'pending' &&
              !responses.any((r) => _sameSlot(r.originalSlot, p.preferredSlot)))
          .toList();
      _loading = false;
    });
  }

  bool _sameSlot(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      a.hour == b.hour &&
      a.minute == b.minute;

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
              _buildHeader(isDark),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.all(AppTheme.spacingLarge),
                          children: [
                            if (_pending.isEmpty && _responses.isEmpty)
                              _buildEmpty(isDark)
                            else ...[
                              if (_pending.isNotEmpty) ...[
                                _sectionTitle('Waiting for doctor', isDark),
                                const SizedBox(height: 8),
                                for (final p in _pending)
                                  _pendingCard(p, isDark),
                                const SizedBox(height: 18),
                              ],
                              if (_responses.isNotEmpty) ...[
                                _sectionTitle('Doctor responses', isDark),
                                const SizedBox(height: 8),
                                for (var i = 0; i < _responses.length; i++)
                                  _responseCard(_responses[i], i, isDark),
                              ],
                            ],
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios),
            color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Appointments',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                  ),
                ),
                Text(
                  'Doctor confirmations & reschedule proposals',
                  style: TextStyle(
                    fontSize: 11.5,
                    color:
                        isDark ? AppTheme.darkTextGray : AppTheme.textGray,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _refresh(),
            icon: const Icon(Icons.refresh_rounded),
            color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t, bool isDark) => Text(
        t,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
        ),
      );

  Widget _pendingCard(Appointment p, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF7C4DFF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.schedule,
                  color: Color(0xFF7C4DFF), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Waiting for confirmation',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppTheme.darkTextLight
                          : AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Requested for ${_fmt(p.preferredSlot)} • ${p.modality}',
                    style: TextStyle(
                      fontSize: 11.5,
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
    );
  }

  Widget _responseCard(AppointmentResponse r, int i, bool isDark) {
    final isConfirmed = r.status == AppointmentStatus.confirmed;
    final accent = isConfirmed
        ? const Color(0xFF4CAF50)
        : const Color(0xFFFF9800);
    final icon = isConfirmed ? Icons.check_circle_rounded : Icons.event_repeat;
    final title = isConfirmed
        ? 'Appointment confirmed'
        : 'Reschedule proposed';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _openResponseDetail(r),
        child: GlassCard(
          padding: const EdgeInsets.all(AppTheme.spacingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (!r.read)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? AppTheme.darkTextLight
                                      : AppTheme.textDark,
                                ),
                              ),
                            ),
                            Text(
                              _ago(r.receivedAt),
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark
                                    ? AppTheme.darkTextDim
                                    : AppTheme.textLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          r.doctorName,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
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
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event, size: 14, color: accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isConfirmed
                            ? 'Confirmed for ${_fmt(r.originalSlot)}'
                            : 'Proposed new slot: ${_fmt(r.newSlot ?? r.originalSlot)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (r.note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '"${r.note}"',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                    color: isDark
                        ? AppTheme.darkTextLight
                        : AppTheme.textDark,
                  ),
                ),
              ],
            ],
          ),
        ),
      )
          .animate()
          .fadeIn(delay: (i * 60).ms, duration: 300.ms)
          .slideY(begin: 0.05, end: 0, curve: Curves.easeOut),
    );
  }

  Future<void> _openResponseDetail(AppointmentResponse r) async {
    if (!r.read) {
      await AppointmentResponseService.markRead(r.id);
      _refresh(silent: true);
    }
  }

  Widget _buildEmpty(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy,
                size: 64,
                color: isDark ? AppTheme.darkTextDim : AppTheme.textLight),
            const SizedBox(height: 12),
            Text(
              'No appointments yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Book one from any disease deck or the chatbot — confirmations will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
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
    final h = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    final mi = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month]} ${d.year}, $h:$mi $ap';
  }

  String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
