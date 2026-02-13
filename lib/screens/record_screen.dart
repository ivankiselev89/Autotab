import 'package:flutter/material.dart';

class RecordScreen extends StatefulWidget {
  @override
  _RecordScreenState createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  double bpm = 120.0;
  String selectedInstrument = 'Guitar';
  final List<String> instruments = ['Guitar', 'Piano', 'Drums', 'Violin'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Record Screen')), 
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Recording UI', style: TextStyle(fontSize: 24)),
            SizedBox(height: 20),
            TextField(
              decoration: InputDecoration(
                labelText: 'BPM',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                bpm = double.tryParse(value) ?? bpm;
              },
            ),
            SizedBox(height: 20),
            DropdownButton<String>(
              value: selectedInstrument,
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
          ],
        ),
      ),
    );
  }
}