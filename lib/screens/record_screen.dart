import 'package:flutter/material.dart';

class RecordScreen extends StatefulWidget {
  @override
  _RecordScreenState createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  double bpm = 120.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Record Audio'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Text('BPM: ${bpm.toStringAsFixed(0)}'),
            Slider(
              value: bpm,
              min: 60,
              max: 240,
              divisions: 180,
              label: bpm.toStringAsFixed(0),
              onChanged: (newBPM) {
                setState(() {
                  bpm = newBPM;
                });
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Add audio recording functionality here
              },
              child: Text('Start Recording'),
            ),
          ],
        ),
      ),
    );
  }
}