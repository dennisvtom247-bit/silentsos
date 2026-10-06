import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_utils.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  Widget _buildReportCard({
    required String title,
    required String value,
    required Widget visual,
  }) {
    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            const SizedBox(height: 16),
            visual,
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionRow(String label, int count, int total, Color color) {
    final double percent = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
              Text(
                "$count (${(percent * 100).toStringAsFixed(1)}%)",
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: const Color(0xFF2D2D2D),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseUtils.isDemoMode) {
      const totalSos = 45;
      const pinTriggers = 33;
      const shakeTriggers = 12;
      const otherTriggers = 0;

      const activeSos = 2;
      const resolvedSos = 43;
      const failedSos = 0;

      return _buildContent(totalSos, pinTriggers, shakeTriggers, otherTriggers, activeSos, resolvedSos, failedSos);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('sos_events').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.orange));
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        }

        final docs = snapshot.data?.docs ?? [];
        final totalSos = docs.length;

        // SOS Trigger Methods
        final pinTriggers = docs.where((d) => (d.data() as Map<String, dynamic>)['trigger_method'] == 'PIN').length;
        final shakeTriggers = docs.where((d) => (d.data() as Map<String, dynamic>)['trigger_method'] == 'Shake').length;
        final otherTriggers = totalSos - pinTriggers - shakeTriggers;

        // SOS Statuses
        final activeSos = docs.where((d) => (d.data() as Map<String, dynamic>)['sos_status'] == 'Active').length;
        final resolvedSos = docs.where((d) => (d.data() as Map<String, dynamic>)['sos_status'] == 'Resolved').length;
        final failedSos = docs.where((d) => (d.data() as Map<String, dynamic>)['sos_status'] == 'Failed').length;

        return _buildContent(totalSos, pinTriggers, shakeTriggers, otherTriggers, activeSos, resolvedSos, failedSos);
      },
    );
  }

  Widget _buildContent(int totalSos, int pinTriggers, int shakeTriggers, int otherTriggers, int activeSos, int resolvedSos, int failedSos) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildReportCard(
          title: "SOS Trigger Methods Distribution",
          value: "Breakdown of methods used to initiate emergency alarms",
          visual: Column(
            children: [
              _buildDistributionRow("Secret PIN Trigger", pinTriggers, totalSos, Colors.orange),
              _buildDistributionRow("Shake Gesture Trigger", shakeTriggers, totalSos, Colors.blueAccent),
              _buildDistributionRow("Other Methods", otherTriggers, totalSos, Colors.grey),
            ],
          ),
        ),
        _buildReportCard(
          title: "SOS Resolution Statuses",
          value: "Current state of logged emergency incidents",
          visual: Column(
            children: [
              _buildDistributionRow("Active Alerts", activeSos, totalSos, Colors.redAccent),
              _buildDistributionRow("Resolved Incidents", resolvedSos, totalSos, Colors.greenAccent),
              _buildDistributionRow("Failed Operations", failedSos, totalSos, Colors.grey[700]!),
            ],
          ),
        ),
        // Trend Card
        _buildReportCard(
          title: "Emergency Response Efficiency",
          value: "Summary of resolved incidents relative to total alerts",
          visual: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: totalSos > 0 ? resolvedSos / totalSos : 0.0,
                          strokeWidth: 10,
                          backgroundColor: const Color(0xFF2D2D2D),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                        ),
                      ),
                      Text(
                        totalSos > 0 ? "${((resolvedSos / totalSos) * 100).toInt()}%" : "0%",
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Resolution Rate",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
