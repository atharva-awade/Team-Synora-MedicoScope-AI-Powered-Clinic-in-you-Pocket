class EmergencyContact {
  final String name;
  final String phone;
  final String relationship;

  EmergencyContact({
    this.name = '',
    this.phone = '',
    this.relationship = '',
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      relationship: json['relationship'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'relationship': relationship,
      };
}

class Medication {
  final String name;
  final String dosage;
  final String frequency;

  Medication({
    this.name = '',
    this.dosage = '',
    this.frequency = '',
  });

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      name: json['name'] ?? '',
      dosage: json['dosage'] ?? '',
      frequency: json['frequency'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
      };
}

class PatientModel {
  final String? id;
  final String userId;
  final EmergencyContact emergencyContact;
  final List<Medication> medications;
  final List<String> conditions;
  final String? linkedDoctorId;
  final String dateOfBirth;
  final String bloodGroup;

  PatientModel({
    this.id,
    required this.userId,
    EmergencyContact? emergencyContact,
    List<Medication>? medications,
    List<String>? conditions,
    this.linkedDoctorId,
    this.dateOfBirth = '',
    this.bloodGroup = '',
  })  : emergencyContact = emergencyContact ?? EmergencyContact(),
        medications = medications ?? [],
        conditions = conditions ?? [];

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: json['_id'] ?? json['id'],
      userId: json['userId'] ?? '',
      emergencyContact: json['emergencyContact'] != null
          ? EmergencyContact.fromJson(json['emergencyContact'])
          : EmergencyContact(),
      medications: json['medications'] != null
          ? (json['medications'] as List)
              .map((m) => Medication.fromJson(m))
              .toList()
          : [],
      conditions: json['conditions'] != null
          ? List<String>.from(json['conditions'])
          : [],
      linkedDoctorId: json['linkedDoctorId'],
      dateOfBirth: json['dateOfBirth'] ?? '',
      bloodGroup: json['bloodGroup'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'emergencyContact': emergencyContact.toJson(),
        'medications': medications.map((m) => m.toJson()).toList(),
        'conditions': conditions,
        'linkedDoctorId': linkedDoctorId,
        'dateOfBirth': dateOfBirth,
        'bloodGroup': bloodGroup,
      };
}
