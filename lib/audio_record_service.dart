import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'firebase_utils.dart';
import 'emergency_audio_record.dart';

class AudioRecordService {
  static final AudioRecordService _instance = AudioRecordService._internal();
  factory AudioRecordService() => _instance;
  AudioRecordService._internal();

  final List<EmergencyAudioRecord> _fallbackRecords = [];
  final StreamController<List<EmergencyAudioRecord>> _fallbackStreamController = 
      StreamController<List<EmergencyAudioRecord>>.broadcast();

  bool _isFirebaseInitialized = false;

  Future<File> _getLocalFile() async {
    final uid = FirebaseUtils.currentUid;
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/emergency_audio_records_$uid.json');
  }

  Future<void> _loadLocalRecords() async {
    try {
      final file = await _getLocalFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        _fallbackRecords.clear();
        for (var item in jsonList) {
          if (item is Map<String, dynamic>) {
            _fallbackRecords.add(EmergencyAudioRecord.fromMap(item));
          }
        }
        debugPrint("AudioRecordService: Loaded ${_fallbackRecords.length} records from local file.");
      } else {
        _fallbackRecords.clear();
      }
    } catch (e) {
      debugPrint("AudioRecordService: Error loading records from local file ($e).");
    }
  }

  Future<void> _saveLocalRecords() async {
    try {
      final file = await _getLocalFile();
      final List<Map<String, dynamic>> jsonList = _fallbackRecords.map((r) => r.toMap()).toList();
      await file.writeAsString(jsonEncode(jsonList));
      debugPrint("AudioRecordService: Saved ${_fallbackRecords.length} records to local file.");
    } catch (e) {
      debugPrint("AudioRecordService: Error writing records to local file ($e).");
    }
  }

  Future<void> initialize() async {
    await _loadLocalRecords();
    try {
      if (Firebase.apps.isNotEmpty) {
        _isFirebaseInitialized = true;
      }
    } catch (e) {
      debugPrint("Firebase check failed in AudioRecordService: $e");
      _isFirebaseInitialized = false;
    }
  }

  /// Refreshes local cache on user login
  Future<void> handleUserLogin() async {
    await _loadLocalRecords();
    _fallbackStreamController.add(List.from(_fallbackRecords));
  }

  Stream<List<EmergencyAudioRecord>> getRecordsStream() {
    if (_isFirebaseInitialized && FirebaseUtils.isFirebaseInitialized) {
      try {
        final uid = FirebaseUtils.currentUid;
        if (uid != 'guest') {
          return FirebaseFirestore.instance
              .collection('emergency_audio_records')
              .where('user_id', isEqualTo: uid)
              .snapshots()
              .map((snapshot) {
            final records = snapshot.docs.map((doc) {
              return EmergencyAudioRecord.fromMap(doc.data());
            }).toList();
            records.sort((a, b) {
              final aDateTime = "${a.recordedDate} ${a.recordedTime}";
              final bDateTime = "${b.recordedDate} ${b.recordedTime}";
              return bDateTime.compareTo(aDateTime);
            });
            return records;
          });
        }
      } catch (e) {
        debugPrint("Error fetching Firestore records stream: $e. Falling back to local.");
      }
    }
    
    _sortFallbackRecords();
    Timer.run(() => _fallbackStreamController.add(List.from(_fallbackRecords)));
    return _fallbackStreamController.stream;
  }

  Future<List<EmergencyAudioRecord>> getRecords() async {
    if (_isFirebaseInitialized && FirebaseUtils.isFirebaseInitialized) {
      try {
        final uid = FirebaseUtils.currentUid;
        if (uid != 'guest') {
          final query = await FirebaseFirestore.instance
              .collection('emergency_audio_records')
              .where('user_id', isEqualTo: uid)
              .get();
          final records = query.docs.map((doc) => EmergencyAudioRecord.fromMap(doc.data())).toList();
          records.sort((a, b) {
            final aDateTime = "${a.recordedDate} ${a.recordedTime}";
            final bDateTime = "${b.recordedDate} ${b.recordedTime}";
            return bDateTime.compareTo(aDateTime);
          });
          return records;
        }
      } catch (e) {
        debugPrint("Error fetching records from Firestore: $e. Falling back to local.");
      }
    }
    _sortFallbackRecords();
    return List.from(_fallbackRecords);
  }

  void _sortFallbackRecords() {
    _fallbackRecords.sort((a, b) {
      final aDateTime = "${a.recordedDate} ${a.recordedTime}";
      final bDateTime = "${b.recordedDate} ${b.recordedTime}";
      return bDateTime.compareTo(aDateTime);
    });
  }

  Future<void> addRecord(EmergencyAudioRecord record) async {
    if (_isFirebaseInitialized && FirebaseUtils.isFirebaseInitialized) {
      try {
        final uid = FirebaseUtils.currentUid;
        if (uid != 'guest') {
          final data = record.toMap();
          data['createdAt'] = FieldValue.serverTimestamp();
          await FirebaseFirestore.instance
              .collection('emergency_audio_records')
              .doc(record.audioId)
              .set(data);
          debugPrint("Audio record saved to Firestore: ${record.audioId}");
          
          _addOrUpdateLocal(record);
          return;
        }
      } catch (e) {
        debugPrint("Failed to save audio record to Firestore: $e. Saving locally.");
      }
    }

    _addOrUpdateLocal(record);
  }

  Future<void> updateRecord(EmergencyAudioRecord record) async {
    if (_isFirebaseInitialized && FirebaseUtils.isFirebaseInitialized) {
      try {
        final uid = FirebaseUtils.currentUid;
        if (uid != 'guest') {
          final data = record.toMap();
          data['updatedAt'] = FieldValue.serverTimestamp();
          await FirebaseFirestore.instance
              .collection('emergency_audio_records')
              .doc(record.audioId)
              .update(data);
          debugPrint("Audio record updated in Firestore: ${record.audioId}");
          
          _addOrUpdateLocal(record);
          return;
        }
      } catch (e) {
        debugPrint("Failed to update audio record in Firestore: $e. Updating locally.");
      }
    }

    _addOrUpdateLocal(record);
  }

  void _addOrUpdateLocal(EmergencyAudioRecord record) async {
    final index = _fallbackRecords.indexWhere((r) => r.audioId == record.audioId);
    if (index >= 0) {
      _fallbackRecords[index] = record;
    } else {
      _fallbackRecords.add(record);
    }
    _sortFallbackRecords();
    _fallbackStreamController.add(List.from(_fallbackRecords));
    await _saveLocalRecords();
  }

  Future<void> deleteRecord(String audioId) async {
    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection('emergency_audio_records')
            .doc(audioId)
            .delete();
        debugPrint("Audio record deleted from Firestore: $audioId");
      } catch (e) {
        debugPrint("Failed to delete audio record from Firestore: $e. Deleting locally.");
      }
    }

    _fallbackRecords.removeWhere((r) => r.audioId == audioId);
    _fallbackStreamController.add(List.from(_fallbackRecords));
    await _saveLocalRecords();
    debugPrint("Audio record deleted locally: $audioId");
  }
}
