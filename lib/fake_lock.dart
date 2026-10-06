import 'package:flutter/material.dart';
import 'sos_service.dart';
import 'add_contact.dart';
import 'security_settings_service.dart';

class FakeLock {
  // Keep standard default constants as static references for safety/documentation
  static const String sosCode = "9999";
  static const String adminUnlockCode = "1234";

  /// Evaluates the entered sequence.
  /// Returns `true` if the input is a shortcut/code (SOS or Admin Unlock),
  /// and `false` if it is a normal calculator expression.
  static Future<bool> evaluateInput(BuildContext context, String input) async {
    final cleanInput = input.trim();
    final settingsService = SecuritySettingsService();

    if (settingsService.verifySosPin(cleanInput)) {
      debugPrint("FakeLock: Match found for SOS Code. Triggering SOS.");
      // Trigger the SOS Service in background (non-blocking)
      SOSService().triggerSOS();
      return true;
    } else if (settingsService.verifyAccessPin(cleanInput)) {
      debugPrint("FakeLock: Match found for Contacts unlock. Opening Admin View.");
      // Navigate to the Emergency Contacts Screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AddContactScreen()),
      );
      return true;
    }
    
    return false;
  }
}
