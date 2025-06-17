import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/partnership_model.dart';
import '../models/message_model.dart';
import '../models/app_user.dart';
import '../models/journal_entry.dart';
import '../models/planet_model.dart';

/// A service that handles local storage operations using SharedPreferences.
class StorageService extends ChangeNotifier {
  static final StorageService instance = StorageService._internal();
  
  StorageService._internal();

  static const String _usersKey = 'users';
  static const String _currentUserKey = 'current_user';
  static const String _partnershipsKey = 'partnerships';
  static const String _journalEntriesKey = 'journal_entries';
  static const String _messagesKey = 'messages';
  static const String _planetsKey = 'planets';

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  StorageService();

  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;

  void setUser(UserModel user) {
    _currentUser = user;
    notifyListeners();
  }

  void clearUser() {
    _currentUser = null;
    notifyListeners();
  }

  /// Initializes the storage service.
  Future<void> init() async {
    if (!_isInitialized) {
      print('Initializing StorageService...');
      _prefs = await SharedPreferences.getInstance();
      // One-time clear to remove corrupted/legacy data
      await _prefs.clear();
      _isInitialized = true;
      print('StorageService initialized');
    }
  }

  /// Gets all users from storage.
  Future<List<AppUser>> getAllUsers() async {
    await init();
    final usersJson = _prefs.getStringList(_usersKey) ?? [];
    print('Getting all users: ${usersJson.length} users found');
    final users = usersJson.map((json) {
      try {
        if (json is! String) {
          print('Skipping non-string user data: $json');
          return null;
        }
        final Map<String, dynamic> userMap = jsonDecode(json);
        final user = AppUser.fromMap(userMap);
        print('Parsed user: id=${user.id}, email=${user.email}');
        return user;
      } catch (e) {
        print('Error parsing user: $e');
        print('Problematic JSON: $json');
        return null;
      }
    }).whereType<AppUser>().toList();
    return users;
  }

  /// Gets the current user from storage.
  Future<AppUser?> getCurrentUser() async {
    await init();
    final userJson = _prefs.getString(_currentUserKey);
    print('Getting current user: ${userJson != null ? 'user found' : 'no user found'}');
    if (userJson == null) return null;
    
    try {
      final user = AppUser.fromMap(jsonDecode(userJson));
      print('Current user: id=${user.id}, email=${user.email}');
      return user;
    } catch (e) {
      print('Error parsing current user: $e');
      print('Problematic JSON: $userJson');
      return null;
    }
  }

  /// Sets the current user in storage.
  Future<void> setCurrentUser(AppUser? user) async {
    await init();
    if (user == null) {
      print('Logging out user');
      await _prefs.remove(_currentUserKey);
    } else {
      print('Setting current user: id=${user.id}, email=${user.email}');
      // Get the latest user data before setting as current user
      final latestUser = await getUser(user.id);
      if (latestUser != null) {
        print('Setting current user with latest data');
        await _prefs.setString(_currentUserKey, jsonEncode(latestUser.toMap()));
      } else {
        print('Setting current user with provided data');
        await _prefs.setString(_currentUserKey, jsonEncode(user.toMap()));
      }
      
      // Verify the save
      final savedUserJson = _prefs.getString(_currentUserKey);
      if (savedUserJson != null) {
        final savedUser = AppUser.fromMap(jsonDecode(savedUserJson));
        print('Verified saved current user: id=${savedUser.id}, email=${savedUser.email}');
      }
    }
    notifyListeners();
  }

  /// Creates a new user in storage.
  Future<void> createUser(AppUser user) async {
    await init();
    print('Creating new user: ${user.id}');
    print('User details: name=${user.name}, email=${user.email}');
    
    // Get current users
    final users = await getAllUsers();
    print('Current users in storage: ${users.length}');
    
    // Check if user already exists
    final existingUserIndex = users.indexWhere((u) => u.email == user.email);
    if (existingUserIndex != -1) {
      print('User with email ${user.email} already exists');
      throw Exception('User with this email already exists');
    }
    
    // Add new user
    users.add(user);
    
    // Save users
    final usersJson = users.map((u) => jsonEncode(u.toMap())).toList();
    await _prefs.setStringList(_usersKey, usersJson);
    print('Saved users to storage: ${usersJson.length} users');
    
    // Verify the save
    final savedUsers = await getAllUsers();
    print('Verifying saved users: ${savedUsers.length} users found');
    for (final savedUser in savedUsers) {
      print('Saved user: id=${savedUser.id}, email=${savedUser.email}');
    }
    
    notifyListeners();
  }

