import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'security_settings.dart';
import 'firebase_utils.dart';

class SecuritySettingsService {
  static final SecuritySettingsService _instance = SecuritySettingsService._internal();
  factory SecuritySettingsService() => _instance;
  SecuritySettingsService._internal();

  SecuritySettings? _currentSettings;
  bool _isFirebaseInitialized = false;

  SecuritySettings get currentSettings {
    if (_currentSettings == null) {
      final uid = FirebaseUtils.currentUid;
      _currentSettings = SecuritySettings(
        securityId: uid,
        userId: uid,
        sosPinHash: hashPin('9999'),
        accessPinHash: hashPin('1234'),
        updatedAt: DateTime.now().toIso8601String(),
      );
    }
    return _currentSettings!;
  }

  String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  Future<File> _getLocalFile() async {
    final uid = FirebaseUtils.currentUid;
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/security_settings_$uid.json');
  }

  Future<void> _loadLocalSettings() async {
    try {
      final file = await _getLocalFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> map = jsonDecode(content);
        _currentSettings = SecuritySettings.fromMap(map);
        debugPrint("SecuritySettingsService: Loaded settings from local file.");
      } else {
        _currentSettings = null; 
      }
    } catch (e) {
      debugPrint("SecuritySettingsService: Error loading settings from local file ($e).");
    }
  }

  Future<void> _saveLocalSettings() async {
    try {
      if (_currentSettings == null) return;
      final file = await _getLocalFile();
      await file.writeAsString(jsonEncode(_currentSettings!.toMap()));
      debugPrint("SecuritySettingsService: Saved settings to local file.");
    } catch (e) {
      debugPrint("SecuritySettingsService: Error writing settings to local file ($e).");
    }
  }

  Future<void> initialize() async {
    await _loadLocalSettings();
    try {
      if (Firebase.apps.isNotEmpty) {
        _isFirebaseInitialized = true;
      }
    } catch (e) {
      debugPrint("Firebase check failed in SecuritySettingsService: $e");
      _isFirebaseInitialized = false;
    }

    if (_isFirebaseInitialized && FirebaseUtils.isFirebaseInitialized) {
      await _loadFromFirestore();
    }
  }

  /// Re-load settings when user logs in
  Future<void> handleUserLogin() async {
    _currentSettings = null;
    await _loadLocalSettings();
    if (_isFirebaseInitialized && FirebaseUtils.isFirebaseInitialized) {
      await _loadFromFirestore();
    }
  }

  Future<void> _loadFromFirestore() async {
    try {
      if (!FirebaseUtils.isFirebaseInitialized) return;
      final uid = FirebaseUtils.currentUid;
      if (uid != 'guest') {
        final doc = await FirebaseFirestore.instance
            .collection('security_settings')
            .doc(uid)
            .get();
        if (doc.exists && doc.data() != null) {
          _currentSettings = SecuritySettings.fromMap(doc.data()!);
          await _saveLocalSettings(); // Keep local in sync
          debugPrint("SecuritySettingsService: Loaded settings from Firestore.");
        }
      }
    } catch (e) {
      debugPrint("SecuritySettingsService: Error loading from Firestore ($e).");
    }
  }

  Future<void> updateSettings(SecuritySettings settings) async {
    _currentSettings = settings;
    await _saveLocalSettings();

    if (_isFirebaseInitialized && FirebaseUtils.isFirebaseInitialized) {
      try {
        final uid = FirebaseUtils.currentUid;
        if (uid != 'guest') {
          final data = settings.toMap();
          data['user_id'] = uid;
          await FirebaseFirestore.instance
              .collection('security_settings')
              .doc(uid)
              .set(data);
          debugPrint("SecuritySettingsService: Updated settings in Firestore.");
        }
      } catch (e) {
        debugPrint("SecuritySettingsService: Failed to update in Firestore ($e).");
      }
    }
  }

  bool verifySosPin(String inputPin) {
    return currentSettings.sosPinHash == hashPin(inputPin);
  }

  bool verifyAccessPin(String inputPin) {
    return currentSettings.accessPinHash == hashPin(inputPin);
  }
}
