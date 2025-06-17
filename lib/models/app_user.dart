import 'package:flutter/foundation.dart';

/// A class representing a user in the application.
@immutable
class AppUser {
  /// The unique identifier of the user.
  final String id;

  /// The name of the user.
  final String name;

  /// The email address of the user.
  final String email;

  /// The password of the user.
  final String password;

  /// The list of goals for the user.
  final List<Goal> goals;

  /// The partner ID of the user.
  final String? partnerId;

  /// Creates a new [AppUser] instance.
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.goals,
    this.partnerId,
  });

  /// Creates a copy of this [AppUser] with the given fields replaced with the new values.
  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    String? password,
    List<Goal>? goals,
    String? partnerId,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      goals: goals ?? this.goals,
      partnerId: partnerId ?? this.partnerId,
    );
  }

  /// Converts the [AppUser] instance to a JSON map.
  Map<String, dynamic> toJson() {
    print('Converting user to JSON: id=$id, email=$email');
    final json = {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'goals': goals.map((g) => g.toJson()).toList(),
      'partnerId': partnerId,
    };
    print('Generated JSON: $json');
    return json;
  }

  /// Converts the [AppUser] instance to a map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'goals': goals.map((g) => g.toMap()).toList(),
      'partnerId': partnerId,
    };
  }

  /// Creates an [AppUser] instance from a JSON map.
  factory AppUser.fromJson(Map<String, dynamic> json) {
    print('Creating user from JSON: $json');
    try {
      final user = AppUser(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        password: json['password'] as String,
        goals: (json['goals'] as List<dynamic>?)
                ?.map((g) => Goal.fromJson(g as Map<String, dynamic>))
                .toList() ??
            [],
        partnerId: json['partnerId'] as String?,
      );
      print('Created user: id=${user.id}, email=${user.email}');
      return user;
    } catch (e) {
      print('Error creating user from JSON: $e');
      print('Problematic JSON: $json');
      rethrow;
    }
  }

  /// Creates an [AppUser] instance from a map.
  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      password: map['password'] as String? ?? '',
      goals: (map['goals'] as List<dynamic>?)
          ?.map((g) => Goal.fromMap(g as Map<String, dynamic>))
          .toList() ?? [],
      partnerId: map['partnerId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          email == other.email &&
          password == other.password &&
          goals == other.goals &&
          partnerId == other.partnerId;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      email.hashCode ^
      password.hashCode ^
      goals.hashCode ^
      partnerId.hashCode;

  @override
  String toString() {
    return 'AppUser(id: $id, name: $name, email: $email, goals: $goals, partnerId: $partnerId)';
  }
}

/// A class representing a goal for a user.
@immutable
class Goal {
  /// The unique identifier of the goal.
  final String id;

  /// The text description of the goal.
  final String text;

  /// Whether the goal has been completed.
  final bool isCompleted;

  /// The date and time when the goal was created.
  final DateTime createdAt;

  /// The completion status of the goal by date.
  final Map<String, bool>? completionStatusByDate;

  /// Creates a new [Goal] instance.
  Goal({
    required this.id,
    required this.text,
    this.isCompleted = false,
    required this.createdAt,
    this.completionStatusByDate,
  });

  /// Creates a copy of this [Goal] with the given fields replaced with the new values.
  Goal copyWith({
    String? id,
    String? text,
    bool? isCompleted,
    DateTime? createdAt,
    Map<String, bool>? completionStatusByDate,
  }) {
    return Goal(
      id: id ?? this.id,
      text: text ?? this.text,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      completionStatusByDate: completionStatusByDate ?? this.completionStatusByDate,
    );
  }

  /// Converts the [Goal] instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'completionStatusByDate': completionStatusByDate,
    };
  }

  /// Converts the [Goal] instance to a map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'completionStatusByDate': completionStatusByDate,
    };
  }

  /// Creates a [Goal] instance from a JSON map.
  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String,
      text: json['text'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completionStatusByDate: json['completionStatusByDate'] as Map<String, bool>?,
    );
  }

  /// Creates a [Goal] instance from a map.
  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'] as String? ?? '',
      text: map['text'] as String? ?? '',
      isCompleted: map['isCompleted'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      completionStatusByDate: (map['completionStatusByDate'] as Map?)?.map((k, v) => MapEntry(k as String, v as bool)),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Goal &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          text == other.text &&
          isCompleted == other.isCompleted &&
          createdAt == other.createdAt &&
          completionStatusByDate == other.completionStatusByDate;

  @override
  int get hashCode =>
      id.hashCode ^
      text.hashCode ^
      isCompleted.hashCode ^
      createdAt.hashCode ^
      completionStatusByDate.hashCode;

  @override
  String toString() {
    return 'Goal(id: $id, text: $text, isCompleted: $isCompleted, createdAt: $createdAt, completionStatusByDate: $completionStatusByDate)';
  }
}

/// A class representing a daily goal for a user.
@immutable
class DailyGoal {
  /// The unique identifier of the daily goal.
  final String id;

  /// The text description of the daily goal.
  final String text;

  /// Whether the daily goal has been completed.
  final bool isCompleted;

  /// The date and time when the daily goal was created.
  final DateTime createdAt;

  /// Creates a new [DailyGoal] instance.
  DailyGoal({
    required this.id,
    required this.text,
    this.isCompleted = false,
    required this.createdAt,
  });

  /// Creates a copy of this [DailyGoal] with the given fields replaced with the new values.
  DailyGoal copyWith({
    String? id,
    String? text,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return DailyGoal(
      id: id ?? this.id,
      text: text ?? this.text,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Converts the [DailyGoal] instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Creates a [DailyGoal] instance from a JSON map.
  factory DailyGoal.fromJson(Map<String, dynamic> json) {
    return DailyGoal(
      id: json['id'] as String,
      text: json['text'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyGoal &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          text == other.text &&
          isCompleted == other.isCompleted &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      text.hashCode ^
      isCompleted.hashCode ^
      createdAt.hashCode;

  @override
  String toString() {
    return 'DailyGoal(id: $id, text: $text, isCompleted: $isCompleted)';
  }
} 