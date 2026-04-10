import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as dart_math;
import '../services/audio_service.dart';
import '../services/app_state_provider.dart';
import '../services/tab_generator.dart';
import '../services/audio_analysis_service.dart';
import '../models/note.dart';
import '../models/detection_params.dart';
import 'edit_screen.dart';
import 'export_screen.dart';
import 'processing_screen.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  _RecordScreenState createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  String selectedInstrument = 'Guitar';
  String detectionSensitivity = 'High'; // High = capture as many notes as possible
  final List<Map<String, dynamic>> instruments = [
    {'name': 'Guitar', 'icon': Icons.music_note, 'emoji': '🎸'},
    {'name': 'Bass', 'icon': Icons.music_note, 'assetIcon': 'assets/images/bass_icon.png'},
    {'name': 'Banjo', 'icon': Icons.music_note, 'emoji': '🪕'},
    {'name': 'Violin', 'icon': Icons.music_note, 'emoji': '🎻'},
  ];
  bool isRecording = false;
  bool _isStopping = false; // loading state between Stop and ProcessingScreen
  bool _showAdvancedParams = false; // toggle for advanced parameter sliders
  final AudioService audioService = AudioService();
  final TabGeneratorService tabGenerator = TabGeneratorService();
  final AudioAnalysisService audioAnalysis = AudioAnalysisService();
  double currentAudioLevel = 0.0;
  StreamSubscription<double>? _audioLevelSubscription;
  
  // Custom detection params (initialised from the default preset).
  late DetectionParams _customParams;
  
  // Analysis results
  AnalysisResult? _lastAnalysisResult;
  
  // Real-time frequency estimation
  double _estimatedFrequency = 0.0;
  String _currentNoteName = '--';
  int _currentOctave = 0;
  
  // Instrument frequency ranges (Hz)
  Map<String, Map<String, double>> get instrumentRanges => {
    'Guitar': {'low': 82.0, 'high': 1318.0, 'typical': 200.0},
    'Bass': {'low': 41.0, 'high': 392.0, 'typical': 100.0},
    'Piano': {'low': 27.5, 'high': 4186.0, 'typical': 440.0},
    'Violin': {'low': 196.0, 'high': 3136.0, 'typical': 440.0},
    'Drums': {'low': 60.0, 'high': 8000.0, 'typical': 1000.0},
    'Banjo': {'low': 146.8, 'high': 1760.0, 'typical': 400.0},
  };

  Widget _buildSensitivityChip(String label, String subtitle) {
    final isSelected = detectionSensitivity == label;
    return ChoiceChip(
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: isSelected ? Colors.black : Colors.grey[200],
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              color: isSelected ? Colors.black87 : Colors.grey[400],
            ),
          ),
        ],
      ),
      selected: isSelected,
      selectedColor: Colors.red[400],
      backgroundColor: Colors.grey[850],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? Colors.red[500]! : Colors.grey[700]!,
        ),
      ),
      onSelected: (_) {
        setState(() {
          detectionSensitivity = label;
          _customParams = DetectionParams.fromPreset(label);
        });

        // Persist sensitivity choice in global app state if available
        try {
          final appState = Provider.of<AppStateProvider>(context, listen: false);
          appState.setDetectionSensitivity(label);
        } catch (_) {
          // If provider is not available in this context, ignore
        }
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // Initialize detection sensitivity from global app settings if available
    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final storedSensitivity = appState.detectionSensitivity;
      if (storedSensitivity.isNotEmpty) {
        detectionSensitivity = storedSensitivity;
      }
      _customParams = appState.detectionParams;
    } catch (_) {
      // If provider is not available yet, fall back to default
      _customParams = DetectionParams.fromPreset(detectionSensitivity);
    }

    // Listen to audio level stream for visualization
    _audioLevelSubscription = audioService.audioLevelStream.listen((level) {
      if (mounted && isRecording) {
        setState(() {
          currentAudioLevel = level;
          // Estimate frequency based on amplitude and instrument range
          _updateFrequencyEstimate();
        });
      }
    });
  }
  
  void _updateFrequencyEstimate() {
    if (!isRecording || currentAudioLevel < 0.1) {
      _estimatedFrequency = 0.0;
      _currentNoteName = '--';
      _currentOctave = 0;
      return;
    }
    
    // Get instrument frequency range
    final range = instrumentRanges[selectedInstrument]!;
    
    // Estimate frequency based on amplitude (louder = higher typically)
    // This is a rough approximation - real detection happens after recording
    final normalizedLevel = currentAudioLevel.clamp(0.0, 1.0);
    final freqRange = range['high']! - range['low']!;
    _estimatedFrequency = range['low']! + (normalizedLevel * freqRange * 0.5);
    
    // Convert to note (simple approximation)
    final noteInfo = _frequencyToNote(_estimatedFrequency);
    _currentNoteName = noteInfo['name']!;
    _currentOctave = int.tryParse(noteInfo['octave']!) ?? 0;
  }
  
  Map<String, String> _frequencyToNote(double frequency) {
    if (frequency <= 0) return {'name': '--', 'octave': '0'};
    
    const double a4 = 440.0;
    const int a4Midi = 69;
    final midiNote = (12 * (dart_math.log(frequency / a4) / dart_math.log(2)) + a4Midi).round();
    final octave = (midiNote ~/ 12) - 1;
    final noteIndex = midiNote % 12;
    const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    
    return {
      'name': noteNames[noteIndex.clamp(0, 11)],
      'octave': octave.toString(),
    };
  }

  @override
  void dispose() {
    _audioLevelSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'RECORD',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.red[600],
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey[900]!,
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isRecording) ...[
                  // Instrument Selection - Mobile optimized grid
                  Text(
                    'SELECT INSTRUMENT',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: instruments.length,
                    itemBuilder: (context, index) {
                      final instrument = instruments[index];
                      final isSelected = selectedInstrument == instrument['name'];
                      return InkWell(
                        onTap: () {
                          setState(() {
                            selectedInstrument = instrument['name'] as String;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.red[900]!.withOpacity(0.3) : Colors.grey[900],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? Colors.red[700]! : Colors.grey[800]!,
                              width: isSelected ? 3 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.red[900]!.withOpacity(0.5),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              instrument.containsKey('assetIcon')
                                ? Image.asset(
                                    instrument['assetIcon'] as String,
                                    width: 28,
                                    height: 28,
                                    semanticLabel: instrument['name'] as String,
                                  )
                                : Text(
                                    instrument['emoji'] as String,
                                    style: const TextStyle(fontSize: 28),
                                  ),
                              const SizedBox(height: 4),
                              Text(
                                instrument['name'] as String,
                                style: TextStyle(
                                  color: isSelected ? Colors.red[400] : Colors.grey[400],
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Detection Sensitivity Control
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.tune, color: Colors.red[600], size: 24),
                            const SizedBox(width: 12),
                            Text(
                              'DETECTION SENSITIVITY',
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildSensitivityChip('Low', 'Cleaner, fewer notes'),
                            _buildSensitivityChip('Medium', 'Balanced'),
                            _buildSensitivityChip('High', 'Capture everything'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Toggle for advanced sliders
                        InkWell(
                          onTap: () {
                            setState(() {
                              _showAdvancedParams = !_showAdvancedParams;
                            });
                          },
                          child: Row(
                            children: [
                              Icon(
                                _showAdvancedParams
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: Colors.grey[500],
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _showAdvancedParams
                                    ? 'Hide advanced parameters'
                                    : 'Customise parameters',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_showAdvancedParams) ..._buildAdvancedParamSliders(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const SizedBox(height: 24),
                ],
                
                // Recording Status - show only while recording
                if (isRecording)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.red[900]!.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red[700]!,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mic,
                          size: 18,
                          color: Colors.red[600],
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'RECORDING...',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isRecording) const SizedBox(height: 8),

                // Audio level visualization (conditional)
                ..._buildRecordingVisualization(),

                const SizedBox(height: 40),
            
            // Large mobile-friendly record button with gradient
            Center(
              child: GestureDetector(
                onTap: _isStopping ? null : () async {
                    if (isRecording) {
                      // Show loading state while stopping
                      setState(() {
                        _isStopping = true;
                      });

                      // Stop recording
                      final savedPath = await audioService.stopRecording();
                      setState(() {
                        isRecording = false;
                      });
                      
                      if (savedPath == null || !File(savedPath).existsSync()) {
                        setState(() { _isStopping = false; });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Error: Recording file not found'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        return;
                      }
                      
                      if (!mounted) return;

                      // Show dedicated processing screen with detailed logs
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (context) => ProcessingScreen<void>(
                            title: 'Processing Recording',
                            subtitle: 'Analyzing audio and generating transcription...',
                            runTask: (log) async {
                              log('Loading recorded audio from: $savedPath');
                              try {
                                _lastAnalysisResult = await audioAnalysis.analyzeRecording(
                                  savedPath,
                                  instrument: selectedInstrument,
                                  sensitivity: detectionSensitivity.toLowerCase(),
                                  params: _customParams,
                                );

                                if (_lastAnalysisResult != null) {
                                  log('Analysis complete. '
                                      'Notes detected: ${_lastAnalysisResult!.notes.length}.');
                                  log('Tempo: ${_lastAnalysisResult!.rhythm.formattedTempo}, '
                                      'Noise reduction: '
                                      '${_lastAnalysisResult!.noiseReductionPercent.toStringAsFixed(1)}%.');
                                } else {
                                  log('Analysis returned no result. Using fallback notes.');
                                }
                              } catch (e, stack) {
                                print('=== ANALYSIS FAILED ===');
                                print('Error: $e');
                                print('Stack trace:');
                                print(stack);
                                log('Audio analysis failed. Using fallback transcription.');
                                _lastAnalysisResult = null;
                              }

                              final appStateProvider =
                                  Provider.of<AppStateProvider>(context, listen: false);

                              log('Generating transcription text...');
                              final newTranscription = _generateTranscription();

                              // Extract the notes from analysis result or use fallback
                              List<Note> notesForExport;
                              if (_lastAnalysisResult != null) {
                                notesForExport = _lastAnalysisResult!.notes;
                              } else {
                                // Simple musical fallback if analysis failed
                                notesForExport = [
                                  Note(
                                    frequency: 196,
                                    noteName: 'G',
                                    octave: 3,
                                    startTime: 0.0,
                                    endTime: 0.5,
                                    confidence: 0.85,
                                  ),
                                  Note(
                                    frequency: 220,
                                    noteName: 'A',
                                    octave: 3,
                                    startTime: 0.5,
                                    endTime: 1.0,
                                    confidence: 0.88,
                                  ),
                                  Note(
                                    frequency: 247,
                                    noteName: 'B',
                                    octave: 3,
                                    startTime: 1.0,
                                    endTime: 1.5,
                                    confidence: 0.90,
                                  ),
                                ];
                              }

                              log('Saving transcription and notes to app state...');
                              appStateProvider.addTranscription(
                                newTranscription,
                                notes: notesForExport,
                                instrument: selectedInstrument,
                              );
                              appStateProvider.setCurrentTranscription(
                                newTranscription,
                                notes: notesForExport,
                                instrument: selectedInstrument,
                              );
                              log('Transcription ready for export.');
                            },
                          ),
                        ),
                      );

                      if (!mounted) return;

                      setState(() { _isStopping = false; });

                      // Navigate to export screen after processing completes
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExportScreen(),
                        ),
                      );
                    } else {
                      // Start recording
                      _lastAnalysisResult = null; // Clear previous analysis
                      
                      try {
                        await audioService.startRecording();
                        setState(() {
                          isRecording = true;
                        });
                      } catch (e) {
                        print('Failed to start recording: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to start recording: ${e.toString()}'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 5),
                            ),
                          );
                        }
                        return;
                      }
                      
                      // Show recording location
                      final recordingsDir = await audioService.getRecordingsDirectory();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Recording started - Capturing audio...'),
                                const SizedBox(height: 4),
                                Text(
                                  'Saving to: $recordingsDir',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    }
                  },
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: _isStopping
                      ? LinearGradient(
                          colors: [Colors.grey[700]!, Colors.grey[800]!],
                        )
                      : isRecording 
                        ? LinearGradient(
                            colors: [Colors.grey[800]!, Colors.grey[900]!],
                          )
                        : LinearGradient(
                            colors: [Colors.red[600]!, Colors.red[800]!],
                          ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: isRecording ? Colors.grey[900]!.withOpacity(0.5) : Colors.red[900]!.withOpacity(0.7),
                        blurRadius: 15,
                        spreadRadius: 3,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: _isStopping
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'PROCESSING...',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
                            size: 40,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            isRecording ? 'STOP & EXPORT' : 'RECORD',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Removed "Edit Sample" block to simplify flow
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds slider widgets for each advanced detection parameter.
  List<Widget> _buildAdvancedParamSliders() {
    Widget slider({
      required String label,
      required String tooltip,
      required double value,
      required double min,
      required double max,
      required int divisions,
      required ValueChanged<double> onChanged,
      String Function(double)? format,
    }) {
      final fmt = format ?? (v) => v.toStringAsFixed(2);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                  ),
                ),
                Tooltip(
                  message: tooltip,
                  child: Icon(Icons.help_outline, size: 14, color: Colors.grey[600]),
                ),
                const SizedBox(width: 4),
                Text(
                  fmt(value),
                  style: TextStyle(
                    color: Colors.red[400],
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: Colors.red[700],
                inactiveTrackColor: Colors.grey[800],
                thumbColor: Colors.red[400],
                overlayColor: Colors.red.withOpacity(0.15),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      );
    }

    void _updateParam(DetectionParams Function(DetectionParams) updater) {
      setState(() {
        _customParams = updater(_customParams);
      });
      try {
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        appState.setDetectionParams(_customParams);
      } catch (_) {}
    }

    return [
      const SizedBox(height: 8),
      slider(
        label: 'Pitch Confidence',
        tooltip: 'Min YIN confidence to accept a pitch (lower = more permissive)',
        value: _customParams.minYinConfidence,
        min: 0.30,
        max: 0.95,
        divisions: 65,
        onChanged: (v) => _updateParam((p) => p.copyWith(minYinConfidence: v)),
      ),
      slider(
        label: 'Min Note Duration (s)',
        tooltip: 'Segments shorter than this are discarded',
        value: _customParams.minNoteDuration,
        min: 0.01,
        max: 0.10,
        divisions: 90,
        format: (v) => '${(v * 1000).round()} ms',
        onChanged: (v) => _updateParam((p) => p.copyWith(minNoteDuration: v)),
      ),
      slider(
        label: 'Onset Sensitivity',
        tooltip: 'Energy onset factor (lower = more sensitive)',
        value: _customParams.onsetFactor,
        min: 0.3,
        max: 2.0,
        divisions: 34,
        onChanged: (v) => _updateParam((p) => p.copyWith(onsetFactor: v)),
      ),
      slider(
        label: 'Energy Jump',
        tooltip: 'Energy jump threshold for new note detection',
        value: _customParams.jumpFactor,
        min: 1.0,
        max: 2.5,
        divisions: 30,
        onChanged: (v) => _updateParam((p) => p.copyWith(jumpFactor: v)),
      ),
      slider(
        label: 'Spectral Flux',
        tooltip: 'Spectral flux factor (lower = more sensitive)',
        value: _customParams.fluxFactor,
        min: 0.3,
        max: 3.0,
        divisions: 54,
        onChanged: (v) => _updateParam((p) => p.copyWith(fluxFactor: v)),
      ),
      slider(
        label: 'Min Gap (s)',
        tooltip: 'Minimum gap between onsets',
        value: _customParams.minGapSeconds,
        min: 0.03,
        max: 0.40,
        divisions: 37,
        format: (v) => '${(v * 1000).round()} ms',
        onChanged: (v) => _updateParam((p) => p.copyWith(minGapSeconds: v)),
      ),
      slider(
        label: 'Noise Reduction',
        tooltip: 'Higher = more noise removed (risk of cutting quiet notes)',
        value: _customParams.noiseReductionFactor,
        min: 1.0,
        max: 3.5,
        divisions: 50,
        onChanged: (v) => _updateParam((p) => p.copyWith(noiseReductionFactor: v)),
      ),
      slider(
        label: 'Noise Gate',
        tooltip: 'Threshold factor for adaptive noise gate (lower = more permissive)',
        value: _customParams.noiseGateFactor,
        min: 0.01,
        max: 0.30,
        divisions: 29,
        onChanged: (v) => _updateParam((p) => p.copyWith(noiseGateFactor: v)),
      ),
      slider(
        label: 'Repeat Note Merge Gap (s)',
        tooltip: 'Max gap for merging same-pitch notes. Lower = better repeated-note detection.',
        value: _customParams.repeatNoteMergeGap,
        min: 0.0,
        max: 0.50,
        divisions: 50,
        format: (v) => '${(v * 1000).round()} ms',
        onChanged: (v) => _updateParam((p) => p.copyWith(repeatNoteMergeGap: v)),
      ),
    ];
  }
  
  List<Widget> _buildRecordingVisualization() {
    if (!isRecording) return [];

    return [
      // Real-time frequency display
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900]!.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[900]!.withOpacity(0.5), width: 2),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recording: $selectedInstrument',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Range: ${instrumentRanges[selectedInstrument]!["low"]!.toStringAsFixed(0)}-${instrumentRanges[selectedInstrument]!["high"]!.toStringAsFixed(0)} Hz',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: currentAudioLevel > 0.1 ? Colors.red[700] : Colors.grey[700],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.graphic_eq,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentAudioLevel > 0.1 ? '$_currentNoteName$_currentOctave' : '--',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (currentAudioLevel > 0.1)
                            Text(
                              '~${_estimatedFrequency.toStringAsFixed(0)} Hz',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'Signal Strength',
        style: TextStyle(fontSize: 14, color: Colors.grey[500], fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 8),
      Container(
        height: 100,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.red[900]!.withOpacity(0.3),
              Colors.grey[900]!.withOpacity(0.5),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[900]!.withOpacity(0.3)),
        ),
        child: CustomPaint(
          size: const Size(double.infinity, 100),
          painter: FrequencyVisualizerPainter(
            currentAudioLevel,
            instrumentRanges[selectedInstrument]!,
          ),
        ),
      ),
      const SizedBox(height: 12),
      LinearProgressIndicator(
        value: currentAudioLevel,
        backgroundColor: Colors.grey[800],
        valueColor: AlwaysStoppedAnimation<Color>(
          currentAudioLevel > 0.7 ? Colors.red : Colors.red[700]!,
        ),
        minHeight: 10,
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Weak',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          Text(
            currentAudioLevel < 0.3
                ? 'Too Quiet'
                : currentAudioLevel > 0.8
                    ? 'Very Loud'
                    : 'Good Level',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: currentAudioLevel < 0.3
                  ? Colors.orange
                  : currentAudioLevel > 0.8
                      ? Colors.red
                      : Colors.red[400]!,
            ),
          ),
          Text(
            'Strong',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red[900]!, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.red[400]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Note detection shown above is approximate. Accurate pitch detection happens after recording stops.',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[400],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
    ];
  }
  
  // Delimiter used to separate tab-only content from additional details
  // in the transcription string. UI code splits on this to show additional
  // info in a collapsible section.
  static const String additionalInfoDelimiter = '===ADDITIONAL_INFO===';

  // Generate a transcription based on true audio analysis
  String _generateTranscription() {
    final now = DateTime.now();
    final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
                      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    
    // Use notes from true audio analysis or fallback to simple notes
    List<Note> notesToUse;
    String analysisMethod;
    String rhythmInfo = '';
    
    if (_lastAnalysisResult != null) {
      notesToUse = _lastAnalysisResult!.notes;
      analysisMethod = 'Professional Audio Analysis: $selectedInstrument Mode';
      
      final rhythm = _lastAnalysisResult!.rhythm;
      rhythmInfo = '''Rhythm Analysis:
Tempo: ${rhythm.formattedTempo}
Time Signature: ${rhythm.timeSignature}
Beats Detected: ${rhythm.beats.length}
Average Note Duration: ${rhythm.averageDuration.toStringAsFixed(3)}s
Beat Pattern: ${rhythm.beats.take(8).map((b) => b.toStringAsFixed(2)).join(', ')}${rhythm.beats.length > 8 ? '...' : ''}

Audio Processing:
Original Samples: ${_lastAnalysisResult!.originalSamples}
Cleaned Samples: ${_lastAnalysisResult!.cleanedSamples}
Noise Reduction: ${_lastAnalysisResult!.noiseReductionPercent.toStringAsFixed(1)}%
Duration: ${_lastAnalysisResult!.duration.toStringAsFixed(2)}s

Instrument-Specific Processing:
Target: $selectedInstrument
Frequency Filtering: Active
Spectral Noise Reduction: Applied
Harmonic Enhancement: Active''';
    } else {
      // Fallback to simple notes if analysis failed
      notesToUse = [
        Note(frequency: 196, noteName: 'G', octave: 3, startTime: 0.0, endTime: 0.5, confidence: 0.85),
        Note(frequency: 220, noteName: 'A', octave: 3, startTime: 0.5, endTime: 1.0, confidence: 0.88),
        Note(frequency: 247, noteName: 'B', octave: 3, startTime: 1.0, endTime: 1.5, confidence: 0.90),
      ];
      analysisMethod = 'Fallback Mode (Analysis Failed)';
    }
    
    // Use TabGeneratorService to generate tabs from notes, respecting instrument
    String generatedTab = tabGenerator.generateTab(
      notesToUse,
      instrument: selectedInstrument,
    );
    String textNotation = tabGenerator.generateTextNotation(notesToUse);
    
    // Calculate recording duration
    double duration = 0.0;
    if (notesToUse.isNotEmpty) {
      duration = notesToUse.last.endTime;
    }
    
    final estimatedTempoLine = _lastAnalysisResult != null
      ? 'Estimated Tempo: ${_lastAnalysisResult!.rhythm.formattedTempo}\n'
      : '';

    // Primary tab content (always visible)
    final tabSection = '''
Recording Details:
Timestamp: $timestamp
Instrument: $selectedInstrument
Duration: ${duration.toStringAsFixed(1)}s
Notes Detected: ${notesToUse.length}
$estimatedTempoLine
Generated Tablature:
$generatedTab
''';

    // Additional details (collapsed by default in UI)
    final additionalSection = '''
$textNotation
${rhythmInfo.isNotEmpty ? '\n$rhythmInfo\n' : ''}
Analysis Method: $analysisMethod
Noise Suppression:
  • Spectral Subtraction (noise profile removal)
  • Instrument-Specific Band-Pass Filter
  • Adaptive RMS-Based Noise Gate
  • DC Offset Removal
  • Harmonic Enhancement
Pitch Detection: Yin Algorithm (autocorrelation-based)
Format: WAV (uncompressed PCM), 44.1kHz, 16-bit
''';

    return '$tabSection$additionalInfoDelimiter\n$additionalSection';
  }
}

// Enhanced frequency visualizer painter
class FrequencyVisualizerPainter extends CustomPainter {
  final double audioLevel;
  final Map<String, double> frequencyRange;
  
  FrequencyVisualizerPainter(this.audioLevel, this.frequencyRange);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;
    
    final centerY = size.height / 2;
    const barWidth = 6.0;
    const spacing = 3.0;
    final totalBarWidth = barWidth + spacing;
    final numberOfBars = (size.width / totalBarWidth).floor();
    
    for (int i = 0; i < numberOfBars; i++) {
      // Create decaying wave pattern
      final position = i / numberOfBars;
      final decay = 1.0 - (position * 0.5);
      final wave = dart_math.sin(position * dart_math.pi * 4) * 0.3;
      
      final height = (audioLevel * decay + wave.abs()) * size.height * 0.9;
      final x = i * totalBarWidth;
      
      // Color gradient based on position (low to high frequency)
      final color = Color.lerp(
        Colors.grey[700],
        Colors.red,
        position,
      )!.withOpacity(0.7 + audioLevel * 0.3);
      
      paint.color = color;
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            centerY - height / 2,
            barWidth,
            height,
          ),
          const Radius.circular(3),
        ),
        paint,
      );
    }
    
    // Draw frequency range labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    // Low frequency label
    textPainter.text = TextSpan(
      text: '${frequencyRange["low"]!.toStringAsFixed(0)}Hz',
      style: TextStyle(
        color: Colors.grey[600],
        fontSize: 9,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(2, size.height - 12));
    
    // High frequency label
    textPainter.text = TextSpan(
      text: '${frequencyRange["high"]!.toStringAsFixed(0)}Hz',
      style: TextStyle(
        color: Colors.grey[600],
        fontSize: 9,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width - textPainter.width - 2, size.height - 12));
  }
  
  @override
  bool shouldRepaint(FrequencyVisualizerPainter oldDelegate) {
    return oldDelegate.audioLevel != audioLevel;
  }
}

// Legacy waveform painter (kept for reference)
class AudioWaveformPainter extends CustomPainter {
  final double audioLevel;
  
  AudioWaveformPainter(this.audioLevel);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red[600]!.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    
    final centerY = size.height / 2;
    const barWidth = 4.0;
    const spacing = 2.0;
    final totalBarWidth = barWidth + spacing;
    final numberOfBars = (size.width / totalBarWidth).floor();
    
    for (int i = 0; i < numberOfBars; i++) {
      // Create varying heights for visual effect
      final variation = (i % 3) * 0.1;
      final height = (audioLevel + variation) * size.height * 0.8;
      final x = i * totalBarWidth;
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            centerY - height / 2,
            barWidth,
            height,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(AudioWaveformPainter oldDelegate) {
    return oldDelegate.audioLevel != audioLevel;
  }
}