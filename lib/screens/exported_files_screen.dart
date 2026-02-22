import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/export_service.dart';
import 'edit_screen.dart';

class ExportedFilesScreen extends StatefulWidget {
  const ExportedFilesScreen({super.key});

  @override
  State<ExportedFilesScreen> createState() => _ExportedFilesScreenState();
}

class _ExportedFilesScreenState extends State<ExportedFilesScreen> {
  final ExportService _exportService = ExportService();

  List<_ExportedFile> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    try {
      final exportDir = await _exportService.getExportDirectory();
      final dir = Directory(exportDir);
      if (!await dir.exists()) {
        setState(() {
          _files = [];
          _isLoading = false;
        });
        return;
      }

      final entries = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.mid') || f.path.endsWith('.txt'))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      final files = <_ExportedFile>[];
      for (final file in entries) {
        final stat = await file.stat();
        files.add(_ExportedFile(
          path: file.path,
          name: file.uri.pathSegments.isNotEmpty
              ? file.uri.pathSegments.last
              : file.path.split(Platform.pathSeparator).last,
          isMidi: file.path.toLowerCase().endsWith('.mid'),
          sizeBytes: stat.size,
          modified: stat.modified,
        ));
      }

      setState(() {
        _files = files;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error loading exports'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openTextFile(_ExportedFile file) async {
    try {
      final content = await File(file.path).readAsString();
      if (!mounted) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) => EditScreen(
            initialText: content,
            onSave: (updated) async {
              await File(file.path).writeAsString(updated);
            },
          ),
        ),
      );

      // Reload to update sizes/timestamps
      await _loadFiles();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening file ${file.name}'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  Future<void> _playMidiFile(_ExportedFile file) async {
    // Instead of opening the individual MIDI file, open the folder that
    // contains all exports so the user can manage/play them with any tool.
    try {
      final exportDir = await _exportService.getExportDirectory();

      if (Platform.isWindows) {
        await Process.run('explorer', [exportDir]);
        return;
      }

      if (Platform.isMacOS) {
        await Process.run('open', [exportDir]);
        return;
      }

      if (Platform.isLinux) {
        await Process.run('xdg-open', [exportDir]);
        return;
      }

      // On mobile or other platforms, just show the path.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exports folder: $exportDir'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening exports folder'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'EXPORTED FILES',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.red[600],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadFiles,
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.grey[900]!],
          ),
        ),
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: Colors.red[600]),
              )
            : _files.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_off, size: 80, color: Colors.grey[500]),
                        const SizedBox(height: 16),
                        Text(
                          'No exports found',
                          style: TextStyle(fontSize: 18, color: Colors.grey[400]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Export MIDI or tabs to see them here',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final file = _files[index];

                      return ListTile(
                        leading: Icon(
                          file.isMidi ? Icons.music_note : Icons.description,
                          color: file.isMidi ? Colors.red[400] : Colors.grey[300],
                        ),
                        title: Text(
                          file.name,
                          style: TextStyle(color: Colors.grey[200], fontSize: 14),
                        ),
                        subtitle: Text(
                          '${file.isMidi ? 'MIDI' : 'Text'} • ${_formatSize(file.sizeBytes)} • ${_formatDate(file.modified)}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                        trailing: file.isMidi
                            ? IconButton(
                                icon: Icon(
                                  Icons.folder_open,
                                  color: Colors.red[500],
                                ),
                                onPressed: () => _playMidiFile(file),
                              )
                            : IconButton(
                                icon: Icon(Icons.edit, color: Colors.grey[400]),
                                onPressed: () => _openTextFile(file),
                              ),
                        onTap: () {
                          if (file.isMidi) {
                            _playMidiFile(file);
                          } else {
                            _openTextFile(file);
                          }
                        },
                      );
                    },
                  ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _ExportedFile {
  final String path;
  final String name;
  final bool isMidi;
  final int sizeBytes;
  final DateTime modified;

  _ExportedFile({
    required this.path,
    required this.name,
    required this.isMidi,
    required this.sizeBytes,
    required this.modified,
  });
}
