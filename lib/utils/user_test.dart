import 'package:flutter/foundation.dart';
import '../models/app_user.dart';

void testUserModel() {
  final user = AppUser(
    id: '1',
    name: 'Test User',
    email: 'test@example.com',
    password: 'password123',
    goals: [Goal(id: 'g1', text: 'Test goal', createdAt: DateTime.now())],
  );
  
  print('User email: ${user.email}');
} 