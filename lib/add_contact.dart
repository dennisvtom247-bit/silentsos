import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'contact_service.dart';
import 'recording_history_screen.dart';
import 'security_settings_screen.dart';
import 'auth_screen.dart';
import 'firebase_utils.dart';

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _relationshipController = TextEditingController();
  
  final _contactService = ContactService();
  bool _isSaving = false;
  String _status = 'Active';

  static const _smsChannel = MethodChannel('com.silentsos.silentsos/sms');

  @override
  void initState() {
    super.initState();
    _requestSmsPermissionProactively();
  }

  /// Request SMS permission proactively when the settings screen opens.
  /// This ensures the permission dialog is shown well BEFORE any SOS trigger,
  /// avoiding a race condition during emergencies.
  Future<void> _requestSmsPermissionProactively() async {
    try {
      final bool hasPermission = await _smsChannel.invokeMethod<bool>('hasSmsPermission') ?? false;
      if (!hasPermission) {
        debugPrint('SMS permission not granted yet. Requesting proactively...');
        await _smsChannel.invokeMethod('requestSmsPermission');
      } else {
        debugPrint('SMS permission already granted.');
      }
    } catch (e) {
      debugPrint('Error requesting SMS permission proactively: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final relationship = _relationshipController.text.trim().isEmpty 
          ? 'Friend' 
          : _relationshipController.text.trim();

      await _contactService.addContact(
        name, 
        phone, 
        relationship: relationship, 
        status: _status,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.greenAccent),
                const SizedBox(width: 12),
                Text(
                  "Saved '$name' successfully!",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            backgroundColor: Colors.grey[900],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }

      _nameController.clear();
      _phoneController.clear();
      _relationshipController.clear();
      setState(() {
        _status = 'Active';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving contact: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showEditDialog(EmergencyContact contact) {
    final editFormKey = GlobalKey<FormState>();
    final nameEditController = TextEditingController(text: contact.name);
    final phoneEditController = TextEditingController(text: contact.phone);
    final relationshipEditController = TextEditingController(text: contact.relationship);
    String statusEdit = contact.status;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text("Edit Contact", style: TextStyle(color: Colors.white)),
              content: Form(
                key: editFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameEditController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Contact Name',
                          labelStyle: TextStyle(color: Colors.grey),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneEditController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          labelStyle: TextStyle(color: Colors.grey),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: relationshipEditController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Relationship (e.g. Mom, Friend)',
                          labelStyle: TextStyle(color: Colors.grey),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Status:", style: TextStyle(color: Colors.grey)),
                          DropdownButton<String>(
                            value: statusEdit,
                            dropdownColor: const Color(0xFF1E1E1E),
                            style: const TextStyle(color: Colors.white),
                            items: ["Active", "Inactive"].map((String s) {
                              return DropdownMenuItem<String>(
                                value: s,
                                child: Text(s),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  statusEdit = val;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () async {
                    if (editFormKey.currentState!.validate()) {
                      await _contactService.editContact(
                        contact.id,
                        nameEditController.text.trim(),
                        phoneEditController.text.trim(),
                        relationshipEditController.text.trim().isEmpty ? 'Friend' : relationshipEditController.text.trim(),
                        statusEdit,
                      );
                      if (context.mounted) Navigator.pop(context);
                      _showSnackBar("Contact updated successfully.", Colors.green);
                    }
                  },
                  child: const Text("Save", style: TextStyle(color: Colors.orange)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String message, Color bgColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _deleteContact(EmergencyContact contact) async {
    try {
      await _contactService.deleteContact(contact.id);
      _showSnackBar("Removed ${contact.name}", Colors.grey[850]!);
    } catch (e) {
      _showSnackBar("Error deleting contact: $e", Colors.redAccent);
    }
  }

  void _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Sign Out", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to log out from SilentSOS?", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout", style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (FirebaseUtils.isFirebaseInitialized) {
        try {
          await FirebaseAuth.instance.signOut();
        } catch (e) {
          debugPrint("Sign out failed: $e");
        }
      }
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          title: const Text(
            "SilentSOS Settings",
            style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
          backgroundColor: const Color(0xFF1E1E1E),
          elevation: 0,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.security, color: Colors.white),
              tooltip: "Security Settings",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SecuritySettingsScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.orange),
              tooltip: "Sign Out",
              onPressed: _handleLogout,
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.orange,
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.people_outline), text: "Recipients"),
              Tab(icon: Icon(Icons.mic_none), text: "Recordings"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Emergency Contacts management
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              "Add New Contact",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _buildInputDecoration("Contact Name", Icons.person_outline, hint: "e.g., Jane Doe"),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a contact name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.phone,
                              decoration: _buildInputDecoration("Phone Number", Icons.phone_outlined, hint: "e.g., +1234567890"),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a phone number';
                                }
                                final cleanVal = value.trim();
                                if (cleanVal.length < 5) {
                                  return 'Please enter a valid phone number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _relationshipController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _buildInputDecoration("Relationship", Icons.family_restroom_outlined, hint: "e.g., Mom, Spouse, Friend"),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Contact Status:", style: TextStyle(color: Colors.grey)),
                                DropdownButton<String>(
                                  value: _status,
                                  dropdownColor: const Color(0xFF1E1E1E),
                                  style: const TextStyle(color: Colors.white),
                                  items: ["Active", "Inactive"].map((String s) {
                                    return DropdownMenuItem<String>(
                                      value: s,
                                      child: Text(s),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _status = val;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _isSaving ? null : _saveContact,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange[800],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text(
                                      "Save Contact",
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "SOS Recipients List (Tap to Edit)",
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: StreamBuilder<List<EmergencyContact>>(
                      stream: _contactService.getContactsStream(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Colors.orange));
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              "Error loading contacts: ${snapshot.error}",
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          );
                        }

                        final contacts = snapshot.data ?? [];
                        if (contacts.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.contact_phone_outlined, size: 60, color: Colors.grey[700]),
                                const SizedBox(height: 12),
                                Text(
                                  "No contacts configured.",
                                  style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Add contacts above to receive SOS notifications.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: contacts.length,
                          physics: const BouncingScrollPhysics(),
                          itemBuilder: (context, index) {
                            final contact = contacts[index];
                            final isActive = contact.status.toLowerCase() == 'active';

                            return Card(
                              color: const Color(0xFF1E1E1E),
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.orange.withValues(alpha: 0.1),
                                  child: Icon(Icons.person, color: isActive ? Colors.orange : Colors.grey),
                                ),
                                title: Text(
                                  "${contact.name} (${contact.relationship})",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  "${contact.phone} • ${contact.status}",
                                  style: TextStyle(color: Colors.grey[400]),
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                                  onPressed: () => _deleteContact(contact),
                                ),
                                onTap: () => _showEditDialog(contact),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Tab 2: SOS Audio Recordings list
            const RecordingHistoryScreen(),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData prefix, {String? hint}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[400]),
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[600]),
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
      prefixIcon: Icon(prefix, color: Colors.grey[400]),
    );
  }
}
