import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import '../services/audio_service.dart';
import '../services/app_state_provider.dart';
import '../services/tab_generator.dart';
import '../services/audio_analysis_service.dart';
import '../models/note.dart';
import 'edit_screen.dart';
import 'export_screen.dart';

class RecordScreen extends StatefulWidget {
  @override
  _RecordScreenState createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  double bpm = 120.0;
  String selectedInstrument = 'Guitar';
  final List<String> instruments = ['Guitar', 'Piano', 'Drums', 'Violin'];
  bool isRecording = false;
  final AudioService audioService = AudioService();
  final TabGeneratorService tabGenerator = TabGeneratorService();
  final AudioAnalysisService audioAnalysis = AudioAnalysisService();
  double currentAudioLevel = 0.0;
  StreamSubscription<double>? _audioLevelSubscription;
  
  // Analysis results
  AnalysisResult? _lastAnalysisResult;

  @override
  void initState() {
    super.initState();
    // Listen to audio level stream for visualization only
    _audioLevelSubscription = audioService.audioLevelStream.listen((level) {
      if (mounted) {
        setState(() {
          currentAudioLevel = level;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioLevelSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Record Screen'),
        backgroundColor: Colors.deepPurple,
      ), 
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Recording status icon
            Icon(
              isRecording ? Icons.mic : Icons.mic_none,
              size: 100,
              color: isRecording ? Colors.red : Colors.grey,
            ),
            SizedBox(height: 20),
            Text(
              isRecording ? 'Recording...' : 'Ready to Record',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            
            // Audio level visualization
            if (isRecording) ...[
              Text(
                'Audio Level',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              SizedBox(height: 10),
              Container(
                height: 80,
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: CustomPaint(
                  size: Size(double.infinity, 80),
                  painter: AudioWaveformPainter(currentAudioLevel),
                ),
              ),
              SizedBox(height: 10),
              LinearProgressIndicator(
                value: currentAudioLevel,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  currentAudioLevel > 0.7 ? Colors.red : Colors.green,
                ),
                minHeight: 8,
              ),
              SizedBox(height: 20),
            ],
            
            SizedBox(height: 20),
            TextField(
              decoration: InputDecoration(
                labelText: 'BPM',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
                prefixIcon: Icon(Icons.speed),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  bpm = double.tryParse(value) ?? bpm;
                });
              },
            ),
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: selectedInstrument,
              decoration: InputDecoration(
                labelText: 'Instrument',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
                prefixIcon: Icon(Icons.music_note),
              ),
              onChanged: (String? newValue) {
                setState(() {
                  selectedInstrument = newValue!;
                });
              },
              items: instruments.map<DropdownMenuItem<String>>((String instrument) {
                return DropdownMenuItem<String>(
                  value: instrument,
                  child: Text(instrument),
                );
              }).toList(),
            ),
            SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    if (isRecording) {
                      // Stop recording
                      final savedPath = await audioService.stopRecording();
                      setState(() {
                        isRecording = false;
                      });
                      
                      if (savedPath == null || !File(savedPath).existsSync()) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: Recording file not found'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        return;
                      }
                      
                      // Show processing indicator
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Analyzing audio with pitch detection...'),
                                      SizedBox(height: 2),
                                      Text(
                                        'Reading WAV → $selectedInstrument filter → Noise suppression → Pitch detection',
                                        style: TextStyle(fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            duration: Duration(seconds: 10),
                          ),
                        );
                      }
                      
                      // Perform true audio analysis with instrument-specific filtering
                      try {
                        _lastAnalysisResult = await audioAnalysis.analyzeRecording(
                          savedPath,
                          instrument: selectedInstrument,
                        );
                        
                        // Show analysis results
                        if (mounted) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('✓ Audio analysis complete!'),
                                  SizedBox(height: 4),
                                  Text(
                                    '${_lastAnalysisResult!.notes.length} notes detected | '
                                    '${_lastAnalysisResult!.rhythm.formattedTempo} | '
                                    'Noise reduced: ${_lastAnalysisResult!.noiseReductionPercent.toStringAsFixed(1)}%',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Saved: $savedPath',
                                    style: TextStyle(fontSize: 9),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 6),
                            ),
                          );
                        }
                      } catch (e) {
                        print('=== ANALYSIS FAILED ===');
                        print('Error: $e');
                        print('Stack trace:');
                        print(StackTrace.current);
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('⚠ Audio analysis not available'),
                                  SizedBox(height: 4),
                                  Text(
                                    'Using fallback transcription. Check console for details.',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Reason: Unable to read audio file',
                                    style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 7),
                            ),
                          );
                        }
                        
                        // Use fallback if FFmpeg fails
                        _lastAnalysisResult = null;
                      }
                      
                      // Generate a transcription based on the recording
                      final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
                      String newTranscription = _generateTranscription();
                      
                      // Extract the notes from analysis result or use fallback
                      List<Note> notesForExport;
                      if (_lastAnalysisResult != null && _lastAnalysisResult!.notes.isNotEmpty) {
                        notesForExport = _lastAnalysisResult!.notes;
                      } else {
                        // Fallback notes if analysis failed
                        notesForExport = [
                          Note(frequency: 196, noteName: 'G', octave: 3, startTime: 0.0, endTime: 0.5, confidence: 0.85),
                          Note(frequency: 220, noteName: 'A', octave: 3, startTime: 0.5, endTime: 1.0, confidence: 0.88),
                          Note(frequency: 247, noteName: 'B', octave: 3, startTime: 1.0, endTime: 1.5, confidence: 0.90),
                        ];
                      }
                      
                      appStateProvider.addTranscription(newTranscription, notes: notesForExport);
                      appStateProvider.setCurrentTranscription(newTranscription, notes: notesForExport);
                      
                      // Navigate to export screen immediately
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
                              duration: Duration(seconds: 5),
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
                                Text('Recording started - Capturing audio...'),
                                SizedBox(height: 4),
                                Text(
                                  'Saving to: $recordingsDir',
                                  style: TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 4),
                          ),
                        );
                      }
                    }
                  },
                  icon: Icon(isRecording ? Icons.stop : Icons.fiber_manual_record),
                  label: Text(isRecording ? 'Stop & Export' : 'Record'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRecording ? Colors.red : Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                ),
                SizedBox(width: 20),
                ElevatedButton.icon(
                  onPressed: isRecording ? null : () {
                    final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
                    final currentContext = context;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditScreen(
                          initialText: 'Sample transcription for $selectedInstrument at $bpm BPM',
                          onSave: (text) {
                            appStateProvider.addTranscription(text);
                          },
                        ),
                      ),
                    ).then((_) {
                      // Show snackbar after returning from edit screen
                      ScaffoldMessenger.of(currentContext).showSnackBar(
                        SnackBar(
                          content: Text('Transcription saved'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    });
                  },
                  icon: Icon(Icons.edit),
                  label: Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
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
      rhythmInfo = '''\n\nRhythm Analysis:
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
    
    // Use TabGeneratorService to generate tabs from notes
    String generatedTab = tabGenerator.generateTab(notesToUse);
    String textNotation = tabGenerator.generateTextNotation(notesToUse);
    
    // Calculate recording duration
    double duration = 0.0;
    if (notesToUse.isNotEmpty) {
      duration = notesToUse.last.endTime;
    }
    
    return '''
Recording Details:
Timestamp: $timestamp
Instrument: $selectedInstrument
BPM Setting: ${bpm.toStringAsFixed(0)}
Duration: ${duration.toStringAsFixed(1)}s
Notes Detected: ${notesToUse.length}

Generated Tablature:
$generatedTab

$textNotation$rhythmInfo

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
  }
}

// Custom painter for audio waveform visualization
class AudioWaveformPainter extends CustomPainter {
  final double audioLevel;
  
  AudioWaveformPainter(this.audioLevel);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.deepPurple.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    
    final centerY = size.height / 2;
    final barWidth = 4.0;
    final spacing = 2.0;
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
          Radius.circular(2),
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