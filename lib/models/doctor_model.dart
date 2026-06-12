class DoctorModel {
  final String? id;
  final String userId;
  final String specialization;
  final String licenseNumber;
  final String hospital;
  final List<String> linkedPatientIds;
  final int yearsOfExperience;

  DoctorModel({
    this.id,
    required this.userId,
    required this.specialization,
    required this.licenseNumber,
    this.hospital = '',
    List<String>? linkedPatientIds,
    this.yearsOfExperience = 0,
  }) : linkedPatientIds = linkedPatientIds ?? [];

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      id: json['_id'] ?? json['id'],
      userId: json['userId'] ?? '',
      specialization: json['specialization'] ?? '',
      licenseNumber: json['licenseNumber'] ?? '',
      hospital: json['hospital'] ?? '',
      linkedPatientIds: json['linkedPatients'] != null
          ? List<String>.from(json['linkedPatients'].map((p) => p.toString()))
          : [],
      yearsOfExperience: json['yearsOfExperience'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'specialization': specialization,
        'licenseNumber': licenseNumber,
        'hospital': hospital,
        'linkedPatients': linkedPatientIds,
        'yearsOfExperience': yearsOfExperience,
      };
}
