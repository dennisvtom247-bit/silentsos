import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'firebase_utils.dart';

class EmergencyContact {
  final String id; // contact_id
  final String userId;
  final String name;
  final String phone;
  final String relationship;
  final String status;

  EmergencyContact({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.relationship,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'contact_id': id,
      'user_id': userId,
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'status': status,
    };
  }

  factory EmergencyContact.fromMap(String id, Map<String, dynamic> map) {
    return EmergencyContact(
      id: id,
      userId: map['user_id'] ?? map['userId'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      relationship: map['relationship'] ?? 'Friend',
      status: map['status'] ?? 'Active',
    );
  }
}

class ContactService {
  static final ContactService _instance = ContactService._internal();
  factory ContactService() => _instance;
  ContactService._internal();

  final List<EmergencyContact> _fallbackContacts = [];
  final StreamController<List<EmergencyContact>> _fallbackStreamController = 
      StreamController<List<EmergencyContact>>.broadcast();

  bool _isFirebaseInitialized = false;

  /// Helper to get the local contacts.json file handle per user
  Future<File> _getLocalFile() async {
    final uid = FirebaseUtils.currentUid;
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/contacts_$uid.json');
  }

  /// Load contacts from the local JSON file
  Future<void> _loadLocalContacts() async {
    try {
      final file = await _getLocalFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        _fallbackContacts.clear();
        for (var item in jsonList) {
          if (item is Map<String, dynamic>) {
            _fallbackContacts.add(EmergencyContact(
              id: item['contact_id'] ?? item['id'] ?? '',
              userId: item['user_id'] ?? item['userId'] ?? '',
              name: item['name'] ?? '',
              phone: item['phone'] ?? '',
              relationship: item['relationship'] ?? 'Friend',
              status: item['status'] ?? 'Active',
            ));
          }
        }
        debugPrint("ContactService: Loaded ${_fallbackContacts.length} contacts from local file.");
      } else {
        _fallbackContacts.clear();
      }
    } catch (e) {
      debugPrint("ContactService: Error loading contacts from local file ($e).");
    }
  }

  /// Save contacts to the local JSON file
  Future<void> _saveLocalContacts() async {
    try {
      final file = await _getLocalFile();
      final List<Map<String, dynamic>> jsonList = _fallbackContacts.map((c) => c.toMap()).toList();
      await file.writeAsString(jsonEncode(jsonList));
      debugPrint("ContactService: Saved ${_fallbackContacts.length} contacts to local file.");
    } catch (e) {
      debugPrint("ContactService: Error writing contacts to local file ($e).");
    }
  }

  /// Initializes authentication checks.
  Future<void> initialize() async {
    // Load local fallback contacts on startup to guarantee persistence
    await _loadLocalContacts();

    try {
      if (Firebase.apps.isNotEmpty) {
        _isFirebaseInitialized = true;
      }
    } catch (e) {
      debugPrint("Firebase initialization check failed: $e");
      _isFirebaseInitialized = false;
    }
  }

  /// Triggered after user login to refresh the local cache
  Future<void> handleUserLogin() async {
    await _loadLocalContacts();
    _fallbackStreamController.add(List.from(_fallbackContacts));
  }

  /// Get contacts stream for UI list updates
  Stream<List<EmergencyContact>> getContactsStream() {
    if (_isFirebaseInitialized) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          return FirebaseFirestore.instance
              .collection('contacts')
              .where('user_id', isEqualTo: user.uid)
              .snapshots()
              .map((snapshot) {
            return snapshot.docs.map((doc) {
              return EmergencyContact.fromMap(doc.id, doc.data());
            }).toList();
          });
        }
      } catch (e) {
        debugPrint("Error fetching Firestore contacts stream: $e. Falling back to memory.");
      }
    }
    
    // Fallback stream logic
    Timer.run(() => _fallbackStreamController.add(List.from(_fallbackContacts)));
    return _fallbackStreamController.stream;
  }

  /// Fetch all emergency contacts (used when triggering SOS)
  Future<List<EmergencyContact>> getContacts() async {
    if (_isFirebaseInitialized) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final query = await FirebaseFirestore.instance
              .collection('contacts')
              .where('user_id', isEqualTo: user.uid)
              .get();
          return query.docs.map((doc) {
            return EmergencyContact.fromMap(doc.id, doc.data());
          }).toList();
        }
      } catch (e) {
        debugPrint("Error fetching contacts from Firestore: $e. Falling back to memory.");
      }
    }
    return List.from(_fallbackContacts);
  }

  /// Adds an emergency contact.
  Future<void> addContact(String name, String phone, {String relationship = 'Friend', String status = 'Active'}) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';
    final newId = DateTime.now().millisecondsSinceEpoch.toString();

    final newContact = EmergencyContact(
      id: newId,
      userId: uid,
      name: name,
      phone: phone,
      relationship: relationship,
      status: status,
    );

    if (_isFirebaseInitialized && user != null) {
      try {
        await FirebaseFirestore.instance.collection('contacts').doc(newId).set({
          'contact_id': newId,
          'user_id': uid,
          'name': name,
          'phone': phone,
          'relationship': relationship,
          'status': status,
          'createdAt': FieldValue.serverTimestamp(),
        });
        debugPrint("Contact saved to Firestore: $name");
        
        _addOrUpdateLocal(newContact);
        return;
      } catch (e) {
        debugPrint("Failed to save contact to Firestore: $e. Saving locally.");
      }
    }

    _addOrUpdateLocal(newContact);
  }

  /// Edits an emergency contact.
  Future<void> editContact(String id, String name, String phone, String relationship, String status) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';

    final updatedContact = EmergencyContact(
      id: id,
      userId: uid,
      name: name,
      phone: phone,
      relationship: relationship,
      status: status,
    );

    if (_isFirebaseInitialized && user != null) {
      try {
        await FirebaseFirestore.instance.collection('contacts').doc(id).update({
          'name': name,
          'phone': phone,
          'relationship': relationship,
          'status': status,
        });
        debugPrint("Contact updated in Firestore: $name");
        
        _addOrUpdateLocal(updatedContact);
        return;
      } catch (e) {
        debugPrint("Failed to update contact in Firestore: $e. Updating locally.");
      }
    }

    _addOrUpdateLocal(updatedContact);
  }

  void _addOrUpdateLocal(EmergencyContact contact) async {
    final index = _fallbackContacts.indexWhere((c) => c.id == contact.id);
    if (index >= 0) {
      _fallbackContacts[index] = contact;
    } else {
      _fallbackContacts.add(contact);
    }
    _fallbackStreamController.add(List.from(_fallbackContacts));
    await _saveLocalContacts();
  }

  /// Deletes an emergency contact.
  Future<void> deleteContact(String id) async {
    if (_isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance.collection('contacts').doc(id).delete();
        debugPrint("Contact deleted from Firestore: $id");
      } catch (e) {
        debugPrint("Failed to delete contact from Firestore: $e. Trying local deletion.");
      }
    }

    _fallbackContacts.removeWhere((contact) => contact.id == id);
    _fallbackStreamController.add(List.from(_fallbackContacts));
    await _saveLocalContacts();
    debugPrint("Contact deleted from memory and local file: $id");
  }
}
