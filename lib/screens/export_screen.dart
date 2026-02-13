import 'package:flutter/material.dart';

class ExportScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Export Transcriptions'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Export Options'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Logic to export as MIDI
              },
              child: Text('Export as MIDI'),
            ),
            ElevatedButton(
              onPressed: () {
                // Logic to export as Tabs
              },
              child: Text('Export as Tabs'),
            ),
          ],
        ),
      ),
    );
  }
}