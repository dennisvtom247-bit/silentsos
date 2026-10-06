import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'sos_event.dart';
import 'firebase_utils.dart';

class SosEventService {
  static final SosEventService _instance = SosEventService._internal();
  factory SosEventService() => _instance;
  SosEventService._internal();

  final List<SOSEvent> _fallbackEvents = [];
  final StreamController<List<SOSEvent>> _fallbackStreamController = 
      StreamController<List<SOSEvent>>.broadcast();

  bool _isFirebaseInitialized = false;

  Future<File> _getLocalFile() async {
    final uid = FirebaseUtils.currentUid;
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/sos_events_$uid.json');
  }

  Future<void> _loadLocalEvents() async {
    try {
      final file = await _getLocalFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        _fallbackEvents.clear();
        for (var item in jsonList) {
          if (item is Map<String, dynamic>) {
            _fallbackEvents.add(SOSEvent.fromMap(item));
          }
        }
        debugPrint("SosEventService: Loaded ${_fallbackEvents.length} events from local file.");
      }
    } catch (e) {
      debugPrint("SosEventService: Error loading events from local file ($e).");
    }
  }

  Future<void> _saveLocalEvents() async {
    try {
      final file = await _getLocalFile();
      final List<Map<String, dynamic>> jsonList = _fallbackEvents.map((e) => e.toMap()).toList();
      await file.writeAsString(jsonEncode(jsonList));
      debugPrint("SosEventService: Saved ${_fallbackEvents.length} events to local file.");
    } catch (e) {
      debugPrint("SosEventService: Error writing events to local file ($e).");
    }
  }

  Future<void> initialize() async {
    await _loadLocalEvents();
    try {
      if (Firebase.apps.isNotEmpty) {
        _isFirebaseInitialized = true;
      }
    } catch (e) {
      debugPrint("Firebase check failed in SosEventService: $e");
      _isFirebaseInitialized = false;
    }
  }

  Stream<List<SOSEvent>> getEventsStream() {
    if (_isFirebaseInitialized && FirebaseUtils.isFirebaseInitialized) {
      try {
        final uid = FirebaseUtils.currentUid;
        if (uid != 'guest') {
          return FirebaseFirestore.instance
              .collection('sos_events')
              .where('user_id', isEqualTo: uid)
              .snapshots()
              .map((snapshot) {
            final events = snapshot.docs.map((doc) => SOSEvent.fromMap(doc.data())).toList();
            events.sort((a, b) {
              final aDateTime = "${a.date} ${a.time}";
              final bDateTime = "${b.date} ${b.time}";
              return bDateTime.compareTo(aDateTime);
            });
            return events;
          });
        }
      } catch (e) {
        debugPrint("Error fetching Firestore events stream: $e. Falling back to local.");
      }
    }

    _sortEvents();
    Timer.run(() => _fallbackStreamController.add(List.from(_fallbackEvents)));
    return _fallbackStreamController.stream;
  }

  void _sortEvents() {
    _fallbackEvents.sort((a, b) {
      final aDateTime = "${a.date} ${a.time}";
      final bDateTime = "${b.date} ${b.time}";
      return bDateTime.compareTo(aDateTime);
    });
  }

  Future<void> addEvent(SOSEvent event) async {
    if (_isFirebaseInitialized && FirebaseUtils.isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection('sos_events')
            .doc(event.sosId)
            .set(event.toMap());
        debugPrint("SOS Event saved to Firestore: ${event.sosId}");
      } catch (e) {
        debugPrint("Failed to save SOS Event to Firestore: $e. Saving locally.");
      }
    }

    final index = _fallbackEvents.indexWhere((e) => e.sosId == event.sosId);
    if (index >= 0) {
      _fallbackEvents[index] = event;
    } else {
      _fallbackEvents.add(event);
    }
    _sortEvents();
    _fallbackStreamController.add(List.from(_fallbackEvents));
    await _saveLocalEvents();
  }
}
