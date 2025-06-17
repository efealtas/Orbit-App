class UserModel {
  final String id;
  final String name;
  final String email;
  final List<String> goals;
  final String? partnerId;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.goals,
    this.partnerId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'goals': goals,
      'partnerId': partnerId,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      goals: List<String>.from(map['goals'] ?? []),
      partnerId: map['partnerId'] as String?,
    );
  }
} 