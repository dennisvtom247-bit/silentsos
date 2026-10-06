class SOSEvent {
  final String sosId;
  final String userId;
  final String triggerMethod;
  final String date;
  final String time;
  final double latitude;
  final double longitude;
  final String locationStatus;
  final String smsStatus;
  final String audioStatus;
  final String sosStatus; // Active, Resolved, Failed

  SOSEvent({
    required this.sosId,
    required this.userId,
    required this.triggerMethod,
    required this.date,
    required this.time,
    required this.latitude,
    required this.longitude,
    required this.locationStatus,
    required this.smsStatus,
    required this.audioStatus,
    required this.sosStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'sos_id': sosId,
      'user_id': userId,
      'trigger_method': triggerMethod,
      'date': date,
      'time': time,
      'latitude': latitude,
      'longitude': longitude,
      'location_status': locationStatus,
      'sms_status': smsStatus,
      'audio_status': audioStatus,
      'sos_status': sosStatus,
    };
  }

  factory SOSEvent.fromMap(Map<String, dynamic> map) {
    return SOSEvent(
      sosId: map['sos_id'] ?? '',
      userId: map['user_id'] ?? '',
      triggerMethod: map['trigger_method'] ?? 'Unknown',
      date: map['date'] ?? '',
      time: map['time'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      locationStatus: map['location_status'] ?? 'Unknown',
      smsStatus: map['sms_status'] ?? 'Unknown',
      audioStatus: map['audio_status'] ?? 'Unknown',
      sosStatus: map['sos_status'] ?? 'Active',
    );
  }
}
