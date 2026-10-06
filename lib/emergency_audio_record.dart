class EmergencyAudioRecord {
  final String audioId;
  final String userId;
  final String sosId;
  final String filePath;
  final String recordedDate;
  final String recordedTime;
  final String duration;
  final String status;
  final String createdAt;
  final String downloadUrl;

  EmergencyAudioRecord({
    required this.audioId,
    required this.userId,
    required this.sosId,
    required this.filePath,
    required this.recordedDate,
    required this.recordedTime,
    required this.duration,
    required this.status,
    required this.createdAt,
    this.downloadUrl = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'audio_id': audioId,
      'user_id': userId,
      'sos_id': sosId,
      'file_path': filePath,
      'recorded_date': recordedDate,
      'recorded_time': recordedTime,
      'duration': duration,
      'status': status,
      'created_at': createdAt,
      'download_url': downloadUrl,
    };
  }

  factory EmergencyAudioRecord.fromMap(Map<String, dynamic> map) {
    return EmergencyAudioRecord(
      audioId: map['audio_id'] ?? '',
      userId: map['user_id'] ?? map['userId'] ?? '',
      sosId: map['sos_id'] ?? map['sosId'] ?? '',
      filePath: map['file_path'] ?? map['filePath'] ?? '',
      recordedDate: map['recorded_date'] ?? map['recordedDate'] ?? '',
      recordedTime: map['recorded_time'] ?? map['recordedTime'] ?? '',
      duration: map['duration'] ?? '',
      status: map['status'] ?? 'Unknown',
      createdAt: map['created_at'] ?? '',
      downloadUrl: map['download_url'] ?? '',
    );
  }
}
