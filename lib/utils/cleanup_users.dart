import 'dart:convert';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';

/// Utility function to clean up local users that don't exist in Firebase.
/// This should be run once to ensure data consistency.
Future<void> cleanupNonFirebaseUsers() async {
  print('Starting cleanup of non-Firebase users...');
  
  final storageService = StorageService.instance;
  final firebaseService = FirebaseService();
  
  // Initialize storage service
  await storageService.init();
  
  // Get all local users
  final localUsers = await storageService.getAllUsers();
  print('Found ${localUsers.length} local users:');
  for (final user in localUsers) {
    print('- ${user.name} (${user.email})');
  }
  
  final usersToKeep = <String>[];
  
  // Check each user against Firebase
  for (final user in localUsers) {
    try {
      print('\nChecking user ${user.name} (${user.email}) in Firebase...');
      final userDoc = await firebaseService.getUserData(user.id);
      if (userDoc.exists) {
        print('✓ User exists in Firebase');
        usersToKeep.add(user.id);
      } else {
        print('✗ User does NOT exist in Firebase - will be removed');
      }
    } catch (e) {
      print('Error checking user in Firebase: $e');
      // If there's an error checking Firebase, we'll keep the user to be safe
      usersToKeep.add(user.id);
    }
  }
  
  print('\nUsers to keep: ${usersToKeep.length}');
  print('Users to remove: ${localUsers.length - usersToKeep.length}');
  
  // Get current user
  final currentUser = await storageService.getCurrentUser();
  if (currentUser != null) {
    print('\nCurrent user: ${currentUser.name} (${currentUser.email})');
    if (!usersToKeep.contains(currentUser.id)) {
      print('Current user does not exist in Firebase, clearing...');
      await storageService.setCurrentUser(null);
    }
  }
  
  // Get all partnerships
  final partnerships = await storageService.getAllPartnerships();
  print('\nFound ${partnerships.length} partnerships:');
  for (final p in partnerships) {
    print('- Partnership between users: ${p.user1Id} and ${p.user2Id}');
  }
  
  // Remove partnerships that involve deleted users
  final validPartnerships = partnerships.where((p) => 
    usersToKeep.contains(p.user1Id) && usersToKeep.contains(p.user2Id)
  ).toList();
  
  print('\nRemoving ${partnerships.length - validPartnerships.length} invalid partnerships');
  
  // Update partnerships in storage
  await storageService.updatePartnerships(validPartnerships);
  
  // Keep only the users that exist in Firebase
  final usersToKeepList = localUsers.where((u) => usersToKeep.contains(u.id)).toList();
  
  // Update users in storage
  await storageService.updateUsers(usersToKeepList);
  
  // Clear any messages related to deleted partnerships
  final messages = await storageService.getAllMessages();
  final validMessages = messages.where((m) => 
    validPartnerships.any((p) => p.id == m.partnershipId)
  ).toList();
  
  print('\nRemoving ${messages.length - validMessages.length} invalid messages');
  
  // Update messages in storage
  await storageService.updateMessages(validMessages);
  
  // Verify the cleanup
  final remainingUsers = await storageService.getAllUsers();
  print('\nCleanup verification:');
  print('- Remaining users: ${remainingUsers.length}');
  for (final user in remainingUsers) {
    print('  - ${user.name} (${user.email})');
  }
  
  final remainingPartnerships = await storageService.getAllPartnerships();
  print('- Remaining partnerships: ${remainingPartnerships.length}');
  for (final p in remainingPartnerships) {
    print('  - Partnership between users: ${p.user1Id} and ${p.user2Id}');
  }
  
  print('\nCleanup complete!');
} 