import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_screen.dart';
import 'admin_users_screen.dart';
import 'admin_sos_screen.dart';
import 'admin_audio_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_profile_screen.dart';
import 'firebase_utils.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;

  final List<String> _titles = [
    "Admin Dashboard",
    "User Management",
    "SOS Event Logs",
    "Audio Evidence Management",
    "System Statistics & Reports",
    "Administrator Profile",
  ];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const AdminSummaryView(),
      const AdminUsersScreen(),
      const AdminSosScreen(),
      const AdminAudioScreen(),
      const AdminReportsScreen(),
      const AdminProfileScreen(),
    ];
  }

  void _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Admin Logout", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to sign out?", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sign Out", style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (FirebaseUtils.isFirebaseInitialized) {
        try {
          await FirebaseAuth.instance.signOut();
        } catch (_) {}
      }
      FirebaseUtils.isDemoMode = false;
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.orange),
            tooltip: "Logout",
            onPressed: _handleLogout,
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E1E1E),
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF262626),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.admin_panel_settings, size: 50, color: Colors.orange),
                    const SizedBox(height: 10),
                    const Text(
                      "SilentSOS Admin",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      FirebaseUtils.isDemoMode ? "Demo Administrator" : (FirebaseAuth.instance.currentUser?.email ?? "Admin Mode"),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(0, Icons.dashboard_outlined, "Dashboard"),
                  _buildDrawerItem(1, Icons.people_outline, "Users"),
                  _buildDrawerItem(2, Icons.emergency_outlined, "SOS Events"),
                  _buildDrawerItem(3, Icons.mic_none, "Audio Evidence"),
                  _buildDrawerItem(4, Icons.bar_chart_outlined, "Reports & Analytics"),
                  _buildDrawerItem(5, Icons.person_outline, "Profile Settings"),
                ],
              ),
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.power_settings_new, color: Colors.redAccent),
              title: const Text("Sign Out", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _handleLogout();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: _pages[_currentIndex],
    );
  }

  Widget _buildDrawerItem(int index, IconData icon, String title) {
    final isSelected = _currentIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.orange : Colors.grey[400]),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.orange : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.orange.withValues(alpha: 0.1),
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
        Navigator.pop(context); // Close drawer
      },
    );
  }
}

class AdminSummaryView extends StatelessWidget {
  const AdminSummaryView({super.key});

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      color: const Color(0xFF1E1E1E),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.grey[400], fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseUtils.isDemoMode) {
      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            "System Overview Dashboard (Local Demo)",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildStatCard(
            title: "Registered Users",
            value: "126",
            icon: Icons.people_outline,
            color: Colors.blueAccent,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            title: "Active SOS Alerts",
            value: "2",
            icon: Icons.notifications_active_outlined,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            title: "Resolved SOS Alerts",
            value: "43",
            icon: Icons.check_circle_outline,
            color: Colors.greenAccent,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            title: "Total SOS Incidents",
            value: "45",
            icon: Icons.emergency_outlined,
            color: Colors.orangeAccent,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            title: "Audio Evidence Records",
            value: "38",
            icon: Icons.mic_outlined,
            color: Colors.purpleAccent,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            title: "Configured Contacts",
            value: "180",
            icon: Icons.contact_phone_outlined,
            color: Colors.tealAccent,
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, usersSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('sos_events').snapshots(),
          builder: (context, sosSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('emergency_audio_records').snapshots(),
              builder: (context, audioSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('contacts').snapshots(),
                  builder: (context, contactsSnapshot) {
                    final usersCount = usersSnapshot.hasData ? usersSnapshot.data!.docs.where((d) => (d.data() as Map<String, dynamic>)['role'] != 'admin').length : 0;
                    final totalSos = sosSnapshot.hasData ? sosSnapshot.data!.docs.length : 0;
                    final activeSos = sosSnapshot.hasData ? sosSnapshot.data!.docs.where((d) => (d.data() as Map<String, dynamic>)['sos_status'] == 'Active').length : 0;
                    final resolvedSos = sosSnapshot.hasData ? sosSnapshot.data!.docs.where((d) => (d.data() as Map<String, dynamic>)['sos_status'] == 'Resolved').length : 0;
                    final audioCount = audioSnapshot.hasData ? audioSnapshot.data!.docs.length : 0;
                    final contactsCount = contactsSnapshot.hasData ? contactsSnapshot.data!.docs.length : 0;

                    return ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        const Text(
                          "System Overview Dashboard",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildStatCard(
                          title: "Registered Users",
                          value: usersCount.toString(),
                          icon: Icons.people_outline,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(height: 12),
                        _buildStatCard(
                          title: "Active SOS Alerts",
                          value: activeSos.toString(),
                          icon: Icons.notifications_active_outlined,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 12),
                        _buildStatCard(
                          title: "Resolved SOS Alerts",
                          value: resolvedSos.toString(),
                          icon: Icons.check_circle_outline,
                          color: Colors.greenAccent,
                        ),
                        const SizedBox(height: 12),
                        _buildStatCard(
                          title: "Total SOS Incidents",
                          value: totalSos.toString(),
                          icon: Icons.emergency_outlined,
                          color: Colors.orangeAccent,
                        ),
                        const SizedBox(height: 12),
                        _buildStatCard(
                          title: "Audio Evidence Records",
                          value: audioCount.toString(),
                          icon: Icons.mic_outlined,
                          color: Colors.purpleAccent,
                        ),
                        const SizedBox(height: 12),
                        _buildStatCard(
                          title: "Configured Contacts",
                          value: contactsCount.toString(),
                          icon: Icons.contact_phone_outlined,
                          color: Colors.tealAccent,
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
