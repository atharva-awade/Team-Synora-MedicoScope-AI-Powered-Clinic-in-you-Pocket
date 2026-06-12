import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:medicoscope/core/constants/disease_constants.dart';
import 'package:medicoscope/core/providers/auth_provider.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';
import 'package:medicoscope/services/appointment_service.dart';
import 'package:medicoscope/services/disease_result_pipeline.dart';

/// Opens a bottom sheet that lets the patient book an appointment with
/// their linked doctor for a particular disease / modality.
Future<void> showBookAppointmentSheet(
  BuildContext context, {
  DiseaseType? disease,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BookAppointmentSheet(disease: disease),
  );
}

class _BookAppointmentSheet extends StatefulWidget {
  final DiseaseType? disease;
  const _BookAppointmentSheet({this.disease});

  @override
  State<_BookAppointmentSheet> createState() => _BookAppointmentSheetState();
}

class _BookAppointmentSheetState extends State<_BookAppointmentSheet> {
  final TextEditingController _reasonCtrl = TextEditingController();
  DateTime _slot = DateTime.now().add(const Duration(days: 1, hours: 10));
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _slot,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_slot),
    );
    if (time == null || !mounted) return;
    setState(() {
      _slot = DateTime(
          picked.year, picked.month, picked.day, time.hour, time.minute);
    });
  }

  Future<void> _book() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) {
      setState(() {
        _busy = false;
        _error = 'Please sign in first.';
      });
      return;
    }
    final doctorId =
        await DiseaseResultPipeline.resolveDoctorIdFor(auth.token);
    if (doctorId == null || doctorId.isEmpty) {
      setState(() {
        _busy = false;
        _error =
            'No doctor linked yet. Use the "Link Doctor" screen first — the appointment needs a recipient.';
      });
      return;
    }

    try {
      await AppointmentService.book(
        doctorId: doctorId,
        patientId: user.id,
        patientName: user.name,
        preferredSlot: _slot,
        modality: widget.disease == null
            ? 'general'
            : DiseaseRegistry.of(widget.disease!).title.toLowerCase(),
        reason: _reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not send appointment request. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final accent = widget.disease == null
        ? const Color(0xFF4ECDC4)
        : DiseaseRegistry.of(widget.disease!).gradient.first;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkBackground : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _done ? _buildSuccess(isDark, accent) : _buildForm(isDark, accent),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(bool isDark, Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.event_available, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Book appointment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppTheme.darkTextLight
                          : AppTheme.textDark,
                    ),
                  ),
                  Text(
                    widget.disease == null
                        ? 'with your linked doctor'
                        : '${DiseaseRegistry.of(widget.disease!).title} consultation with your linked doctor',
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
        const SizedBox(height: 18),
        Text(
          'Preferred date & time',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined, color: accent, size: 18),
                const SizedBox(width: 10),
                Text(
                  _fmt(_slot),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppTheme.darkTextLight
                        : AppTheme.textDark,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded,
                    color:
                        isDark ? AppTheme.darkTextGray : AppTheme.textGray),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Reason (optional)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _reasonCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText:
                'e.g. "Follow-up on my lab report" or "Review latest BP reading"',
            hintStyle: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextDim : AppTheme.textLight,
            ),
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.withOpacity(0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5252).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFFFF5252).withOpacity(0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFFFF5252), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFFF5252),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_error != null) const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _book,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(_busy ? 'Requesting…' : 'Request appointment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildSuccess(bool isDark, Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded,
              size: 44, color: Color(0xFF4CAF50)),
        ),
        const SizedBox(height: 14),
        Text(
          'Appointment request sent',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? AppTheme.darkTextLight : AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your doctor will see it in their notifications and confirm a slot shortly.\nPreferred time: ${_fmt(_slot)}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.5,
            color: isDark ? AppTheme.darkTextGray : AppTheme.textGray,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Done',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 6),
      ],
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
    final h = d.hour == 0
        ? 12
        : (d.hour > 12 ? d.hour - 12 : d.hour);
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    final mi = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month]} ${d.year}, $h:$mi $ap';
  }
}
