class JournalEntry {
  final String id;
  final String userId;
  final String content;
  final DateTime timestamp;
  final String mood;

  JournalEntry({
    required this.id,
    required this.userId,
    required this.content,
    required this.timestamp,
    required this.mood,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'mood': mood,
    };
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    return JournalEntry(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      content: map['content'] as String? ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : DateTime.now(),
      mood: map['mood'] as String? ?? '',
    );
  }
} 