import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';
import 'admin_dashboard_screen.dart';
import 'contact_service.dart';
import 'audio_record_service.dart';
import 'security_settings_service.dart';
import 'sos_event_service.dart';
import 'firebase_utils.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum AuthMode { userLogin, userRegister, adminLogin, forgotPassword }

class _AuthScreenState extends State<AuthScreen> {
  AuthMode _authMode = AuthMode.userLogin;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _switchMode(AuthMode mode) {
    setState(() {
      _authMode = mode;
      _formKey.currentState?.reset();
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      if (_authMode == AuthMode.userLogin) {
        // 1. Log in normal user
        final credentials = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        // 2. Fetch User Doc
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(credentials.user!.uid)
            .get();

        if (!userDoc.exists) {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'User profile record not found in system database.',
          );
        }

        final data = userDoc.data()!;
        final status = data['status'] ?? 'active';
        
        if (status == 'deactivated') {
          await FirebaseAuth.instance.signOut();
          throw FirebaseAuthException(
            code: 'user-disabled',
            message: 'Your account has been deactivated. Please contact support.',
          );
        }

        // Initialize Services for User
        await ContactService().handleUserLogin();
        await AudioRecordService().handleUserLogin();
        await SecuritySettingsService().handleUserLogin();
        await SosEventService().initialize(); // Refresh logs

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainDecoyController()),
          );
        }

      } else if (_authMode == AuthMode.userRegister) {
        // 1. Create User
        final credentials = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final uid = credentials.user!.uid;
        final name = _nameController.text.trim();
        final phone = _phoneController.text.trim();

        // Determine role: Academic testing fallback
        final String role = (email.endsWith('@admin.com') || email.endsWith('@silentsos.admin')) 
            ? 'admin' 
            : 'user';

        // 2. Save User Document
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'uid': uid,
          'name': name,
          'email': email,
          'phone': phone,
          'role': role,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });

        _showSnackBar("Registration successful! Please login.", Colors.green);
        _switchMode(AuthMode.userLogin);

      } else if (_authMode == AuthMode.adminLogin) {
        // 1. Log in admin
        final credentials = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // 2. Verify admin role
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(credentials.user!.uid)
            .get();

        if (!userDoc.exists || userDoc.data()?['role'] != 'admin') {
          await FirebaseAuth.instance.signOut();
          throw FirebaseAuthException(
            code: 'access-denied',
            message: 'Access Denied: You are not authorized as an administrator.',
          );
        }

        // Initialize Services for Admin
        await ContactService().handleUserLogin();
        await AudioRecordService().handleUserLogin();
        await SecuritySettingsService().handleUserLogin();
        await SosEventService().initialize();

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
          );
        }

      } else if (_authMode == AuthMode.forgotPassword) {
        // Send reset link
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        _showSnackBar("Password reset email sent. Please check your inbox.", Colors.orange);
        _switchMode(AuthMode.userLogin);
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? "An authentication error occurred.", Colors.red[850]!);
    } catch (e) {
      _showSnackBar("An unexpected error occurred: $e", Colors.red[850]!);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color bgColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = _authMode == AuthMode.adminLogin;
    final bool isForgot = _authMode == AuthMode.forgotPassword;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Brand Logo/Header
                  const Icon(Icons.shield_outlined, color: Colors.orange, size: 70),
                  const SizedBox(height: 12),
                  Text(
                    isAdmin ? "SILENTSOS ADMIN" : "SILENTSOS PORTAL",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isForgot 
                        ? "Enter your email to reset password" 
                        : (isAdmin ? "Authorized Administrator Login" : "Personal Safety Dashboard"),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                  const SizedBox(height: 32),

                  // Name Field (Only on Register)
                  if (_authMode == AuthMode.userRegister) ...[
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration("Full Name", Icons.person),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return "Please enter your name";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email Field (All Modes)
                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                    decoration: _buildInputDecoration("Email Address", Icons.email),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return "Please enter your email";
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                        return "Please enter a valid email address";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Phone Field (Only on Register)
                  if (_authMode == AuthMode.userRegister) ...[
                    TextFormField(
                      controller: _phoneController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.phone,
                      decoration: _buildInputDecoration("Phone Number", Icons.phone),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return "Please enter your phone number";
                        if (value.trim().length < 7) return "Please enter a valid phone number";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Password Field (Only on Login/Register)
                  if (!isForgot) ...[
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration(
                        "Password",
                        Icons.lock,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey[400],
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return "Please enter your password";
                        if (value.length < 6) return "Password must be at least 6 characters";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Confirm Password Field (Only on Register)
                  if (_authMode == AuthMode.userRegister) ...[
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration(
                        "Confirm Password",
                        Icons.lock,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey[400],
                          ),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return "Please confirm your password";
                        if (value != _passwordController.text) return "Passwords do not match";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Forgot Password Link (Only on User Login)
                  if (_authMode == AuthMode.userLogin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _switchMode(AuthMode.forgotPassword),
                        child: const Text("Forgot Password?", style: TextStyle(color: Colors.orange)),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 4,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            isForgot 
                                ? "Reset Password" 
                                : (_authMode == AuthMode.userRegister ? "Register Account" : "Login Portal"),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 24),

                  // Bottom Mode Switches
                  if (_authMode == AuthMode.userLogin) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("New user?", style: TextStyle(color: Colors.grey[400])),
                        TextButton(
                          onPressed: () => _switchMode(AuthMode.userRegister),
                          child: const Text("Create Account", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => _switchMode(AuthMode.adminLogin),
                      child: const Text("Login as Administrator", style: TextStyle(color: Colors.grey, fontSize: 13, decoration: TextDecoration.underline)),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        FirebaseUtils.isDemoMode = true;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
                        );
                      },
                      child: const Text("Demo Admin Portal (No Firebase Required)", style: TextStyle(color: Colors.orange, fontSize: 13, decoration: TextDecoration.underline, fontWeight: FontWeight.bold)),
                    ),
                  ],

                  if (_authMode == AuthMode.userRegister || _authMode == AuthMode.adminLogin || _authMode == AuthMode.forgotPassword)
                    TextButton(
                      onPressed: () => _switchMode(AuthMode.userLogin),
                      child: const Text("Back to User Login", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String labelText, IconData prefixIcon, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: Colors.grey[400]),
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.orange, width: 1.5),
      ),
      prefixIcon: Icon(prefixIcon, color: Colors.grey[400]),
      suffixIcon: suffixIcon,
    );
  }
}
