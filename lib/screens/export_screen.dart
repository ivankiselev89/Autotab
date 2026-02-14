import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/app_state_provider.dart';

class ExportScreen extends StatefulWidget {
  @override
  _ExportScreenState createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final TextEditingController _textController = TextEditingController();
  String? _selectedTranscription;

  @override
  void initState() {
    super.initState();
    // Load the most recent transcription if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      if (appState.currentTranscription.isNotEmpty) {
        setState(() {
          _selectedTranscription = appState.currentTranscription;
          _textController.text = appState.currentTranscription;
        });
      } else if (appState.transcriptions.isNotEmpty) {
        setState(() {
          _selectedTranscription = appState.transcriptions.last;
          _textController.text = appState.transcriptions.last;
        });
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Export Transcriptions'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Consumer<AppStateProvider>(
        builder: (context, appState, child) {
          return Column(
            children: [
              // Text viewer/editor section
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Transcription Preview',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_textController.text.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.copy),
                            tooltip: 'Copy to clipboard',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _textController.text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Copied to clipboard'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: _textController,
                        maxLines: null,
                        expands: true,
                        style: TextStyle(fontFamily: 'monospace', fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'No transcription selected. Record audio or select from list below.',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Export options section
              Container(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Export Options',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: ElevatedButton.icon(
                              onPressed: _textController.text.isEmpty ? null : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Exporting as MIDI...'),
                                    backgroundColor: Colors.blue,
                                  ),
                                );
                              },
                              icon: Icon(Icons.music_note),
                              label: Text('MIDI'),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: ElevatedButton.icon(
                              onPressed: _textController.text.isEmpty ? null : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Exporting as Tabs...'),
                                    backgroundColor: Colors.blue,
                                  ),
                                );
                              },
                              icon: Icon(Icons.library_music),
                              label: Text('Tabs'),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: ElevatedButton.icon(
                              onPressed: _textController.text.isEmpty ? null : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Exporting as PDF...'),
                                    backgroundColor: Colors.blue,
                                  ),
                                );
                              },
                              icon: Icon(Icons.picture_as_pdf),
                              label: Text('PDF'),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              Divider(thickness: 1),
              
              // Saved transcriptions list
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saved Transcriptions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (appState.transcriptions.isNotEmpty)
                      Text(
                        '${appState.transcriptions.length} item(s)',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: appState.transcriptions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.music_off,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No transcriptions yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Start recording to create your first transcription',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: appState.transcriptions.length,
                        itemBuilder: (context, index) {
                          final transcription = appState.transcriptions[index];
                          final isSelected = _selectedTranscription == transcription;
                          
                          return Card(
                            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            elevation: isSelected ? 4 : 1,
                            color: isSelected ? Colors.deepPurple[50] : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isSelected 
                                ? BorderSide(color: Colors.deepPurple, width: 2)
                                : BorderSide.none,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isSelected ? Colors.deepPurple : Colors.grey[400],
                                child: Icon(
                                  Icons.music_note,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                'Transcription ${index + 1}',
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                transcription.split('\n').first,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.deepPurple,
                                    ),
                                  SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      // Clear text if deleting selected item
                                      if (isSelected) {
                                        _textController.clear();
                                        _selectedTranscription = null;
                                      }
                                      appState.removeTranscription(index);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Transcription deleted'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedTranscription = transcription;
                                  _textController.text = transcription;
                                });
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}