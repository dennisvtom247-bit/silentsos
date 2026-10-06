import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_utils.dart';

class AdminSosScreen extends StatefulWidget {
  const AdminSosScreen({super.key});

  @override
  State<AdminSosScreen> createState() => _AdminSosScreenState();
}

class _AdminSosScreenState extends State<AdminSosScreen> {
  String _statusFilter = "All";

  void _resolveSosEvent(String sosId, String currentStatus) async {
    if (FirebaseUtils.isDemoMode) {
      _showSnackBar("Demo Mode: Event resolution simulated.", Colors.orange);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Update Status", style: TextStyle(color: Colors.white)),
        content: const Text("Select the new status for this emergency SOS event:", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          if (currentStatus == 'Active')
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Resolve", style: TextStyle(color: Colors.green)),
            ),
          if (currentStatus != 'Failed')
            TextButton(
              onPressed: () {
                Navigator.pop(context, null);
              },
              child: const Text("Mark Failed", style: TextStyle(color: Colors.redAccent)),
            ),
        ],
      ),
    );

    if (confirm != null) {
      final newStatus = confirm == true ? 'Resolved' : 'Failed';
      try {
        await FirebaseFirestore.instance.collection('sos_events').doc(sosId).update({
          'sos_status': newStatus,
        });
        _showSnackBar("SOS status updated to $newStatus.", Colors.green);
      } catch (e) {
        _showSnackBar("Failed to update SOS status: $e", Colors.red);
      }
    }
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

  void _openLocation(double lat, double lng) async {
    final url = "https://maps.google.com/?q=$lat,$lng";
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showSnackBar("Could not open Google Maps link.", Colors.redAccent);
      }
    } catch (e) {
      _showSnackBar("Error launching map: $e", Colors.redAccent);
    }
  }

  Future<Map<String, String>> _getUserInfo(String uid) async {
    if (FirebaseUtils.isDemoMode) {
      if (uid == 'demo_user_1') {
        return {
          'name': 'Jane Doe',
          'email': 'jane@test.com',
          'phone': '+1 555-0199',
        };
      } else {
        return {
          'name': 'John Smith',
          'email': 'john@test.com',
          'phone': '+1 555-0233',
        };
      }
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return {
          'name': data['name'] ?? 'Unknown User',
          'email': data['email'] ?? 'No Email',
          'phone': data['phone'] ?? 'No Phone',
        };
      }
    } catch (_) {}
    return {
      'name': 'Unknown User',
      'email': 'N/A',
      'phone': 'N/A',
    };
  }

  void _showSosDetails(Map<String, dynamic> event) {
    showDialog(
      context: context,
      builder: (context) {
        final double lat = (event['latitude'] as num?)?.toDouble() ?? 0.0;
        final double lng = (event['longitude'] as num?)?.toDouble() ?? 0.0;
        final hasLocation = event['location_status'] == 'Success' && lat != 0.0;

        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("SOS Trigger Details", style: TextStyle(color: Colors.white)),
          content: FutureBuilder<Map<String, String>>(
            future: _getUserInfo(event['user_id'] ?? ''),
            builder: (context, snapshot) {
              final userInfo = snapshot.data ?? {'name': 'Loading...', 'email': 'Loading...', 'phone': 'Loading...'};
              
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow("SOS ID", event['sos_id'] ?? 'N/A'),
                    _buildDetailRow("Trigger Method", event['trigger_method'] ?? 'Unknown'),
                    _buildDetailRow("Date", event['date'] ?? 'N/A'),
                    _buildDetailRow("Time", event['time'] ?? 'N/A'),
                    const Divider(color: Colors.grey),
                    const Text("User Profile Info:", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                    _buildDetailRow("Triggered By", userInfo['name']!),
                    _buildDetailRow("Email", userInfo['email']!),
                    _buildDetailRow("Phone", userInfo['phone']!),
                    const Divider(color: Colors.grey),
                    const Text("Status Checks:", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                    _buildDetailRow("Location", event['location_status'] ?? 'Unknown'),
                    _buildDetailRow("SMS Sending", event['sms_status'] ?? 'Unknown'),
                    _buildDetailRow("Audio Stream", event['audio_status'] ?? 'Unknown'),
                    _buildDetailRow("SOS Incident", event['sos_status'] ?? 'Active'),
                    if (hasLocation) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _openLocation(lat, lng),
                        icon: const Icon(Icons.map, color: Colors.white),
                        label: const Text("View on Google Maps"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        ),
                      ),
                    ]
                  ],
                ),
              );
            },
          ),
          actions: [
            if (event['sos_status'] == 'Active')
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _resolveSosEvent(event['sos_id'], event['sos_status']);
                },
                child: const Text("Resolve", style: TextStyle(color: Colors.green)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close", style: TextStyle(color: Colors.orange)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: RichText(
        text: TextSpan(
          text: "$label: ",
          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
          children: [
            TextSpan(
              text: value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.normal, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Resolved':
        return Colors.green;
      case 'Failed':
        return Colors.redAccent;
      case 'Active':
      default:
        return Colors.orangeAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Filter Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Filter Status:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _statusFilter,
                dropdownColor: const Color(0xFF1E1E1E),
                style: const TextStyle(color: Colors.white),
                items: ["All", "Active", "Resolved", "Failed"].map((String status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _statusFilter = value;
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Events List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseUtils.isDemoMode 
                  ? null 
                  : FirebaseFirestore.instance.collection('sos_events').snapshots(),
              builder: (context, snapshot) {
                var events = <Map<String, dynamic>>[];
                if (FirebaseUtils.isDemoMode) {
                  events = [
                    {
                      'sos_id': 'SOS_123456789',
                      'user_id': 'demo_user_1',
                      'trigger_method': 'PIN',
                      'date': '2026-08-12',
                      'time': '14:40:00',
                      'latitude': 37.7749,
                      'longitude': -122.4194,
                      'location_status': 'Success',
                      'sms_status': 'Sent',
                      'audio_status': 'Recording',
                      'sos_status': 'Active',
                    },
                    {
                      'sos_id': 'SOS_987654321',
                      'user_id': 'demo_user_2',
                      'trigger_method': 'Shake',
                      'date': '2026-08-11',
                      'time': '09:15:00',
                      'latitude': 40.7128,
                      'longitude': -74.0060,
                      'location_status': 'Success',
                      'sms_status': 'Sent',
                      'audio_status': 'Saved',
                      'sos_status': 'Resolved',
                    }
                  ];
                } else {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.orange));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                  }

                  var docs = snapshot.data?.docs ?? [];
                  
                  // Sort newest first
                  events = docs.map((d) => d.data() as Map<String, dynamic>).toList();
                  events.sort((a, b) {
                    final aId = a['sos_id'] ?? '';
                    final bId = b['sos_id'] ?? '';
                    return bId.compareTo(aId);
                  });
                }

                // Apply filter
                if (_statusFilter != "All") {
                  events = events.where((e) => e['sos_status'] == _statusFilter).toList();
                }

                if (events.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 50, color: Colors.grey[750]),
                        const SizedBox(height: 10),
                        Text("No SOS events found", style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: events.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final trigger = event['trigger_method'] ?? 'Unknown';
                    final date = event['date'] ?? '';
                    final time = event['time'] ?? '';
                    final status = event['sos_status'] ?? 'Active';

                    return Card(
                      color: const Color(0xFF1E1E1E),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: FutureBuilder<Map<String, String>>(
                        future: _getUserInfo(event['user_id'] ?? ''),
                        builder: (context, userSnapshot) {
                          final name = userSnapshot.data?['name'] ?? 'Loading...';
                          
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getStatusColor(status).withValues(alpha: 0.1),
                              child: Icon(Icons.warning_amber_rounded, color: _getStatusColor(status)),
                            ),
                            title: Text(
                              "$name • $trigger trigger",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "Date: $date • Time: $time",
                              style: TextStyle(color: Colors.grey[400], fontSize: 13),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _getStatusColor(status).withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(color: _getStatusColor(status), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            onTap: () => _showSosDetails(event),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
