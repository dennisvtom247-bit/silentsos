import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'security_settings.dart';
import 'security_settings_service.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _settingsService = SecuritySettingsService();

  // SOS PIN Form
  final _sosFormKey = GlobalKey<FormState>();
  final _currentSosController = TextEditingController();
  final _newSosController = TextEditingController();
  final _confirmSosController = TextEditingController();
  bool _obscureSosCurrent = true;
  bool _obscureSosNew = true;
  bool _obscureSosConfirm = true;
  bool _isSosSaving = false;

  // Access PIN Form
  final _accessFormKey = GlobalKey<FormState>();
  final _currentAccessController = TextEditingController();
  final _newAccessController = TextEditingController();
  final _confirmAccessController = TextEditingController();
  bool _obscureAccessCurrent = true;
  bool _obscureAccessNew = true;
  bool _obscureAccessConfirm = true;
  bool _isAccessSaving = false;

  @override
  void dispose() {
    _currentSosController.dispose();
    _newSosController.dispose();
    _confirmSosController.dispose();
    _currentAccessController.dispose();
    _newAccessController.dispose();
    _confirmAccessController.dispose();
    super.dispose();
  }

  Future<void> _updateSosPin() async {
    if (!_sosFormKey.currentState!.validate()) return;

    final currentSos = _currentSosController.text.trim();
    final newSos = _newSosController.text.trim();

    // 1. Verify current SOS PIN
    if (!_settingsService.verifySosPin(currentSos)) {
      _showErrorSnackBar("Incorrect current SOS PIN.");
      return;
    }

    // 2. Validate same check
    final newSosHash = _settingsService.hashPin(newSos);
    if (newSosHash == _settingsService.currentSettings.accessPinHash) {
      _showErrorSnackBar("SOS PIN and Access PIN cannot be identical.");
      return;
    }

    setState(() {
      _isSosSaving = true;
    });

    try {
      final updatedSettings = SecuritySettings(
        securityId: _settingsService.currentSettings.securityId,
        userId: _settingsService.currentSettings.userId,
        sosPinHash: newSosHash,
        accessPinHash: _settingsService.currentSettings.accessPinHash,
        updatedAt: DateTime.now().toIso8601String(),
      );

      await _settingsService.updateSettings(updatedSettings);

      _currentSosController.clear();
      _newSosController.clear();
      _confirmSosController.clear();

      _showSuccessSnackBar("SOS PIN changed successfully!");
    } catch (e) {
      _showErrorSnackBar("Error changing SOS PIN: $e");
    } finally {
      setState(() {
        _isSosSaving = false;
      });
    }
  }

  Future<void> _updateAccessPin() async {
    if (!_accessFormKey.currentState!.validate()) return;

    final currentAccess = _currentAccessController.text.trim();
    final newAccess = _newAccessController.text.trim();

    // 1. Verify current Access PIN
    if (!_settingsService.verifyAccessPin(currentAccess)) {
      _showErrorSnackBar("Incorrect current Access PIN.");
      return;
    }

    // 2. Validate same check
    final newAccessHash = _settingsService.hashPin(newAccess);
    if (newAccessHash == _settingsService.currentSettings.sosPinHash) {
      _showErrorSnackBar("Access PIN and SOS PIN cannot be identical.");
      return;
    }

    setState(() {
      _isAccessSaving = true;
    });

    try {
      final updatedSettings = SecuritySettings(
        securityId: _settingsService.currentSettings.securityId,
        userId: _settingsService.currentSettings.userId,
        sosPinHash: _settingsService.currentSettings.sosPinHash,
        accessPinHash: newAccessHash,
        updatedAt: DateTime.now().toIso8601String(),
      );

      await _settingsService.updateSettings(updatedSettings);

      _currentAccessController.clear();
      _newAccessController.clear();
      _confirmAccessController.clear();

      _showSuccessSnackBar("Access PIN changed successfully!");
    } catch (e) {
      _showErrorSnackBar("Error changing Access PIN: $e");
    } finally {
      setState(() {
        _isAccessSaving = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.grey[900],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildPinField({
    required TextEditingController controller,
    required String labelText,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white, letterSpacing: 2.0),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: Colors.grey[400], letterSpacing: 0.0),
        filled: true,
        fillColor: const Color(0xFF262626),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.orange, width: 1.5),
        ),
        prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[400]),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.grey[400],
          ),
          onPressed: onToggleVisibility,
        ),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    String? defaultValidator(String? value, String fieldName) {
      if (value == null || value.trim().isEmpty) {
        return "Please enter $fieldName";
      }
      if (value.trim().length != 4) {
        return "PIN must be exactly 4 digits";
      }
      return null;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          "Security Settings",
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 4,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SOS PIN SECTION CARD
            Card(
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _sosFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.emergency_outlined, color: Colors.orange, size: 24),
                          const SizedBox(width: 8),
                          const Text(
                            "SOS TRIGGER PIN",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "This secret PIN triggers the background emergency sequence from the decoy calculator.",
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      _buildPinField(
                        controller: _currentSosController,
                        labelText: "Current SOS PIN",
                        obscureText: _obscureSosCurrent,
                        onToggleVisibility: () => setState(() => _obscureSosCurrent = !_obscureSosCurrent),
                        validator: (value) => defaultValidator(value, "current SOS PIN"),
                      ),
                      const SizedBox(height: 12),
                      _buildPinField(
                        controller: _newSosController,
                        labelText: "New SOS PIN",
                        obscureText: _obscureSosNew,
                        onToggleVisibility: () => setState(() => _obscureSosNew = !_obscureSosNew),
                        validator: (value) => defaultValidator(value, "new SOS PIN"),
                      ),
                      const SizedBox(height: 12),
                      _buildPinField(
                        controller: _confirmSosController,
                        labelText: "Confirm New SOS PIN",
                        obscureText: _obscureSosConfirm,
                        onToggleVisibility: () => setState(() => _obscureSosConfirm = !_obscureSosConfirm),
                        validator: (value) {
                          final matchErr = defaultValidator(value, "confirmation PIN");
                          if (matchErr != null) return matchErr;
                          if (value != _newSosController.text) {
                            return "New PINs do not match";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isSosSaving ? null : _updateSosPin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isSosSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                "Change SOS PIN",
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ACCESS PIN SECTION CARD
            Card(
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _accessFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.admin_panel_settings_outlined, color: Colors.orange, size: 24),
                          const SizedBox(width: 8),
                          const Text(
                            "ACCESS PIN",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "This PIN unlocks the administrative settings dashboard (emergency contacts & recordings).",
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      _buildPinField(
                        controller: _currentAccessController,
                        labelText: "Current Access PIN",
                        obscureText: _obscureAccessCurrent,
                        onToggleVisibility: () => setState(() => _obscureAccessCurrent = !_obscureAccessCurrent),
                        validator: (value) => defaultValidator(value, "current Access PIN"),
                      ),
                      const SizedBox(height: 12),
                      _buildPinField(
                        controller: _newAccessController,
                        labelText: "New Access PIN",
                        obscureText: _obscureAccessNew,
                        onToggleVisibility: () => setState(() => _obscureAccessNew = !_obscureAccessNew),
                        validator: (value) => defaultValidator(value, "new Access PIN"),
                      ),
                      const SizedBox(height: 12),
                      _buildPinField(
                        controller: _confirmAccessController,
                        labelText: "Confirm New Access PIN",
                        obscureText: _obscureAccessConfirm,
                        onToggleVisibility: () => setState(() => _obscureAccessConfirm = !_obscureAccessConfirm),
                        validator: (value) {
                          final matchErr = defaultValidator(value, "confirmation PIN");
                          if (matchErr != null) return matchErr;
                          if (value != _newAccessController.text) {
                            return "New PINs do not match";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isAccessSaving ? null : _updateAccessPin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isAccessSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                "Change Access PIN",
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
