import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'emergency_audio_record.dart';
import 'audio_record_service.dart';
import 'audio_service.dart';

class RecordingHistoryScreen extends StatefulWidget {
  const RecordingHistoryScreen({super.key});

  @override
  State<RecordingHistoryScreen> createState() => _RecordingHistoryScreenState();
}

class _RecordingHistoryScreenState extends State<RecordingHistoryScreen> with SingleTickerProviderStateMixin {
  late final AudioPlayer _audioPlayer;
  String? _playingAudioId;
  bool _isPlaying = false;
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();
    _finalizeAndMigrate();
    _audioPlayer = AudioPlayer();
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            _playingAudioId = null;
          }
        });
      }
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  Future<void> _finalizeAndMigrate() async {
    try {
      await AudioService().finalizeActiveRecording();
      await AudioService().migrateOldRecordings();
    } catch (e) {
      debugPrint("Error finalizing/migrating recordings: $e");
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _pulseController?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(EmergencyAudioRecord record) async {
    if (record.status == 'Failed' || record.filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Cannot play failed recording."),
          backgroundColor: Colors.red[800],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (record.status == 'Recording') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Audio is currently recording. Wait for it to finish."),
          backgroundColor: Colors.orange[800],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final file = File(record.filePath);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Audio file not found on device."),
          backgroundColor: Colors.red[800],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      if (_playingAudioId == record.audioId) {
        if (_isPlaying) {
          await _audioPlayer.pause();
        } else {
          await _audioPlayer.play();
        }
      } else {
        await _audioPlayer.stop();
        setState(() {
          _playingAudioId = record.audioId;
        });
        await _audioPlayer.setFilePath(record.filePath);
        await _audioPlayer.play();
      }
    } catch (e) {
      debugPrint("Error playing audio: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Playback error: $e"),
          backgroundColor: Colors.red[800],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteRecord(EmergencyAudioRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Delete Recording", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to permanently delete this audio evidence?", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (_playingAudioId == record.audioId) {
        await _audioPlayer.stop();
        _playingAudioId = null;
        _isPlaying = false;
      }

      if (record.filePath.isNotEmpty) {
        final file = File(record.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      await AudioRecordService().deleteRecord(record.audioId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Recording deleted successfully."),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error deleting recording: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to delete recording: $e"),
            backgroundColor: Colors.red[800],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Saved':
        return Colors.greenAccent[700]!;
      case 'Failed':
        return Colors.redAccent[700]!;
      case 'Recording':
        return Colors.orangeAccent[700]!;
      default:
        return Colors.grey;
    }
  }

  Widget _getStatusIcon(String status) {
    switch (status) {
      case 'Saved':
        return const Icon(Icons.check_circle_outline, color: Colors.green, size: 16);
      case 'Failed':
        return const Icon(Icons.error_outline, color: Colors.redAccent, size: 16);
      case 'Recording':
        return AnimatedBuilder(
          animation: _pulseController!,
          builder: (context, child) {
            return Opacity(
              opacity: _pulseController!.value,
              child: const Icon(Icons.radio_button_checked, color: Colors.orangeAccent, size: 16),
            );
          },
        );
      default:
        return const Icon(Icons.help_outline, color: Colors.grey, size: 16);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: StreamBuilder<List<EmergencyAudioRecord>>(
        stream: AudioRecordService().getRecordsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading history: ${snapshot.error}",
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final records = snapshot.data ?? [];
          if (records.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic_off_outlined, size: 80, color: Colors.grey[800]),
                    const SizedBox(height: 16),
                    const Text(
                      "No Audio Recordings Found",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Emergency audio records will appear here when an SOS triggers.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: records.length,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final record = records[index];
              final isThisPlaying = _playingAudioId == record.audioId && _isPlaying;
              
              return Card(
                color: const Color(0xFF1E1E1E),
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isThisPlaying ? Colors.orange.withValues(alpha: 0.5) : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => _togglePlay(record),
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isThisPlaying 
                                ? Colors.orange[800] 
                                : (record.status == 'Failed' ? Colors.grey[850] : Colors.orange.withValues(alpha: 0.1)),
                          ),
                          child: Icon(
                            isThisPlaying ? Icons.pause : Icons.play_arrow,
                            color: record.status == 'Failed' 
                                ? Colors.grey[600] 
                                : (isThisPlaying ? Colors.white : Colors.orange),
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    record.recordedDate,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(record.status).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _getStatusColor(record.status).withValues(alpha: 0.3), width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _getStatusIcon(record.status),
                                      const SizedBox(width: 4),
                                      Text(
                                        record.status,
                                        style: TextStyle(
                                          color: _getStatusColor(record.status),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Time: ${record.recordedTime} • Duration: ${record.duration}",
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "SOS ID: ${record.sosId}",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 22),
                        onPressed: () => _deleteRecord(record),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
