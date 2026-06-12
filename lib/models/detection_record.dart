class DetectionRecord {
  final String? id;
  final String className;
  final double confidence;
  final String category;
  final String description;
  final String? patientId;
  final String? doctorId;
  final String performedBy;
  final String? performedByName;
  final String? performedByRole;
  final DateTime timestamp;

  DetectionRecord({
    this.id,
    required this.className,
    required this.confidence,
    required this.category,
    this.description = '',
    this.patientId,
    this.doctorId,
    required this.performedBy,
    this.performedByName,
    this.performedByRole,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory DetectionRecord.fromJson(Map<String, dynamic> json) {
    return DetectionRecord(
      id: json['_id'] ?? json['id'],
      className: json['className'] ?? '',
      confidence: (json['confidence'] ?? 0).toDouble(),
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      patientId: json['patientId'],
      doctorId: json['doctorId'],
      performedBy: json['performedBy'] is Map
          ? json['performedBy']['_id'] ?? ''
          : json['performedBy'] ?? '',
      performedByName:
          json['performedBy'] is Map ? json['performedBy']['name'] : null,
      performedByRole:
          json['performedBy'] is Map ? json['performedBy']['role'] : null,
      timestamp: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'className': className,
        'confidence': confidence,
        'category': category,
        'description': description,
        'patientId': patientId,
      };
}
