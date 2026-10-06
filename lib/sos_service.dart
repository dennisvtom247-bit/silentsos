import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'contact_service.dart';
import 'audio_service.dart';
import 'sos_event.dart';
import 'sos_event_service.dart';
import 'firebase_utils.dart';

class SOSService {
  static final SOSService _instance = SOSService._internal();
  factory SOSService() => _instance;
  SOSService._internal();

  static const MethodChannel _smsChannel =
      MethodChannel('com.silentsos.silentsos/sms');

  bool _isTriggering = false;
  bool get isTriggering => _isTriggering;

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  /// Main SOS flow trigger — sends SMS immediately, records audio in background.
  Future<void> triggerSOS({String triggerMethod = "PIN"}) async {
    if (_isTriggering) {
      debugPrint("SOS is already being triggered.");
      return;
    }

    _isTriggering = true;
    debugPrint("🚨 SOS TRIGGERED! Starting sequence with method: $triggerMethod");

    final String uid = FirebaseUtils.currentUid;
    final String sosId = "SOS_${DateTime.now().millisecondsSinceEpoch}";

    final now = DateTime.now();
    final dateStr = "${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}";
    final timeStr = "${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:${_twoDigits(now.second)}";

    // Create and save initial SOS Event record
    final sosEvent = SOSEvent(
      sosId: sosId,
      userId: uid,
      triggerMethod: triggerMethod,
      date: dateStr,
      time: timeStr,
      latitude: 0.0,
      longitude: 0.0,
      locationStatus: "Retrieving",
      smsStatus: "Sending",
      audioStatus: "Recording",
      sosStatus: "Active",
    );
    await SosEventService().addEvent(sosEvent);

    // 1. Start background audio recording
    String audioStatus = "Failed";
    final audioService = AudioService();
    try {
      final recordingPath = await audioService.startRecording(sosId: sosId);
      if (recordingPath != null) {
        debugPrint("🎤 Background recording started: $recordingPath");
        audioStatus = "Recording";
      }
    } catch (e) {
      debugPrint("❌ Failed to start background recording: $e");
      audioStatus = "Failed";
    }

    // Update SOS event with audio state
    final eventAfterAudio = SOSEvent(
      sosId: sosId,
      userId: uid,
      triggerMethod: triggerMethod,
      date: dateStr,
      time: timeStr,
      latitude: sosEvent.latitude,
      longitude: sosEvent.longitude,
      locationStatus: sosEvent.locationStatus,
      smsStatus: sosEvent.smsStatus,
      audioStatus: audioStatus,
      sosStatus: "Active",
    );
    await SosEventService().addEvent(eventAfterAudio);

    // 2. Fetch GPS location
    String locationLink = "";
    double latitude = 0.0;
    double longitude = 0.0;
    String locationStatus = "Failed";

    try {
      debugPrint("========== LOCATION DEBUG ==========");

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint("Location service enabled: $serviceEnabled");

      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint("Current permission: $permission");

      if (permission == LocationPermission.denied) {
        debugPrint("Requesting location permission...");
        permission = await Geolocator.requestPermission();
        debugPrint("Permission after request: $permission");
      }

      Position? position;

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        try {
          debugPrint("Getting current location...");
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 5),
            ),
          );
        } catch (e) {
          debugPrint("getCurrentPosition failed or timed out: $e. Trying fallback (getLastKnownPosition)...");
        }
      }

      if (position == null) {
        try {
          position = await Geolocator.getLastKnownPosition();
        } catch (e) {
          debugPrint("Failed to get last known position: $e");
        }
      }

      if (position != null) {
        latitude = position.latitude;
        longitude = position.longitude;
        locationStatus = "Success";
        locationLink = "https://maps.google.com/?q=${position.latitude},${position.longitude}";
        debugPrint("Generated link: $locationLink");
      } else {
        throw Exception("Could not retrieve current or last known position.");
      }

    } catch (e) {
      debugPrint("========== GPS ERROR ==========");
      debugPrint(e.toString());
      locationStatus = "Failed";
      locationLink = "[Location unavailable]";
    }

    // Update SOS event with location state
    final eventAfterLocation = SOSEvent(
      sosId: sosId,
      userId: uid,
      triggerMethod: triggerMethod,
      date: dateStr,
      time: timeStr,
      latitude: latitude,
      longitude: longitude,
      locationStatus: locationStatus,
      smsStatus: eventAfterAudio.smsStatus,
      audioStatus: eventAfterAudio.audioStatus,
      sosStatus: "Active",
    );
    await SosEventService().addEvent(eventAfterLocation);

    // 3. Fetch emergency contacts
    List<EmergencyContact> contacts = [];
    try {
      final allContacts = await ContactService().getContacts();
      // Include all contacts except those explicitly set to 'inactive'
      contacts = allContacts.where((c) => c.status.trim().toLowerCase() != 'inactive').toList();
      debugPrint("Loaded ${contacts.length} emergency contact(s) out of ${allContacts.length} total.");
    } catch (e) {
      debugPrint("Error fetching contacts: $e");
    }

    // 4. Build SMS
    final StringBuffer msg = StringBuffer();
    msg.write("EMERGENCY! I need help. I am in danger.");
    if (locationLink.isNotEmpty && !locationLink.startsWith("[")) {
      msg.write(" Live location: $locationLink");
    }
    msg.write(" - Sent via SilentSOS");
    final String messageText = msg.toString();

    // 5. Send SMS silently in background (no app opens, no user action needed)
    String smsStatus = "Failed";
    try {
      if (contacts.isEmpty) {
        debugPrint("No emergency contacts found. Skipping SMS.");
        smsStatus = "Failed";
      } else {
        smsStatus = await _sendSilentSMS(contacts, messageText);
      }
    } catch (e) {
      debugPrint("SMS sending failed: $e");
      smsStatus = "Failed";
    }

    // Final update to SOS event status
    final finalEvent = SOSEvent(
      sosId: sosId,
      userId: uid,
      triggerMethod: triggerMethod,
      date: dateStr,
      time: timeStr,
      latitude: latitude,
      longitude: longitude,
      locationStatus: locationStatus,
      smsStatus: smsStatus,
      audioStatus: eventAfterLocation.audioStatus,
      sosStatus: (smsStatus == "Failed" && locationStatus == "Failed") ? "Failed" : "Active",
    );
    await SosEventService().addEvent(finalEvent);

    _isTriggering = false;
  }

  /// Sends SMS silently in the background using Android native SmsManager via MethodChannel.
  /// Falls back to opening the SMS app if permission is denied or background send fails.
  Future<String> _sendSilentSMS(List<EmergencyContact> contacts, String message) async {
    // Check permission status first (non-blocking check only)
    bool hasPermission = false;
    try {
      hasPermission = await _smsChannel.invokeMethod<bool>('hasSmsPermission') ?? false;
      debugPrint('SMS permission status: $hasPermission');
    } catch (e) {
      debugPrint('Permission check error: $e');
    }

    // If no permission, skip straight to fallback — don't request during emergency
    // (requesting is non-blocking and creates a race condition)
    if (!hasPermission) {
      debugPrint('SMS permission not granted. Skipping native SMS, going to fallback launcher...');
      return await _fallbackLaunchSMS(contacts, message);
    }

    int sentCount = 0;
    for (final contact in contacts) {
      final cleanPhone = contact.phone.replaceAll(RegExp(r'[^0-9+]'), '');
      if (cleanPhone.isEmpty) {
        debugPrint('WARNING: Contact ${contact.name} has invalid phone number: ${contact.phone}');
        continue;
      }
      
      try {
        debugPrint('Attempting silent SMS to ${contact.name} ($cleanPhone)...');
        final result = await _smsChannel.invokeMethod<String>('sendSms', {
          'phone': cleanPhone,
          'message': message,
        });
        if (result == 'sent') {
          sentCount++;
          debugPrint('SUCCESS: Silent SMS sent to ${contact.name} ($cleanPhone)');
        } else {
          debugPrint('WARNING: Silent SMS returned non-sent result for ${contact.name}: $result');
        }
      } on PlatformException catch (e) {
        debugPrint('ERROR: PlatformException sending SMS to ${contact.name}: [${e.code}] ${e.message}');
      } catch (e) {
        debugPrint('ERROR: Unexpected error sending SMS to ${contact.name}: $e');
      }
    }

    if (sentCount > 0) {
      return 'Sent';
    } else {
      debugPrint('WARNING: Background silent SMS failed for all contacts. Triggering fallback SMS launcher...');
      return await _fallbackLaunchSMS(contacts, message);
    }
  }

  /// Fallback: Opens the SMS app with contacts and message pre-filled.
  Future<String> _fallbackLaunchSMS(List<EmergencyContact> contacts, String body) async {
    try {
      final String separator = Platform.isAndroid ? ';' : ',';
      final String phones = contacts.map((c) => c.phone.trim()).join(separator);
      final encodedBody = Uri.encodeComponent(body);
      final String url = 'sms:$phones?body=$encodedBody';
      final Uri smsUri = Uri.parse(url);
      debugPrint('Fallback SMS URI: $url');
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
        debugPrint('Fallback SMS app launched successfully');
        return 'Sent';
      } else {
        debugPrint('Cannot launch SMS URI: $url');
      }
    } catch (e) {
      debugPrint('Fallback SMS launch failed: $e');
    }
    return 'Failed';
  }
}