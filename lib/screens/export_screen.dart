import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/app_state_provider.dart';
import '../services/export_service.dart';
import '../models/note.dart';
import 'processing_screen.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  _ExportScreenState createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final TextEditingController _textController = TextEditingController();
  final ExportService _exportService = ExportService();
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
        title: const Text(
          'EXPORT TRANSCRIPTIONS',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.red[600],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.grey[900]!],
          ),
        ),
        child: Consumer<AppStateProvider>(
        builder: (context, appState, child) {
          return Column(
            children: [
              // Text viewer/editor section
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[800]!, width: 1),
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
                            color: Colors.grey[300],
                          ),
                        ),
                        if (_textController.text.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.copy, color: Colors.red[600]),
                            tooltip: 'Copy to clipboard',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _textController.text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Copied to clipboard'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: TextField(
                        controller: _textController,
                        maxLines: null,
                        expands: true,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          color: Colors.grey[300],
                        ),
                        decoration: InputDecoration(
                          hintText: 'No transcription selected. Record audio or select from list below.',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Export options section (no BPM configuration needed)
              Container(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Export Options',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[300],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: ElevatedButton.icon(
                              onPressed: _textController.text.isEmpty
                                  ? null
                                  : () async {
                                      try {
                                        // Get actual notes from app state
                                        final appState = Provider.of<AppStateProvider>(context, listen: false);
                                        final notes = appState.currentNotes.isNotEmpty
                                            ? appState.currentNotes
                                            : appState.getNotesForTranscription(_textController.text);

                                        if (notes.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('No notes available for export. Please record audio first.'),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                          return;
                                        }

                                        final fileName = 'autotab_midi_${DateTime.now().millisecondsSinceEpoch}';

                                        // Choose an appropriate General MIDI program based on
                                        // the current instrument (e.g., Banjo → program 105).
                                        final instrumentName = appState.currentInstrument;
                                        final program = _exportService.resolveMidiProgram(instrumentName);

                                        final filePath = await Navigator.of(context).push<String>(
                                          MaterialPageRoute(
                                            fullscreenDialog: true,
                                            builder: (context) => ProcessingScreen<String>(
                                              title: 'Export MIDI',
                                              subtitle: 'Exporting MIDI file from current transcription.',
                                              runTask: (log) async {
                                                final path = await _exportService.exportAsMidi(
                                                  notes,
                                                  fileName,
                                                  instrument: program,
                                                  log: log,
                                                );
                                                log('MIDI export completed.');
                                                return path;
                                              },
                                            ),
                                          ),
                                        );

                                        if (filePath != null && mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('MIDI exported to: $filePath'),
                                              backgroundColor: Colors.green,
                                              duration: const Duration(seconds: 4),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Error exporting MIDI: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                              icon: const Icon(Icons.music_note),
                              label: const Text('MIDI'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
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
                              onPressed: _textController.text.isEmpty
                                  ? null
                                  : () async {
                                      try {
                                        // Get actual notes from app state
                                        final appState = Provider.of<AppStateProvider>(context, listen: false);
                                        final notes = appState.currentNotes.isNotEmpty
                                            ? appState.currentNotes
                                            : appState.getNotesForTranscription(_textController.text);

                                        if (notes.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('No notes available for export. Please record audio first.'),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                          return;
                                        }

                                        final fileName = 'autotab_tabs_${DateTime.now().millisecondsSinceEpoch}';
                                        // Use the instrument associated with the current transcription,
                                        // defaulting to Guitar if unknown.
                                        final instrumentName = appState.currentInstrument;

                                        final filePath = await Navigator.of(context).push<String>(
                                          MaterialPageRoute(
                                            fullscreenDialog: true,
                                            builder: (context) => ProcessingScreen<String>(
                                              title: 'Export Tabs',
                                              subtitle: 'Exporting tablature and notation.',
                                              runTask: (log) async {
                                                final path = await _exportService.exportAsTab(
                                                  notes,
                                                  fileName,
                                                  instrument: instrumentName,
                                                  log: log,
                                                );
                                                log('Tab export completed.');
                                                return path;
                                              },
                                            ),
                                          ),
                                        );

                                        if (filePath != null && mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Tab exported to: $filePath'),
                                              backgroundColor: Colors.green,
                                              duration: const Duration(seconds: 4),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Error exporting tab: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                              icon: const Icon(Icons.library_music),
                              label: const Text('Tabs'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
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
              
              const Divider(thickness: 1),
              
              // Saved transcriptions list
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saved Transcriptions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[300],
                      ),
                    ),
                    if (appState.transcriptions.isNotEmpty)
                      Text(
                        '${appState.transcriptions.length} item(s)',
                        style: TextStyle(color: Colors.grey[500]),
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
                            const SizedBox(height: 16),
                            Text(
                              'No transcriptions yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start recording to create your first transcription',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
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
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            elevation: isSelected ? 4 : 1,
                            color: isSelected ? Colors.grey[850] : Colors.grey[900],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isSelected 
                                ? BorderSide(color: Colors.red[700]!, width: 2)
                                : BorderSide(color: Colors.grey[800]!),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isSelected ? Colors.red[700] : Colors.grey[700],
                                child: const Icon(
                                  Icons.music_note,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                'Transcription ${index + 1}',
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: Colors.grey[300],
                                ),
                              ),
                              subtitle: Text(
                                transcription.split('\n').first,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.red[600],
                                    ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      // If deleting selected item, select next available transcription
                                      if (isSelected) {
                                        // Remove the transcription first
                                        appState.removeTranscription(index);
                                        
                                        // Select next available transcription
                                        if (appState.transcriptions.isNotEmpty) {
                                          // Calculate new index: use current index if available, otherwise use last index
                                          final newIndex = index < appState.transcriptions.length 
                                              ? index 
                                              : appState.transcriptions.length - 1;
                                          final nextTranscription = appState.transcriptions[newIndex];
                                          setState(() {
                                            _selectedTranscription = nextTranscription;
                                            _textController.text = nextTranscription;
                                          });
                                        } else {
                                          // No transcriptions left, clear selection
                                          setState(() {
                                            _textController.clear();
                                            _selectedTranscription = null;
                                          });
                                        }
                                      } else {
                                        // Not selected, just remove it
                                        appState.removeTranscription(index);
                                      }
                                      
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Transcription deleted'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              onTap: () {
                                // Update current transcription and load its notes
                                final notes = appState.getNotesForTranscription(transcription);
                                final instrument = appState.getInstrumentForTranscription(transcription);
                                appState.setCurrentTranscription(
                                  transcription,
                                  notes: notes,
                                  instrument: instrument,
                                );
                                
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
      ),
    );
  }
}