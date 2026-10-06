class SecuritySettings {
  final String securityId;
  final String userId;
  final String sosPinHash;
  final String accessPinHash;
  final String updatedAt;

  SecuritySettings({
    required this.securityId,
    required this.userId,
    required this.sosPinHash,
    required this.accessPinHash,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'security_id': securityId,
      'user_id': userId,
      'sos_pin': sosPinHash,
      'access_pin': accessPinHash,
      'updated_at': updatedAt,
    };
  }

  factory SecuritySettings.fromMap(Map<String, dynamic> map) {
    return SecuritySettings(
      securityId: map['security_id'] ?? '',
      userId: map['user_id'] ?? '',
      sosPinHash: map['sos_pin'] ?? '',
      accessPinHash: map['access_pin'] ?? '',
      updatedAt: map['updated_at'] ?? '',
    );
  }
}