  /// Gets a user by ID from storage.
  Future<AppUser?> getUser(String userId) async {
    await init();
    final users = await getAllUsers();
    try {
      final user = users.firstWhere((user) => user.id == userId);
      print('Getting user by ID: ${user.id} found with ${user.goals.length} goals');
      print('User goals: ${user.goals.map((g) => '${g.text}: ${g.isCompleted}').join(', ')}');
      return user;
    } catch (e) {
      print('Getting user by ID: no user found with ID $userId');
      return null;
    }
  }

  /// Updates a user in storage.
  Future<void> updateUser(AppUser user) async {
    await init();
    print('Updating user: ${user.id}');
    final users = await getAllUsers();
    final index = users.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      users[index] = user;
      await _prefs.setStringList(
        _usersKey,
        users.map((u) => jsonEncode(u.toMap())).toList(),
      );
      // Also update current user if it's the same user
      final currentUser = await getCurrentUser();
      if (currentUser?.id == user.id) {
        await setCurrentUser(user);
      }
      notifyListeners();
      
      // Verify the update
      final savedUsers = await getAllUsers();
      final savedUser = savedUsers.firstWhere((u) => u.id == user.id);
      print('Verified saved user goals: ${savedUser.goals.map((g) => '${g.text}: ${g.isCompleted}').join(', ')}');
    }
  }

  /// Gets a user by email from storage.
  Future<AppUser?> getUserByEmail(String email) async {
    await init();
    print('Getting user by email: $email');
    final users = await getAllUsers();
    try {
      final user = users.firstWhere((user) => user.email == email);
      print('Found user with email $email: id=${user.id}');
      return user;
    } catch (e) {
      print('No user found with email $email');
      return null;
    }
  }

  /// Updates a user's goals in storage.
  Future<void> updateUserGoals(String userId, List<Goal> goals) async {
    await init();
    print('Updating user goals for user: $userId');
    final users = await getAllUsers();
    final index = users.indexWhere((u) => u.id == userId);
    if (index != -1) {
      final user = users[index];
      final updatedUser = AppUser(
        id: user.id,
        name: user.name,
        email: user.email,
        password: user.password,
        goals: goals,
      );
      users[index] = updatedUser;
      await _prefs.setStringList(
        _usersKey,
        users.map((u) => jsonEncode(u.toMap())).toList(),
      );
      // Also update current user if it's the same user
      final currentUser = await getCurrentUser();
      if (currentUser?.id == userId) {
        await setCurrentUser(updatedUser);
      }
      notifyListeners();
    }
  }

  /// Updates a single goal's completion status.
  Future<void> updateGoalCompletion(String userId, String goalId, bool isCompleted) async {
    try {
      await init();
      print('Updating goal completion for user $userId, goal $goalId to $isCompleted');
      
      // Get all users
      final users = await getAllUsers();
      print('Current users in storage: ${users.map((u) => '${u.id}: ${u.goals.map((g) => '${g.text}: ${g.isCompleted}').join(', ')}').join('\n')}');
      
      // Find the user
      final userIndex = users.indexWhere((u) => u.id == userId);
      if (userIndex == -1) {
        print('Error: User not found with ID $userId');
        return;
      }
      
      final user = users[userIndex];
      print('Found user: ${user.id} with goals: ${user.goals.map((g) => '${g.text}: ${g.isCompleted}').join(', ')}');
      
      // Find and update the goal
      final goalIndex = user.goals.indexWhere((g) => g.id == goalId);
      if (goalIndex == -1) {
        print('Error: Goal not found with ID $goalId');
        return;
      }
      
      // Create updated goals list
      final updatedGoals = List<Goal>.from(user.goals);
      updatedGoals[goalIndex] = Goal(
        id: goalId,
        text: user.goals[goalIndex].text,
        isCompleted: isCompleted,
        createdAt: user.goals[goalIndex].createdAt,
      );
      
      // Create updated user
      final updatedUser = AppUser(
        id: user.id,
        name: user.name,
        email: user.email,
        password: user.password,
        goals: updatedGoals,
      );
      
      // Update user in the list
      users[userIndex] = updatedUser;
      print('Updated user goals: ${updatedUser.goals.map((g) => '${g.text}: ${g.isCompleted}').join(', ')}');
      
      // Save all users back to storage
      final usersJson = users.map((u) => jsonEncode(u.toMap())).toList();
      await _prefs.setStringList(_usersKey, usersJson);
      print('Saved users back to storage');
      
      // Verify the save
      final savedUsers = await getAllUsers();
      print('Verified saved users: ${savedUsers.map((u) => '${u.id}: ${u.goals.map((g) => '${g.text}: ${g.isCompleted}').join(', ')}').join('\n')}');
      
      // Update current user if it's the same user
      final currentUser = await getCurrentUser();
      if (currentUser?.id == userId) {
        await setCurrentUser(updatedUser);
        print('Updated current user with new goals');
      }
      
      // Force a refresh of all users
      notifyListeners();
      
      // Double-check the save after a short delay
      await Future.delayed(const Duration(milliseconds: 100));
      final doubleCheckUsers = await getAllUsers();
      print('Double-check saved users: ${doubleCheckUsers.map((u) => '${u.id}: ${u.goals.map((g) => '${g.text}: ${g.isCompleted}').join(', ')}').join('\n')}');
    } catch (e) {
      print('Error updating goal completion: $e');
      rethrow;
    }
  }

  /// Deletes a user's goals in storage.
  Future<void> deleteUserGoals(String userId) async {
    await init();
    print('Deleting user goals for user: $userId');
    final user = await getUser(userId);
    if (user != null) {
      final updatedUser = AppUser(
        id: user.id,
        name: user.name,
        email: user.email,
        password: user.password,
        goals: [], // Clear all goals
      );
      await updateUser(updatedUser);
    }
  }

  /// Gets all partnerships from storage.
  Future<List<Partnership>> getAllPartnerships() async {
    await init();
    final partnershipsJson = _prefs.getStringList(_partnershipsKey) ?? [];
    print('Getting all partnerships: ${partnershipsJson.length} partnerships found');
    return partnershipsJson
        .map((json) => Partnership.fromMap(jsonDecode(json)))
        .toList();
  }

  /// Gets a partnership by user ID from storage.
  Future<Partnership?> getPartnership(String userId) async {
    await init();
    final partnerships = await getAllPartnerships();
    try {
      final partnership = partnerships.firstWhere(
        (p) => p.user1Id == userId || p.user2Id == userId,
      );
      print('Getting partnership: partnership found for user $userId');
      print('Partnership details: user1Id=${partnership.user1Id}, user2Id=${partnership.user2Id}');
      return partnership;
    } catch (e) {
      print('Getting partnership: no partnership found for user $userId');
      return null;
    }
  }

  /// Creates a new partnership in storage.
  Future<void> createPartnership(Partnership partnership) async {
    await init();
    print('Creating new partnership: ${partnership.id}');
    print('Partnership details: user1Id=${partnership.user1Id}, user2Id=${partnership.user2Id}');
    final partnerships = await getAllPartnerships();
    partnerships.add(partnership);
    await _prefs.setStringList(
      _partnershipsKey,
      partnerships.map((p) => jsonEncode(p.toMap())).toList(),
    );
    notifyListeners();
  }

  /// Updates a partnership in storage.
  Future<void> updatePartnership(Partnership partnership) async {
    await init();
    print('Updating partnership: ${partnership.id}');
    print('New streak value: ${partnership.streak}');
    
    final partnerships = await getAllPartnerships();
    final index = partnerships.indexWhere((p) => p.id == partnership.id);
    if (index != -1) {
      partnerships[index] = partnership;
      await _prefs.setStringList(
        _partnershipsKey,
        partnerships.map((p) => jsonEncode(p.toMap())).toList(),
      );
      
      // Verify the save
      final savedPartnerships = await getAllPartnerships();
      final savedPartnership = savedPartnerships.firstWhere((p) => p.id == partnership.id);
      print('Verified saved partnership streak: ${savedPartnership.streak}');
      
      notifyListeners();
    } else {
      print('Error: Partnership not found with ID ${partnership.id}');
    }
  }

  /// Gets all journal entries from storage.
  Future<List<JournalEntry>> getAllJournalEntries() async {
    await init();
    final entriesJson = _prefs.getStringList(_journalEntriesKey) ?? [];
    print('Getting all journal entries: ${entriesJson.length} entries found');
    return entriesJson
        .map((json) => JournalEntry.fromMap(jsonDecode(json)))
        .toList();
  }

  /// Gets journal entries by user ID from storage.
  Future<List<JournalEntry>> getJournalEntries(String userId) async {
    await init();
    final entries = await getAllJournalEntries();
    final userEntries = entries.where((entry) => entry.userId == userId).toList();
    print('Getting journal entries for user $userId: ${userEntries.length} entries found');
    return userEntries;
  }

  /// Creates a new journal entry in storage.
  Future<void> createJournalEntry(JournalEntry entry) async {
    await init();
    print('Creating new journal entry: ${entry.id}');
    final entries = await getAllJournalEntries();
    entries.add(entry);
    await _prefs.setStringList(
      _journalEntriesKey,
      entries.map((e) => jsonEncode(e.toMap())).toList(),
    );
    notifyListeners();
  }

  /// Deletes a journal entry from storage.
  Future<void> deleteJournalEntry(String entryId) async {
    await init();
    print('Deleting journal entry: $entryId');
    final entries = await getAllJournalEntries();
    entries.removeWhere((entry) => entry.id == entryId);
    await _prefs.setStringList(
      _journalEntriesKey,
      entries.map((e) => jsonEncode(e.toMap())).toList(),
    );
    notifyListeners();
  }

  /// Gets all messages from storage.
  Future<List<Message>> getAllMessages() async {
    await init();
    final messagesJson = _prefs.getStringList(_messagesKey) ?? [];
    print('Getting all messages: ${messagesJson.length} messages found');
    return messagesJson.map((json) {
      try {
        final Map<String, dynamic> messageMap = jsonDecode(json);
        return Message.fromMap(messageMap);
      } catch (e) {
        print('Error parsing message: $e');
        print('Problematic JSON: $json');
        return null;
      }
    }).whereType<Message>().toList();
  }

  /// Gets messages by partnership ID from storage.
  Future<List<Message>> getMessages(String partnershipId) async {
    await init();
    final messages = await getAllMessages();
    final partnershipMessages = messages.where((msg) => msg.partnershipId == partnershipId).toList();
    print('Getting messages for partnership $partnershipId: ${partnershipMessages.length} messages found');
    print('Messages: ${partnershipMessages.map((m) => '${m.senderId} -> ${m.receiverId}: ${m.text}').join('\n')}');
    return partnershipMessages;
  }

  /// Creates a new message in storage.
  Future<void> createMessage(Message message) async {
    await init();
    print('Creating new message: ${message.id}');
    print('Message details: partnershipId=${message.partnershipId}, senderId=${message.senderId}, receiverId=${message.receiverId}');
    final messages = await getAllMessages();
    messages.add(message);
    await _prefs.setStringList(
      _messagesKey,
      messages.map((m) => jsonEncode(m.toMap())).toList(),
    );
    notifyListeners();
  }

  /// Gets all planets from storage.
  Future<List<Planet>> getAllPlanets() async {
    await init();
    final planetsJson = _prefs.getStringList(_planetsKey) ?? [];
    print('Getting all planets: ${planetsJson.length} planets found');
    return planetsJson
        .map((json) => Planet.fromMap(jsonDecode(json)))
        .toList();
  }

  /// Gets a planet by user ID from storage.
  Future<Planet?> getPlanet(String userId) async {
    await init();
    final planets = await getAllPlanets();
    try {
      final planet = planets.firstWhere((p) => p.userId == userId);
      print('Getting planet: planet found for user $userId');
      return planet;
    } catch (e) {
      print('Getting planet: no planet found for user $userId');
      return null;
    }
  }

  /// Creates a new planet in storage.
  Future<void> createPlanet(Planet planet) async {
    await init();
    print('Creating new planet: ${planet.id}');
    final planets = await getAllPlanets();
    planets.add(planet);
    await _prefs.setStringList(
      _planetsKey,
      planets.map((p) => jsonEncode(p.toMap())).toList(),
    );
    notifyListeners();
  }

  /// Updates a planet in storage.
  Future<void> updatePlanet(Planet planet) async {
    await init();
    print('Updating planet: ${planet.id}');
    final planets = await getAllPlanets();
    final index = planets.indexWhere((p) => p.id == planet.id);
    if (index != -1) {
      planets[index] = planet;
      await _prefs.setStringList(
        _planetsKey,
        planets.map((p) => jsonEncode(p.toMap())).toList(),
      );
      notifyListeners();
    }
  }

  /// Initializes test users for development
  Future<void> initializeTestUsers() async {
    await init();
    
    // Check if any users exist
    final existingUsers = await getAllUsers();
    if (existingUsers.isNotEmpty) {
      print('Users already exist, skipping test user initialization');
      return;
    }
    
    print('No users found, initializing test users...');
    
    // Create test users with goals
    final testUsers = [
      AppUser(
        id: 'user1',
        name: 'John Doe',
        email: 'john@test.com',
        password: 'password123',
        goals: [
          Goal(
            id: '1',
            text: 'Complete morning meditation',
            isCompleted: false,
            createdAt: DateTime.now(),
          ),
          Goal(
            id: '2',
            text: 'Read for 30 minutes',
            isCompleted: false,
            createdAt: DateTime.now(),
          ),
        ],
      ),
      AppUser(
        id: 'user2',
        name: 'Jane Smith',
        email: 'jane@test.com',
        password: 'password123',
        goals: [
          Goal(
            id: '3',
            text: 'Go for a run',
            isCompleted: false,
            createdAt: DateTime.now(),
          ),
          Goal(
            id: '4',
            text: 'Practice coding',
            isCompleted: false,
            createdAt: DateTime.now(),
          ),
        ],
      ),
    ];

    // Save users
    await _prefs.setStringList(
      _usersKey,
      testUsers.map((user) => jsonEncode(user.toMap())).toList(),
    );

    // Create planets for test users
    for (final user in testUsers) {
      final planet = Planet(
        id: 'planet_${user.id}',
        userId: user.id,
        name: '${user.name}\'s Planet',
        level: 1,
        experience: 0,
        evolutionStage: 'seed',
      );
      await createPlanet(planet);
    }

    // Verify the users were saved correctly
    final savedUsers = await getAllUsers();
    print('Initialized test users:');
    for (final user in savedUsers) {
      print('User: ${user.name}');
      print('Goals: ${user.goals.map((g) => '${g.text}: ${g.isCompleted}').join(', ')}');
    }

    print('Test users initialized');
  }

  Future<void> deletePartnership(String partnershipId) async {
    await init();
    print('Deleting partnership: $partnershipId');
    
    // Get all partnerships
    final partnerships = await getAllPartnerships();
    final partnership = partnerships.firstWhere((p) => p.id == partnershipId);
    
    // Remove partnership
    partnerships.removeWhere((p) => p.id == partnershipId);
    await _prefs.setStringList(
      _partnershipsKey,
      partnerships.map((p) => jsonEncode(p.toMap())).toList(),
    );
    
    // Delete all messages for this partnership
    final messages = await getAllMessages();
    final partnershipMessages = messages.where((m) => m.partnershipId == partnershipId).toList();
    final remainingMessages = messages.where((m) => m.partnershipId != partnershipId).toList();
    await _prefs.setStringList(
      _messagesKey,
      remainingMessages.map((m) => jsonEncode(m.toMap())).toList(),
    );
    
    print('Deleted partnership and ${partnershipMessages.length} messages');
    notifyListeners();
  }

  Future<List<Planet>> getPlanets() async {
    final prefs = await SharedPreferences.getInstance();
    final planetsJson = prefs.getString(_planetsKey) ?? '[]';
    final List<dynamic> planetsList = jsonDecode(planetsJson);
    return planetsList.map((p) => Planet.fromMap(p)).toList();
  }

  /// Updates the list of users in storage.
  Future<void> updateUsers(List<AppUser> users) async {
    await init();
    print('Updating users list: ${users.length} users');
    final usersJson = users.map((u) => jsonEncode(u.toMap())).toList();
    await _prefs.setStringList(_usersKey, usersJson);
    notifyListeners();
  }

  /// Updates the list of partnerships in storage.
  Future<void> updatePartnerships(List<Partnership> partnerships) async {
    await init();
    print('Updating partnerships list: ${partnerships.length} partnerships');
    final partnershipsJson = partnerships.map((p) => jsonEncode(p.toMap())).toList();
    await _prefs.setStringList(_partnershipsKey, partnershipsJson);
    notifyListeners();
  }

  /// Updates the list of messages in storage.
  Future<void> updateMessages(List<Message> messages) async {
    await init();
    print('Updating messages list: ${messages.length} messages');
    final messagesJson = messages.map((m) => jsonEncode(m.toMap())).toList();
    await _prefs.setStringList(_messagesKey, messagesJson);
    notifyListeners();
  }
} 