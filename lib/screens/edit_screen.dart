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
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.save),
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: controller,
          maxLines: null,
          decoration: InputDecoration(
            hintText: 'Edit your note...',
            border: OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
}