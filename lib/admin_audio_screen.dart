import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:just_audio/just_audio.dart';
import 'emergency_audio_record.dart';
import 'firebase_utils.dart';

class AdminAudioScreen extends StatefulWidget {
  const AdminAudioScreen({super.key});

  @override
  State<AdminAudioScreen> createState() => _AdminAudioScreenState();
}

class _AdminAudioScreenState extends State<AdminAudioScreen> {
  late final AudioPlayer _audioPlayer;
  String? _playingAudioId;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            _playingAudioId = null;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(EmergencyAudioRecord record) async {
    if (FirebaseUtils.isDemoMode) {
      _showSnackBar("Demo Mode: Audio streaming simulation. (Play buttons are mock-only)", Colors.orange);
      return;
    }
    if (record.downloadUrl.isEmpty) {
      _showSnackBar("Cannot play: Recording evidence is not synced to Firebase Storage.", Colors.red[850]!);
      return;
    }

    try {
      if (_playingAudioId == record.audioId) {
        if (_isPlaying) {
          await _audioPlayer.pause();
        } else {
          await _audioPlayer.play();
        }
      } else {
        await _audioPlayer.stop();
        setState(() {
          _playingAudioId = record.audioId;
        });
        await _audioPlayer.setUrl(record.downloadUrl);
        await _audioPlayer.play();
      }
    } catch (e) {
      debugPrint("Error streaming audio: $e");
      _showSnackBar("Error streaming audio playback: $e", Colors.red[850]!);
    }
  }

  Future<Map<String, String>> _getUserInfo(String uid) async {
    if (FirebaseUtils.isDemoMode) {
      if (uid == 'demo_user_1') {
        return {
          'name': 'Jane Doe',
          'email': 'jane@test.com',
        };
      } else {
        return {
          'name': 'John Smith',
          'email': 'john@test.com',
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
        };
      }
    } catch (_) {}
    return {
      'name': 'Unknown User',
      'email': 'N/A',
    };
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Authorized Audio Evidence",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseUtils.isDemoMode 
                  ? null 
                  : FirebaseFirestore.instance.collection('emergency_audio_records').snapshots(),
              builder: (context, snapshot) {
                final List<EmergencyAudioRecord> records;
                if (FirebaseUtils.isDemoMode) {
                  records = [
                    EmergencyAudioRecord(
                      audioId: 'AUD_123456789',
                      userId: 'demo_user_1',
                      sosId: 'SOS_123456789',
                      filePath: 'SOS_Audio_20260812_144000.m4a',
                      recordedDate: '2026-08-12',
                      recordedTime: '14:40:00',
                      duration: '00:45',
                      status: 'Saved',
                      createdAt: '2026-08-12T14:40:00Z',
                      downloadUrl: 'https://codesandbox.io',
                    )
                  ];
                } else {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.orange));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  
                  // Sort newest first
                  records = docs.map((d) => EmergencyAudioRecord.fromMap(d.data() as Map<String, dynamic>)).toList();
                  records.sort((a, b) {
                    final aDateTime = "${a.recordedDate} ${a.recordedTime}";
                    final bDateTime = "${b.recordedDate} ${b.recordedTime}";
                    return bDateTime.compareTo(aDateTime);
                  });
                }

                if (records.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mic_off_outlined, size: 50, color: Colors.grey[750]),
                        const SizedBox(height: 10),
                        Text("No emergency audio records found", style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: records.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final isThisPlaying = _playingAudioId == record.audioId && _isPlaying;
                    final hasCloudUrl = record.downloadUrl.isNotEmpty;

                    return Card(
                      color: const Color(0xFF1E1E1E),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isThisPlaying ? Colors.orange.withValues(alpha: 0.5) : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: FutureBuilder<Map<String, String>>(
                        future: _getUserInfo(record.userId),
                        builder: (context, userSnapshot) {
                          final name = userSnapshot.data?['name'] ?? 'Loading...';
                          final email = userSnapshot.data?['email'] ?? 'Loading...';

                          return Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () => _togglePlay(record),
                                  borderRadius: BorderRadius.circular(25),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isThisPlaying 
                                          ? Colors.orange[800] 
                                          : (!hasCloudUrl ? Colors.grey[850] : Colors.orange.withValues(alpha: 0.1)),
                                    ),
                                    child: Icon(
                                      isThisPlaying ? Icons.pause : Icons.play_arrow,
                                      color: !hasCloudUrl 
                                          ? Colors.grey[650] 
                                          : (isThisPlaying ? Colors.white : Colors.orange),
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      Text(
                                        email,
                                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        "Date: ${record.recordedDate} • Time: ${record.recordedTime}",
                                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                      ),
                                      Text(
                                        "Duration: ${record.duration} • Status: ${record.status}",
                                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "SOS ID: ${record.sosId}",
                                        style: TextStyle(color: Colors.grey[600], fontSize: 10, fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!hasCloudUrl)
                                  const Tooltip(
                                    message: "Not synced to Cloud",
                                    child: Icon(Icons.cloud_off_outlined, color: Colors.grey, size: 20),
                                  ),
                              ],
                            ),
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
