import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:medicoscope/core/providers/auth_provider.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/services/appointment_response_service.dart';
import 'package:medicoscope/services/mental_health_service.dart';

/// Represents one appointment request seen by the doctor, parsed from
/// the generic mental-health notifications bus.
class _DoctorAppointment {
  final String id;
  final String patientId;
  final String patientName;
  final DateTime requestedSlot;
  final String reason;
  final DateTime receivedAt;
  final bool read;
  final String status; // pending | confirmed | rescheduled

  const _DoctorAppointment({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.requestedSlot,
    required this.reason,
    required this.receivedAt,
    required this.read,
    this.status = 'pending',
  });
}

/// Doctor-side "My Appointments" screen. Shows every appointment request
/// from patients — pending at the top, then recently confirmed /
/// rescheduled ones. Each card has Confirm / Reschedule buttons for
/// pending requests (same as the notifications screen, but surfaced in
/// one dedicated deck for convenience).
class DoctorAppointmentsScreen extends StatefulWidget {
  const DoctorAppointmentsScreen({super.key});

  @override
  State<DoctorAppointmentsScreen> createState() =>
      _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen> {
  List<_DoctorAppointment> _pending = const [];
  List<_DoctorAppointment> _history = const [];
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
    if (!silent && mounted) setState(() => _loading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    final token = auth.token;
    if (user == null || token == null) {
      if (mounted && !silent) setState(() => _loading = false);
      return;
    }

    try {
      final raw = await MentalHealthService.getNotifications(
        doctorId: user.id,
        token: token,
      );

      final pending = <_DoctorAppointment>[];
      final history = <_DoctorAppointment>[];

      for (final n in raw) {
        final source = n['source']?.toString() ?? '';
        final report = n['report']?.toString() ?? '';
        final isPending =
            source == 'appointment_request' ||
                report.startsWith('APPOINTMENT REQUEST');
        final isHistory = source == 'appointment_confirmed' ||
            source == 'appointment_rescheduled' ||
            report.contains(AppointmentResponseService.confirmMarker) ||
            report.contains(AppointmentResponseService.rescheduleMarker);
        if (!isPending && !isHistory) continue;

        final slot = _extractSlot(report);
        final reason = _extractReason(report);
        final appt = _DoctorAppointment(
          id: n['id']?.toString() ?? '',
          patientId: n['patient_id']?.toString() ?? '',
          patientName:
              n['patient_name']?.toString() ?? 'Unknown patient',
          requestedSlot: slot ?? DateTime.now(),
          reason: reason,
          receivedAt: DateTime.tryParse(n['created_at']?.toString() ?? '') ??
              DateTime.now(),
          read: n['read'] == true,
          status: isPending
              ? 'pending'
              : (source == 'appointment_confirmed' ||
                      report
                          .contains(AppointmentResponseService.confirmMarker)
                  ? 'confirmed'
                  : 'rescheduled'),
        );
        if (isPending) {
          pending.add(appt);
        } else {
          history.add(appt);
        }
      }

      pending.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
      history.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));

      if (!mounted) return;
      setState(() {
        _pending = pending;
        _history = history;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _extractSlot(String report) {
    final re = RegExp(
        r'(?:Preferred slot|Original slot|Confirmed slot|Proposed new slot):\s*(\d{1,2})/(\d{1,2})/(\d{4})\s+at\s+(\d{1,2}):(\d{2})');
    final m = re.firstMatch(report);
    if (m == null) return null;
    try {
      return DateTime(
        int.parse(m.group(3)!),
        int.parse(m.group(2)!),
        int.parse(m.group(1)!),
        int.parse(m.group(4)!),
        int.parse(m.group(5)!),
      );
    } catch (_) {
      return null;
    }
  }

  String _extractReason(String report) {
    final m = RegExp(r'Reason:\s*(.+?)(?=\n|$)').firstMatch(report);
    return m?.group(1)?.trim() ?? '';
  }

  Future<void> _confirm(_DoctorAppointment a) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final doctor = auth.user;
    if (doctor == null) return;
    final note = await _askNote('Confirm appointment',
        'Any message for the patient? (optional)');
    if (!mounted) return;

    await AppointmentResponseService.confirm(
      patientId: a.patientId,
      patientName: a.patientName,
      doctorId: doctor.id,
      doctorName: doctor.name,
      originalSlot: a.requestedSlot,
      note: note ?? '',
    );
    await _removeOriginal(a.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Confirmation sent to ${a.patientName} for ${_fmt(a.requestedSlot)}'),
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
    _refresh(silent: true);
  }

  Future<void> _reschedule(_DoctorAppointment a) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final doctor = auth.user;
    if (doctor == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: a.requestedSlot,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(a.requestedSlot),
    );
    if (time == null || !mounted) return;
    final newSlot = DateTime(
        picked.year, picked.month, picked.day, time.hour, time.minute);
    final note = await _askNote('Reschedule appointment',
        'Reason for rescheduling? (optional)');
    if (!mounted) return;

    await AppointmentResponseService.reschedule(
      patientId: a.patientId,
      patientName: a.patientName,
      doctorId: doctor.id,
      doctorName: doctor.name,
      originalSlot: a.requestedSlot,
      newSlot: newSlot,
      note: note ?? '',
    );
    await _removeOriginal(a.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Reschedule proposal sent to ${a.patientName} for ${_fmt(newSlot)}'),
        backgroundColor: const Color(0xFFFF9800),
      ),
    );
    _refresh(silent: true);
  }

  Future<void> _removeOriginal(String id) async {
    if (id.isEmpty) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token;
    if (token == null) return;
    try {
      await MentalHealthService.deleteNotification(
        notificationId: id,
        token: token,
      );
    } catch (_) {}
  }

  Future<String?> _askNote(String title, String hint) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
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
              _header(isDark),
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
                            if (_pending.isEmpty && _history.isEmpty)
                              _empty(isDark)
                            else ...[
                              if (_pending.isNotEmpty) ...[
                                _sectionTitle('Pending requests', isDark,
                                    color: const Color(0xFFFF9800)),
                                const SizedBox(height: 8),
                                for (int i = 0; i < _pending.length; i++)
                                  _pendingCard(_pending[i], i, isDark),
                                const SizedBox(height: 20),
                              ],
                              if (_history.isNotEmpty) ...[
                                _sectionTitle('History', isDark),
                                const SizedBox(height: 8),
                                for (int i = 0; i < _history.length; i++)
                                  _historyCard(_history[i], i, isDark),
                              ],
                            ],
                            const SizedBox(height: 40),
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

  Widget _header(bool isDark) {
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
                  '${_pending.length} pending • ${_history.length} processed',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
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

  Widget _sectionTitle(String t, bool isDark, {Color? color}) => Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: color ?? const Color(0xFF7C4DFF),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            t,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
            ),
          ),
        ],
      );

  Widget _pendingCard(_DoctorAppointment a, int i, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!a.read)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF9800),
                      shape: BoxShape.circle,
                    ),
                  ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_outline,
                      color: Color(0xFFFF9800), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.patientName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppTheme.darkTextLight
                              : AppTheme.textDark,
                        ),
                      ),
                      Text(
                        'Requested ${_ago(a.receivedAt)}',
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
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF7C4DFF).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event,
                      size: 14, color: Color(0xFF7C4DFF)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Preferred: ${_fmt(a.requestedSlot)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7C4DFF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (a.reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '"${a.reason}"',
                style: TextStyle(
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                  color:
                      isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _confirm(a),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Confirm'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle:
                          const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reschedule(a),
                    icon: const Icon(Icons.schedule_rounded, size: 16),
                    label: const Text('Reschedule'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF9800),
                      side: const BorderSide(color: Color(0xFFFF9800)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle:
                          const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(delay: (i * 60).ms, duration: 300.ms)
          .slideY(begin: 0.05, end: 0, curve: Curves.easeOut),
    );
  }

  Widget _historyCard(_DoctorAppointment a, int i, bool isDark) {
    final isConfirmed = a.status == 'confirmed';
    final accent =
        isConfirmed ? const Color(0xFF4CAF50) : const Color(0xFFFF9800);
    final label = isConfirmed ? 'Confirmed' : 'Rescheduled';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isConfirmed
                    ? Icons.check_circle_outline
                    : Icons.event_repeat,
                color: accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label — ${a.patientName}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppTheme.darkTextLight
                          : AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_fmt(a.requestedSlot)} • ${_ago(a.receivedAt)}',
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
          ],
        ),
      )
          .animate()
          .fadeIn(delay: (i * 40).ms, duration: 250.ms),
    );
  }

  Widget _empty(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note,
                size: 60,
                color: isDark ? AppTheme.darkTextDim : AppTheme.textLight),
            const SizedBox(height: 12),
            Text(
              'No appointment requests',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your patients haven\'t booked an appointment yet.\nRequests will appear here automatically.',
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
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
