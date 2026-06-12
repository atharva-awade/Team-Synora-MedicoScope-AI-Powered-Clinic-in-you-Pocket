class DetectionResult {
  final String className;
  final double confidence;
  final String description;
  final String model3dPath;
  final String category;
  final double? bboxX;
  final double? bboxY;
  final double? bboxWidth;
  final double? bboxHeight;

  DetectionResult({
    required this.className,
    required this.confidence,
    required this.description,
    required this.model3dPath,
    required this.category,
    this.bboxX,
    this.bboxY,
    this.bboxWidth,
    this.bboxHeight,
  });

  bool get hasBoundingBox =>
      bboxX != null &&
      bboxY != null &&
      bboxWidth != null &&
      bboxHeight != null &&
      bboxWidth! > 0.01 &&
      bboxHeight! > 0.01;

  Map<String, dynamic> toJson() => {
        'className': className,
        'confidence': confidence,
        'description': description,
        'model3dPath': model3dPath,
        'category': category,
        if (bboxX != null) 'bboxX': bboxX,
        if (bboxY != null) 'bboxY': bboxY,
        if (bboxWidth != null) 'bboxWidth': bboxWidth,
        if (bboxHeight != null) 'bboxHeight': bboxHeight,
      };

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      className: json['className'],
      confidence: json['confidence'],
      description: json['description'],
      model3dPath: json['model3dPath'],
      category: json['category'],
      bboxX: (json['bboxX'] as num?)?.toDouble(),
      bboxY: (json['bboxY'] as num?)?.toDouble(),
      bboxWidth: (json['bboxWidth'] as num?)?.toDouble(),
      bboxHeight: (json['bboxHeight'] as num?)?.toDouble(),
    );
  }
}
