class UserModel {
  final String id;
  final String email;
  final String name;
  final String? phone;
  final String role;
  final String uniqueCode;
  final String? createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    required this.role,
    required this.uniqueCode,
    this.createdAt,
  });

  bool get isPatient => role == 'patient';
  bool get isDoctor => role == 'doctor';
  bool get isAdmin => role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['_id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'],
      role: json['role'] ?? '',
      uniqueCode: json['uniqueCode'] ?? '',
      createdAt: json['createdAt'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'phone': phone,
        'role': role,
        'uniqueCode': uniqueCode,
        'createdAt': createdAt,
      };
}
