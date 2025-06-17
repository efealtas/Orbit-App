class Planet {
  final String id;
  final String userId;
  final String name;
  final int level;
  final int experience;
  final String evolutionStage;

  Planet({
    required this.id,
    required this.userId,
    required this.name,
    required this.level,
    required this.experience,
    required this.evolutionStage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'level': level,
      'experience': experience,
      'evolutionStage': evolutionStage,
    };
  }

  factory Planet.fromMap(Map<String, dynamic> map) {
    return Planet(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      level: map['level'] as int? ?? 0,
      experience: map['experience'] as int? ?? 0,
      evolutionStage: map['evolutionStage'] as String? ?? '',
    );
  }
} 