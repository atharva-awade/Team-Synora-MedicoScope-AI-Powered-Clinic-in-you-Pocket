import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:medicoscope/core/theme/app_theme.dart';
import 'package:medicoscope/core/providers/auth_provider.dart';
import 'package:medicoscope/core/widgets/glass_card.dart';
import 'package:medicoscope/services/cardio_service.dart';
import 'package:medicoscope/services/detection_service.dart';
import 'package:medicoscope/screens/heart/heart_results_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:medicoscope/core/theme/theme_provider.dart';
import 'package:medicoscope/core/locale/locale_provider.dart';
import 'package:medicoscope/core/locale/app_strings.dart';
import 'package:record/record.dart';

class HeartMonitoringScreen extends StatefulWidget {
  final String? patientId;

  const HeartMonitoringScreen({super.key, this.patientId});

  @override
  State<HeartMonitoringScreen> createState() => _HeartMonitoringScreenState();
}

class _HeartMonitoringScreenState extends State<HeartMonitoringScreen>
    with TickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  bool _isProcessing = false;
  int _secondsElapsed = 0;
  Timer? _recordTimer;
  String? _selectedFilePath;
  String? _selectedFileName;
  String _statusMessage = '';

  late AnimationController _pulseController;
  late AnimationController _hourglassController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _hourglassController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _pulseController.dispose();
    _hourglassController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/heart_sound_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, numChannels: 1),
      path: path,
    );

    setState(() {
      _isRecording = true;
      _secondsElapsed = 0;
      _selectedFilePath = path;
      _selectedFileName = null;
    });

    _pulseController.repeat();

    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _secondsElapsed++);
    });
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    _pulseController.stop();
    _pulseController.reset();

    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      _selectedFilePath = path ?? _selectedFilePath;
      _selectedFileName = 'Recorded (${_secondsElapsed}s)';
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'aac', 'm4a'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
        _selectedFileName = result.files.single.name;
      });
    }
  }

  Future<void> _analyze() async {
    if (_selectedFilePath == null) return;

    final lang =
        Provider.of<LocaleProvider>(context, listen: false).languageCode;
    setState(() {
      _isProcessing = true;
      _statusMessage = AppStrings.get('extracting_features', lang);
    });
    _hourglassController.repeat();

    // Cycle status messages (offline-first, no upload needed)
    final messages = [
      AppStrings.get('extracting_features', lang),
      AppStrings.get('analyzing_audio', lang),
      AppStrings.get('detecting_cardiac', lang),
      AppStrings.get('generating_heart_rate', lang),
      AppStrings.get('computing_prediction', lang),
    ];
    int msgIndex = 0;
    final msgTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _isProcessing) {
        msgIndex = (msgIndex + 1) % messages.length;
        setState(() => _statusMessage = messages[msgIndex]);
      }
    });

    try {
      final result = await CardioService.predict(_selectedFilePath!);

      msgTimer.cancel();
      _hourglassController.stop();
      _hourglassController.reset();

      // Save detection record
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      if (token != null) {
        final detectionService = DetectionService(token);
        await detectionService.saveRecord(
          className: result.prediction,
          confidence: result.avgHeartRate,
          category: 'heart_sound',
          description:
              'Heart sound analysis: ${result.prediction} (${result.severity}). '
              'Avg HR: ${result.avgHeartRate.toStringAsFixed(1)} BPM. '
              '${result.recommendation}',
          patientId: widget.patientId,
        );
      }

      setState(() => _isProcessing = false);

      if (mounted) {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                HeartResultsScreen(result: result),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  )),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    } catch (e) {
      msgTimer.cancel();
      _hourglassController.stop();
      _hourglassController.reset();
      setState(() {
        _isProcessing = false;
        _statusMessage = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final lang = Provider.of<LocaleProvider>(context).languageCode;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                : [const Color(0xFFFCE4EC), const Color(0xFFFFEBEE)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMedium),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios),
                      color:
                          isDark ? AppTheme.darkTextLight : AppTheme.textDark,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.get('heart_monitoring', lang),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppTheme.darkTextLight
                                  : AppTheme.textDark,
                            ),
                          ),
                          Text(
                            AppStrings.get('record_upload_heart', lang),
                            style: TextStyle(
                              fontSize: 12,
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

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(AppTheme.spacingLarge),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Heart icon
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final scale = _isRecording
                              ? 1.0 + 0.1 * sin(_pulseController.value * 2 * pi)
                              : 1.0;
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: _isRecording
                                  ? [
                                      const Color(0xFFFF5252),
                                      const Color(0xFFD32F2F)
                                    ]
                                  : _isProcessing
                                      ? [
                                          const Color(0xFF9E9E9E),
                                          const Color(0xFF757575)
                                        ]
                                      : [
                                          const Color(0xFFFF6B6B),
                                          const Color(0xFFEE5A24)
                                        ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_isRecording
                                        ? const Color(0xFFFF5252)
                                        : const Color(0xFFFF6B6B))
                                    .withOpacity(0.4),
                                blurRadius: _isRecording ? 30 : 20,
                                spreadRadius: _isRecording ? 5 : 0,
                              ),
                            ],
                          ),
                          child: _isProcessing
                              ? RotationTransition(
                                  turns: _hourglassController,
                                  child: const Icon(
                                    Icons.hourglass_top_rounded,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                )
                              : Icon(
                                  _isRecording
                                      ? Icons.stop_rounded
                                      : Icons.favorite_rounded,
                                  color: Colors.white,
                                  size: 48,
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Status text
                      Text(
                        _isRecording
                            ? AppStrings.get('recording', lang)
                            : _isProcessing
                                ? AppStrings.get('analyzing', lang)
                                : AppStrings.get('heart_sound_analysis', lang),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppTheme.darkTextLight
                              : AppTheme.textDark,
                        ),
                      ).animate().fadeIn(duration: 400.ms),

                      const SizedBox(height: 4),

                      if (_isProcessing)
                        Text(
                          _statusMessage,
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: isDark
                                ? AppTheme.darkTextGray
                                : AppTheme.textGray,
                          ),
                        ).animate(onPlay: (c) => c.repeat()).shimmer(
                              duration: 1500.ms,
                              color: isDark
                                  ? Colors.white24
                                  : const Color(0xFFFF6B6B).withOpacity(0.3),
                            )
                      else
                        Text(
                          _isRecording
                              ? AppStrings.get('place_near_chest', lang)
                              : AppStrings.get('record_or_upload', lang),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppTheme.darkTextGray
                                : AppTheme.textGray,
                          ),
                        ),

                      // Timer
                      if (_isRecording) ...[
                        const SizedBox(height: 16),
                        Text(
                          '${(_secondsElapsed ~/ 60).toString().padLeft(1, '0')}:${(_secondsElapsed % 60).toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w300,
                            color: isDark
                                ? AppTheme.darkTextLight
                                : AppTheme.textDark,
                          ),
                        ).animate().fadeIn(),
                      ],

                      // (status message already shown in subtitle above)

                      const SizedBox(height: 40),

                      // Action buttons
                      if (!_isProcessing && !_isRecording) ...[
                        // Record button
                        SizedBox(
                          width: double.infinity,
                          child: GestureDetector(
                            onTap: _startRecording,
                            child: GlassCard(
                              padding:
                                  const EdgeInsets.all(AppTheme.spacingMedium),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFF6B6B),
                                          Color(0xFFEE5A24)
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.mic_rounded,
                                        color: Colors.white, size: 26),
                                  ),
                                  const SizedBox(width: AppTheme.spacingMedium),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppStrings.get(
                                              'record_heart_sound', lang),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? AppTheme.darkTextLight
                                                : AppTheme.textDark,
                                          ),
                                        ),
                                        Text(
                                          AppStrings.get('use_phone_mic', lang),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? AppTheme.darkTextGray
                                                : AppTheme.textGray,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: isDark
                                        ? AppTheme.darkTextDim
                                        : AppTheme.textLight,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 200.ms, duration: 400.ms)
                            .slideY(begin: 0.1, end: 0),

                        const SizedBox(height: AppTheme.spacingMedium),

                        // Pick file button
                        SizedBox(
                          width: double.infinity,
                          child: GestureDetector(
                            onTap: _pickFile,
                            child: GlassCard(
                              padding:
                                  const EdgeInsets.all(AppTheme.spacingMedium),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF667EEA),
                                          Color(0xFF764BA2)
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.audio_file_rounded,
                                        color: Colors.white, size: 26),
                                  ),
                                  const SizedBox(width: AppTheme.spacingMedium),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppStrings.get(
                                              'pick_audio_file', lang),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? AppTheme.darkTextLight
                                                : AppTheme.textDark,
                                          ),
                                        ),
                                        Text(
                                          AppStrings.get(
                                              'select_audio_formats', lang),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? AppTheme.darkTextGray
                                                : AppTheme.textGray,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: isDark
                                        ? AppTheme.darkTextDim
                                        : AppTheme.textLight,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 300.ms, duration: 400.ms)
                            .slideY(begin: 0.1, end: 0),
                      ],

                      // Recording stop button
                      if (_isRecording)
                        GestureDetector(
                          onTap: _stopRecording,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFFF5252).withOpacity(0.4),
                                  blurRadius: 15,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.stop_rounded,
                                    color: Colors.white, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  AppStrings.get('stop_recording', lang),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn()
                            .scale(begin: const Offset(0.8, 0.8)),

                      const SizedBox(height: AppTheme.spacingLarge),

                      // Selected file indicator
                      if (_selectedFileName != null &&
                          !_isRecording &&
                          !_isProcessing)
                        GlassCard(
                          padding: const EdgeInsets.all(AppTheme.spacingMedium),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.audio_file_rounded,
                                    color: const Color(0xFF4CAF50),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _selectedFileName!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppTheme.darkTextLight
                                            : AppTheme.textDark,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      size: 18,
                                      color: isDark
                                          ? AppTheme.darkTextDim
                                          : AppTheme.textLight,
                                    ),
                                    onPressed: () => setState(() {
                                      _selectedFilePath = null;
                                      _selectedFileName = null;
                                    }),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: GestureDetector(
                                  onTap: _analyze,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFF6B6B),
                                          Color(0xFFEE5A24)
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF6B6B)
                                              .withOpacity(0.3),
                                          blurRadius: 12,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        AppStrings.get(
                                            'analyze_heart_sound', lang),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.1, end: 0),

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
}
