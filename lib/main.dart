import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shake/shake.dart';
import 'calculator_screen.dart';
import 'contact_service.dart';
import 'sos_service.dart';
import 'audio_record_service.dart';
import 'security_settings_service.dart';
import 'sos_event_service.dart';
import 'auth_screen.dart';
import 'admin_dashboard_screen.dart';
import 'firebase_options.dart';
import 'firebase_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with resilience.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("SilentSOS: Firebase Core initialized.");
  } catch (e) {
    debugPrint("SilentSOS: Firebase initialization skipped or failed ($e). Operating in fallback mode.");
  }

  // Pre-load services
  await ContactService().initialize();
  await AudioRecordService().initialize();
  await SecuritySettingsService().initialize();
  await SosEventService().initialize();

  runApp(const SilentSOSApp());
}

class SilentSOSApp extends StatelessWidget {
  const SilentSOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SilentSOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.orange,
          secondary: Colors.orangeAccent,
          surface: Color(0xFF1E1E1E),
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FirebaseUtils.isFirebaseInitialized) {
      return const MainDecoyController();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF121212),
            body: Center(child: CircularProgressIndicator(color: Colors.orange)),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const AuthScreen();
        }

        // User is logged in, verify role and status from Firestore
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFF121212),
                body: Center(child: CircularProgressIndicator(color: Colors.orange)),
              );
            }

            if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
              // Sign out if profile is missing
              FirebaseAuth.instance.signOut();
              return const AuthScreen();
            }

            final data = userSnapshot.data!.data() as Map<String, dynamic>;
            final String role = data['role'] ?? 'user';
            final String status = data['status'] ?? 'active';

            if (status == 'deactivated') {
              FirebaseAuth.instance.signOut();
              return const AuthScreen();
            }

            if (role == 'admin') {
              return const AdminDashboardScreen();
            } else {
              return const MainDecoyController();
            }
          },
        );
      },
    );
  }
}

/// Controller widget wrapper around Calculator decoy to maintain the global shake listener lifecycle.
class MainDecoyController extends StatefulWidget {
  const MainDecoyController({super.key});

  @override
  State<MainDecoyController> createState() => _MainDecoyControllerState();
}

class _MainDecoyControllerState extends State<MainDecoyController> {
  ShakeDetector? _shakeDetector;

  @override
  void initState() {
    super.initState();
    _initShakeDetection();
  }

  void _initShakeDetection() {
    try {
      _shakeDetector = ShakeDetector.autoStart(
        onPhoneShake: (event) {
          debugPrint("SilentSOS: Strong Shake Detected! Triggering Emergency Sequence. Force: ${event.force}");
          SOSService().triggerSOS(triggerMethod: "Shake");
        },
        shakeThresholdGravity: 2.7, // Gravity force threshold (default is 2.7)
        shakeSlopTimeMS: 1000,
      );
      debugPrint("SilentSOS: Shake detector registered successfully.");
    } catch (e) {
      debugPrint("SilentSOS: Could not initialize shake detector ($e).");
    }
  }

  @override
  void dispose() {
    _shakeDetector?.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Return the decoy calculator screen as the base home view
    return const CalculatorScreen();
  }
}
