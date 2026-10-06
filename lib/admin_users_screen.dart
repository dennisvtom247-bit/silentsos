import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_utils.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  String _searchQuery = "";
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleUserStatus(String uid, String currentStatus) async {
    if (FirebaseUtils.isDemoMode) {
      _showSnackBar("Demo Mode: Status updates are simulated only.", Colors.orange);
      return;
    }
    final newStatus = currentStatus == 'active' ? 'deactivated' : 'active';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          newStatus == 'active' ? "Activate User" : "Suspend User",
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          "Are you sure you want to ${newStatus == 'active' ? 'activate' : 'suspend'} this user account?",
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              newStatus == 'active' ? "Activate" : "Suspend",
              style: TextStyle(color: newStatus == 'active' ? Colors.green : Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'status': newStatus,
        });
        _showSnackBar("User status updated successfully.", Colors.green);
      } catch (e) {
        _showSnackBar("Failed to update user status: $e", Colors.red);
      }
    }
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) {
        final regTime = user['createdAt'] as Timestamp?;
        final regDateStr = regTime != null 
            ? DateTime.fromMillisecondsSinceEpoch(regTime.millisecondsSinceEpoch).toLocal().toString().split('.')[0]
            : '2026-08-12 14:40:00';

        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("User Information", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow("UID", user['uid'] ?? 'N/A'),
              _buildDetailRow("Name", user['name'] ?? 'N/A'),
              _buildDetailRow("Email", user['email'] ?? 'N/A'),
              _buildDetailRow("Phone", user['phone'] ?? 'N/A'),
              _buildDetailRow("Role", user['role'] ?? 'user'),
              _buildDetailRow("Status", user['status'] ?? 'active'),
              _buildDetailRow("Registered At", regDateStr),
            ],
          ),
          actions: [
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
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          text: "$label: ",
          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Search Box
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search by Name, Email, or Phone...",
              hintStyle: TextStyle(color: Colors.grey[500]),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
              suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = "";
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.trim().toLowerCase();
              });
            },
          ),
          const SizedBox(height: 16),

          // Users List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseUtils.isDemoMode 
                  ? null 
                  : FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                final List<Map<String, dynamic>> users;
                if (FirebaseUtils.isDemoMode) {
                  users = [
                    {
                      'uid': 'demo_user_1',
                      'name': 'Jane Doe',
                      'email': 'jane@test.com',
                      'phone': '+1 555-0199',
                      'role': 'user',
                      'status': 'active',
                    },
                    {
                      'uid': 'demo_user_2',
                      'name': 'John Smith',
                      'email': 'john@test.com',
                      'phone': '+1 555-0233',
                      'role': 'user',
                      'status': 'deactivated',
                    }
                  ].where((user) {
                    if (_searchQuery.isEmpty) return true;
                    final name = (user['name'] ?? '').toString().toLowerCase();
                    final email = (user['email'] ?? '').toString().toLowerCase();
                    final phone = (user['phone'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery) || 
                           email.contains(_searchQuery) || 
                           phone.contains(_searchQuery);
                  }).toList();
                } else {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.orange));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                  }

                  // Filter out admin users and apply search query
                  final docs = snapshot.data?.docs ?? [];
                  users = docs.map((d) => d.data() as Map<String, dynamic>).where((user) {
                    final role = user['role'] ?? 'user';
                    if (role == 'admin') return false;

                    if (_searchQuery.isEmpty) return true;

                    final name = (user['name'] ?? '').toString().toLowerCase();
                    final email = (user['email'] ?? '').toString().toLowerCase();
                    final phone = (user['phone'] ?? '').toString().toLowerCase();

                    return name.contains(_searchQuery) || 
                           email.contains(_searchQuery) || 
                           phone.contains(_searchQuery);
                  }).toList();
                }

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 50, color: Colors.grey[750]),
                        const SizedBox(height: 10),
                        Text("No users found", style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: users.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final uid = user['uid'] ?? '';
                    final status = user['status'] ?? 'active';
                    final isActive = status == 'active';

                    return Card(
                      color: const Color(0xFF1E1E1E),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                          child: Icon(Icons.person, color: isActive ? Colors.blueAccent : Colors.grey),
                        ),
                        title: Text(
                          user['name'] ?? 'No Name',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          user['email'] ?? 'No Email',
                          style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isActive ? "Active" : "Suspended",
                              style: TextStyle(
                                color: isActive ? Colors.green : Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Switch(
                              value: isActive,
                              activeThumbColor: Colors.green,
                              activeTrackColor: Colors.green.withValues(alpha: 0.2),
                              inactiveThumbColor: Colors.red,
                              inactiveTrackColor: Colors.red.withValues(alpha: 0.2),
                              onChanged: (_) => _toggleUserStatus(uid, status),
                            ),
                          ],
                        ),
                        onTap: () => _showUserDetails(user),
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
