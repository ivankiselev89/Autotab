import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/audio_service.dart';
import '../services/app_state_provider.dart';
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
  double currentAudioLevel = 0.0;
  StreamSubscription<double>? _audioLevelSubscription;

  @override
  void initState() {
    super.initState();
    // Listen to audio level stream
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
                      await audioService.stopRecording();
                      setState(() {
                        isRecording = false;
                      });
                      
                      // Generate a transcription based on the recording
                      final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
                      String newTranscription = _generateTranscription();
                      appStateProvider.addTranscription(newTranscription);
                      appStateProvider.setCurrentTranscription(newTranscription);
                      
                      // Navigate to export screen immediately
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExportScreen(),
                        ),
                      );
                    } else {
                      // Start recording
                      await audioService.startRecording();
                      setState(() {
                        isRecording = true;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Recording started'),
                          backgroundColor: Colors.green,
                        ),
                      );
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
  
  // Generate a mock transcription based on recording parameters
  String _generateTranscription() {
    final now = DateTime.now();
    final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
                      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    return '''
Recording Details:
Timestamp: $timestamp
Instrument: $selectedInstrument
BPM: ${bpm.toStringAsFixed(0)}

Generated Tablature:
E|--0--2--3--2--0--|
B|--3--3--3--3--3--|
G|--2--2--2--2--2--|
D|--0--0--0--0--0--|
A|-----------------|
E|-----------------|

Notes: This is a sample transcription. The actual audio processing would generate real tablature based on pitch detection and note segmentation.
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