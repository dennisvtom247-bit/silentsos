import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_utils.dart';
import 'emergency_audio_record.dart';
import 'audio_record_service.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentRecordingPath;
  Timer? _autoStopTimer;

  DateTime? _recordingStartTime;
  String? _currentAudioId;
  String? _currentSosId;

  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  /// Get the directory where recordings are stored.
  /// Uses internal application documents directory to ensure reliability and compatibility.
  Future<Directory> _getRecordingDirectory() async {
    final dir = await getApplicationDocumentsDirectory();

    // Create a dedicated sub-folder for SOS recordings
    final recordingsDir = Directory('${dir.path}/SOS_Recordings');
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }
    return recordingsDir;
  }

  /// Migrate any recordings from the old external storage directory to the new internal storage directory.
  Future<void> migrateOldRecordings() async {
    try {
      Directory? oldDir;
      try {
        oldDir = await getExternalStorageDirectory();
      } catch (_) {}

      if (oldDir == null) return;

      final oldRecordingsDir = Directory('${oldDir.path}/SOS_Recordings');
      if (!await oldRecordingsDir.exists()) return;

      final newRecordingsDir = await _getRecordingDirectory();

      final files = oldRecordingsDir.listSync();
      for (final file in files) {
        if (file is File && file.path.endsWith('.m4a') && 
            (file.path.contains('sos_recording_') || file.path.contains('SOS_Audio_'))) {
          final fileName = file.path.split(RegExp(r'[/\\]')).last;
          final newPath = '${newRecordingsDir.path}/$fileName';
          final newFile = File(newPath);
          if (!await newFile.exists()) {
            await file.copy(newPath);
            debugPrint("Migrated recording: $fileName to internal storage.");
          }
          await file.delete();
        }
      }

      // Try to delete the old recordings directory if it's empty
      if (oldRecordingsDir.listSync().isEmpty) {
        await oldRecordingsDir.delete();
      }
    } catch (e) {
      debugPrint("Error migrating recordings: $e");
    }
  }

  /// Check and request microphone permission
  Future<bool> hasPermission() async {
    try {
      return await _audioRecorder.hasPermission();
    } catch (e) {
      debugPrint("Error checking audio permissions: $e");
      return false;
    }
  }

  /// Start local background audio recording
  Future<String?> startRecording({String? sosId}) async {
    try {
      if (_isRecording) {
        debugPrint("Audio recorder is already recording.");
        return _currentRecordingPath;
      }

      _recordingStartTime = DateTime.now();
      _currentSosId = sosId ?? "SOS_${_recordingStartTime!.millisecondsSinceEpoch}";
      _currentAudioId = "AUD_${_recordingStartTime!.millisecondsSinceEpoch}";

      final uid = FirebaseUtils.currentUid;

      final permissionGranted = await hasPermission();
      if (!permissionGranted) {
        debugPrint("Microphone permission denied.");
        // Log the failure to the database
        final now = _recordingStartTime!;
        final failedRecord = EmergencyAudioRecord(
          audioId: _currentAudioId!,
          userId: uid,
          sosId: _currentSosId!,
          filePath: '',
          recordedDate: "${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}",
          recordedTime: "${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:${_twoDigits(now.second)}",
          duration: "00:00",
          status: "Failed",
          createdAt: DateTime.now().toIso8601String(),
          downloadUrl: '',
        );
        await AudioRecordService().addRecord(failedRecord);
        return null;
      }

      final directory = await _getRecordingDirectory();
      
      // Use YYYYMMDD_HHMMSS format automatically
      final now = _recordingStartTime!;
      final dateStr = "${now.year}${_twoDigits(now.month)}${_twoDigits(now.day)}";
      final timeStr = "${_twoDigits(now.hour)}${_twoDigits(now.minute)}${_twoDigits(now.second)}";
      final filePath = '${directory.path}/SOS_Audio_${dateStr}_$timeStr.m4a';

      // Cancel any active auto-stop timer
      _autoStopTimer?.cancel();

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: filePath,
      );

      _isRecording = true;
      _currentRecordingPath = filePath;
      debugPrint("Audio recording started at: $filePath");

      // Save initial record to database with status "Recording"
      final newRecord = EmergencyAudioRecord(
        audioId: _currentAudioId!,
        userId: uid,
        sosId: _currentSosId!,
        filePath: filePath,
        recordedDate: "${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}",
        recordedTime: "${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:${_twoDigits(now.second)}",
        duration: "00:00",
        status: "Recording",
        createdAt: DateTime.now().toIso8601String(),
        downloadUrl: '',
      );
      await AudioRecordService().addRecord(newRecord);

      // Auto-stop recording after 5 minutes to prevent infinite recording
      _autoStopTimer = Timer(const Duration(minutes: 5), () async {
        debugPrint("SilentSOS: Auto-stopping recording after 5 minutes limit.");
        await stopRecording();
      });

      return filePath;
    } catch (e) {
      debugPrint("Failed to start audio recording: $e");
      
      // Log the failure to the database if we set the variables
      if (_currentAudioId != null) {
        final now = _recordingStartTime ?? DateTime.now();
        final uid = FirebaseUtils.currentUid;
        final failedRecord = EmergencyAudioRecord(
          audioId: _currentAudioId!,
          userId: uid,
          sosId: _currentSosId ?? '',
          filePath: '',
          recordedDate: "${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}",
          recordedTime: "${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:${_twoDigits(now.second)}",
          duration: "00:00",
          status: "Failed",
          createdAt: DateTime.now().toIso8601String(),
          downloadUrl: '',
        );
        await AudioRecordService().addRecord(failedRecord);
      }

      _isRecording = false;
      _currentRecordingPath = null;
      _autoStopTimer?.cancel();
      _autoStopTimer = null;
      _recordingStartTime = null;
      _currentAudioId = null;
      _currentSosId = null;
      return null;
    }
  }

  /// Stop audio recording and return the path
  Future<String?> stopRecording() async {
    try {
      _autoStopTimer?.cancel();
      _autoStopTimer = null;

      if (!_isRecording) {
        debugPrint("Audio recorder is not recording.");
        return null;
      }

      final path = await _audioRecorder.stop();
      _isRecording = false;
      _currentRecordingPath = null;

      // Calculate duration
      String durationStr = "00:00";
      if (_recordingStartTime != null) {
        final diff = DateTime.now().difference(_recordingStartTime!);
        final mins = _twoDigits(diff.inMinutes);
        final secs = _twoDigits(diff.inSeconds % 60);
        durationStr = "$mins:$secs";
      }

      // Update database record with final file path, duration, and status "Saved"
      if (_currentAudioId != null && path != null) {
        final now = _recordingStartTime ?? DateTime.now();
        final uid = FirebaseUtils.currentUid;
        final updatedRecord = EmergencyAudioRecord(
          audioId: _currentAudioId!,
          userId: uid,
          sosId: _currentSosId ?? '',
          filePath: path,
          recordedDate: "${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}",
          recordedTime: "${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:${_twoDigits(now.second)}",
          duration: durationStr,
          status: "Saved",
          createdAt: now.toIso8601String(),
          downloadUrl: '',
        );
        await AudioRecordService().updateRecord(updatedRecord);
        
        // Trigger background Firebase Storage upload
        _uploadRecordingToFirebase(path, _currentAudioId!, uid);
      }

      debugPrint("Audio recording stopped and saved: $path");

      _recordingStartTime = null;
      _currentAudioId = null;
      _currentSosId = null;

      return path;
    } catch (e) {
      debugPrint("Failed to stop audio recording: $e");

      if (_currentAudioId != null) {
        final now = _recordingStartTime ?? DateTime.now();
        final uid = FirebaseUtils.currentUid;
        final failedRecord = EmergencyAudioRecord(
          audioId: _currentAudioId!,
          userId: uid,
          sosId: _currentSosId ?? '',
          filePath: _currentRecordingPath ?? '',
          recordedDate: "${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}",
          recordedTime: "${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:${_twoDigits(now.second)}",
          duration: "00:00",
          status: "Failed",
          createdAt: now.toIso8601String(),
          downloadUrl: '',
        );
        await AudioRecordService().updateRecord(failedRecord);
      }

      _isRecording = false;
      _currentRecordingPath = null;
      _recordingStartTime = null;
      _currentAudioId = null;
      _currentSosId = null;
      return null;
    }
  }

  void _uploadRecordingToFirebase(String localPath, String audioId, String uid) async {
    try {
      if (!FirebaseUtils.isFirebaseInitialized) return;
      final file = File(localPath);
      if (!await file.exists()) return;

      final ref = FirebaseStorage.instance
          .ref()
          .child('recordings')
          .child(uid)
          .child('$audioId.m4a');

      debugPrint("FirebaseStorage: Uploading recording $audioId...");
      final uploadTask = await ref.putFile(
        file,
        SettableMetadata(contentType: 'audio/m4a'),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint("FirebaseStorage: Upload complete. Download URL: $downloadUrl");

      // Update record in Firestore with URL
      await FirebaseFirestore.instance
          .collection('emergency_audio_records')
          .doc(audioId)
          .update({
        'download_url': downloadUrl,
      });

      // Update local record
      final records = await AudioRecordService().getRecords();
      final index = records.indexWhere((r) => r.audioId == audioId);
      if (index >= 0) {
        final oldRec = records[index];
        final updatedRec = EmergencyAudioRecord(
          audioId: oldRec.audioId,
          userId: oldRec.userId,
          sosId: oldRec.sosId,
          filePath: oldRec.filePath,
          recordedDate: oldRec.recordedDate,
          recordedTime: oldRec.recordedTime,
          duration: oldRec.duration,
          status: oldRec.status,
          createdAt: oldRec.createdAt,
          downloadUrl: downloadUrl,
        );
        await AudioRecordService().updateRecord(updatedRec);
      }
    } catch (e) {
      debugPrint("FirebaseStorage: Upload failed ($e)");
    }
  }

  /// Stop an in-progress recording so the file is finalized and playable.
  Future<void> finalizeActiveRecording() async {
    if (_isRecording) {
      await stopRecording();
    }
  }

  /// Fetch list of saved SOS recordings (retained for backward compatibility)
  Future<List<FileSystemEntity>> getSavedRecordings() async {
    try {
      final directory = await _getRecordingDirectory();
      if (!await directory.exists()) return [];
      final files = directory.listSync();
      return files
          .where((f) =>
              f.path.endsWith('.m4a') &&
              (f.path.contains('sos_recording_') || f.path.contains('SOS_Audio_')))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path)); // newest first
    } catch (e) {
      debugPrint("Failed to load saved recordings: $e");
      return [];
    }
  }

  /// Dispose recorder resource
  void dispose() {
    _autoStopTimer?.cancel();
    _audioRecorder.dispose();
  }
}
