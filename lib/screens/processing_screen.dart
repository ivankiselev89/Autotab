import 'package:flutter/material.dart';

/// Generic processing screen that shows a live log while a background
/// task runs. Pops itself with the task result when complete.
class ProcessingScreen<T> extends StatefulWidget {
  final String title;
  final String subtitle;
  final Future<T> Function(void Function(String) log) runTask;

  const ProcessingScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.runTask,
  });

  @override
  State<ProcessingScreen<T>> createState() => _ProcessingScreenState<T>();
}

class _ProcessingScreenState<T> extends State<ProcessingScreen<T>> {
  final List<String> _logs = [];
  bool _hasError = false;
  String? _errorMessage;
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();
    // Start the background task after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startTask();
    });
  }

  void _addLog(String message) {
    if (!mounted || _isCancelled) return;
    setState(() {
      _logs.add(message);
    });
  }

  Future<void> _startTask() async {
    try {
      _addLog('Starting...');
      final result = await widget.runTask(_addLog);
      _addLog('Done.');
      if (mounted && !_isCancelled) {
        Navigator.of(context).pop<T>(result);
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _logs.add('Error: $_errorMessage');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.red[600],
        actions: [
          TextButton.icon(
            onPressed: () {
              if (_isCancelled) return;
              _isCancelled = true;
              if (mounted) {
                Navigator.of(context).pop<T>();
              }
            },
            icon: const Icon(Icons.close, size: 18, color: Colors.red),
            label: const Text(
              'Cancel',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.grey[900]!],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[300],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _hasError
                            ? 'Error during export'
                            : 'Processing... you can cancel and continue using the app.',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Log Output',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[300],
                ),
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: _logs.isEmpty
                    ? Center(
                        child: Text(
                          'Waiting for export to start...',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Text(
                              _logs[index],
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            if (_hasError)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop<T>();
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
