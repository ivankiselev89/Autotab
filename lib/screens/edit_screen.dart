import 'package:flutter/material.dart';

class EditScreen extends StatelessWidget {
  final String initialText;
  final ValueChanged<String> onSave;

  EditScreen({required this.initialText, required this.onSave});

  @override
  Widget build(BuildContext context) {
    TextEditingController controller = TextEditingController(text: initialText);

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Notes'),
        backgroundColor: Colors.deepPurple,
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.save),
            tooltip: 'Save changes',
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit your transcription',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Make any necessary corrections to the transcription below',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter your notes here...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  onSave(controller.text);
                  Navigator.pop(context);
                },
                icon: Icon(Icons.save),
                label: Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}