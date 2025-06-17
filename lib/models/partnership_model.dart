class Partnership {
  final String id;
  final String user1Id;
  final String user2Id;
  final DateTime startDate;
  final DateTime endDate;
  final int streak;

  Partnership({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.startDate,
    required this.endDate,
    this.streak = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user1Id': user1Id,
      'user2Id': user2Id,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'streak': streak,
    };
  }

  factory Partnership.fromMap(Map<String, dynamic> map) {
    return Partnership(
      id: map['id'] as String? ?? '',
      user1Id: map['user1Id'] as String? ?? '',
      user2Id: map['user2Id'] as String? ?? '',
      startDate: map['startDate'] != null
          ? DateTime.parse(map['startDate'] as String)
          : DateTime.now(),
      endDate: map['endDate'] != null
          ? DateTime.parse(map['endDate'] as String)
          : DateTime.now(),
      streak: map['streak'] as int? ?? 0,
    );
  }

  Partnership copyWith({
    String? id,
    String? user1Id,
    String? user2Id,
    DateTime? startDate,
    DateTime? endDate,
    int? streak,
  }) {
    return Partnership(
      id: id ?? this.id,
      user1Id: user1Id ?? this.user1Id,
      user2Id: user2Id ?? this.user2Id,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      streak: streak ?? this.streak,
    );
  }
} 