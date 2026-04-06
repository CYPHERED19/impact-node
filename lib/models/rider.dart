class Rider {
  final String id;
  final String name;
  final String phone;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String vehicleType;
  final DateTime createdAt;

  Rider({
    required this.id,
    required this.name,
    required this.phone,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.vehicleType,
    required this.createdAt,
  });

  factory Rider.fromJson(Map<String, dynamic> json) {
    return Rider(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      emergencyContactName: json['emergency_contact_name'] as String,
      emergencyContactPhone: json['emergency_contact_phone'] as String,
      vehicleType: json['vehicle_type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_phone': emergencyContactPhone,
      'vehicle_type': vehicleType,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Rider copyWith({
    String? name,
    String? phone,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? vehicleType,
  }) {
    return Rider(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      vehicleType: vehicleType ?? this.vehicleType,
      createdAt: createdAt,
    );
  }
}
