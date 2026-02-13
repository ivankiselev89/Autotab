import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_service.dart';
import '../services/app_state_provider.dart';
import 'edit_screen.dart';

class RecordScreen extends StatefulWidget {
  @override
  _RecordScreenState createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  double bpm = 120.0;
  String selectedInstrument = 'Guitar';
  final List<String> instruments = ['Guitar', 'Piano', 'Drums', 'Violin'];
  bool isRecording = false;
  final AudioService _audioService = AudioService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Record Screen'),
      ), 
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
            SizedBox(height: 40),
            TextField(
              decoration: InputDecoration(
                labelText: 'BPM',
                border: OutlineInputBorder(),
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
                border: OutlineInputBorder(),
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
                      await _audioService.stopRecording();
                      setState(() {
                        isRecording = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Recording stopped')),
                      );
                    } else {
                      await _audioService.startRecording();
                      setState(() {
                        isRecording = true;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Recording started')),
                      );
                    }
                  },
                  icon: Icon(isRecording ? Icons.stop : Icons.fiber_manual_record),
                  label: Text(isRecording ? 'Stop' : 'Record'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRecording ? Colors.red : Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                ),
                SizedBox(width: 20),
                ElevatedButton.icon(
                  onPressed: isRecording ? null : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditScreen(
                          initialText: 'Sample transcription for $selectedInstrument at $bpm BPM',
                          onSave: (text) {
                            Provider.of<AppStateProvider>(context, listen: false)
                                .addTranscription(text);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Transcription saved')),
                            );
                          },
                        ),
                      ),
                    );
                  },
                  icon: Icon(Icons.edit),
                  label: Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}