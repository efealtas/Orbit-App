import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../models/app_user.dart';
import '../models/partnership_model.dart';
import '../models/planet_model.dart';
import '../models/message_model.dart';
import '../widgets/simple_planet.dart';
import '../screens/messages_screen.dart';
import 'dart:math';
import '../screens/main_layout.dart';
import '../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  AppUser? _user;
  Partnership? _partnership;
  Planet? _planet;
  AppUser? _partner;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fixMismatchedPartnerships();
    _checkUserAndLoadData();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    _animationController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData(); // Reload data when dependencies change (e.g., returning from MessagesScreen)
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fixMismatchedPartnerships() async {
    try {
      final firebaseService = FirebaseService();
      
      // Get all partnerships
      final partnershipsSnapshot = await firebaseService.firestore.collection('partnerships').get();
      final partnerships = partnershipsSnapshot.docs.map((doc) {
        final data = doc.data();
        return Partnership(
          id: doc.id,
          user1Id: data['user1Id'],
          user2Id: data['user2Id'],
          startDate: DateTime.parse(data['startDate']),
          endDate: DateTime.parse(data['endDate']),
          streak: data['streak'] ?? 0,
        );
      }).toList();

      // Get all users
      final usersSnapshot = await firebaseService.firestore.collection('users').get();
      final users = usersSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'partnerId': data['partnerId'],
        };
      }).toList();

      // Create a map of user IDs to their partner IDs
      final userPartnerships = <String, String>{};
      for (final user in users) {
        if (user['partnerId'] != null && user['partnerId'].toString().isNotEmpty) {
          userPartnerships[user['id']] = user['partnerId'];
        }
      }

      // Fix mismatched partnerships
      for (final partnership in partnerships) {
        final user1PartnerId = userPartnerships[partnership.user1Id];
        final user2PartnerId = userPartnerships[partnership.user2Id];

        // If either user's partnerId doesn't match the partnership, fix it
        if (user1PartnerId != partnership.user2Id || user2PartnerId != partnership.user1Id) {
          print('Fixing mismatched partnership: ${partnership.id}');
          print('User1: ${partnership.user1Id} -> ${user1PartnerId} (should be ${partnership.user2Id})');
          print('User2: ${partnership.user2Id} -> ${user2PartnerId} (should be ${partnership.user1Id})');

          // Update both users with correct partner IDs
          await firebaseService.firestore.collection('users').doc(partnership.user1Id).update({
            'partnerId': partnership.user2Id,
          });
          await firebaseService.firestore.collection('users').doc(partnership.user2Id).update({
            'partnerId': partnership.user1Id,
          });
        }
      }
    } catch (e) {
      print('Error fixing mismatched partnerships: $e');
    }
  }

  Future<void> _checkUserAndLoadData() async {
    final storageService = Provider.of<StorageService>(context, listen: false);
    final user = await storageService.getCurrentUser();
    
    if (user == null) {
      debugPrint('HomeScreen: User is null in _checkUserAndLoadData. No local user found.');
      setState(() {
        _user = null;
      });
      // Do NOT redirect. Just show a message or let the user log out.
      return;
    } else {
      debugPrint('HomeScreen: User found in _checkUserAndLoadData: \\${user.email}');
      await _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; });
    try {
      final storageService = Provider.of<StorageService>(context, listen: false);
      final firebaseService = FirebaseService();
      final user = await storageService.getCurrentUser();
      if (user == null) {
        setState(() {
          _user = null;
          _partnership = null;
          _partner = null;
          _isLoading = false;
        });
        return;
      }

      // Get user's partner ID from Firebase
      final userDoc = await firebaseService.firestore.collection('users').doc(user.id).get();
      final partnerId = userDoc.data()?['partnerId'];
      
      if (partnerId != null && partnerId.isNotEmpty) {
        // Get partnership from Firebase
        final partnershipQuery = await firebaseService.firestore
            .collection('partnerships')
            .where('user1Id', isEqualTo: user.id)
            .where('user2Id', isEqualTo: partnerId)
            .get();
            
        if (partnershipQuery.docs.isEmpty) {
          // Try the reverse order
          final reversePartnershipQuery = await firebaseService.firestore
              .collection('partnerships')
              .where('user1Id', isEqualTo: partnerId)
              .where('user2Id', isEqualTo: user.id)
              .get();
              
          if (reversePartnershipQuery.docs.isEmpty) {
            // No partnership found, clear partner ID
            await firebaseService.firestore.collection('users').doc(user.id).update({'partnerId': null});
            setState(() {
              _user = user;
              _partnership = null;
              _partner = null;
              _isLoading = false;
            });
            return;
          }
          
          // Use the reverse partnership
          final partnershipData = reversePartnershipQuery.docs.first.data();
          final partnership = Partnership(
            id: reversePartnershipQuery.docs.first.id,
            user1Id: partnershipData['user1Id'],
            user2Id: partnershipData['user2Id'],
            startDate: DateTime.parse(partnershipData['startDate']),
            endDate: DateTime.parse(partnershipData['endDate']),
            streak: partnershipData['streak'] ?? 0,
          );
          
          // Get partner info from Firebase
          final partnerDoc = await firebaseService.firestore.collection('users').doc(partnerId).get();
          if (partnerDoc.exists) {
            final partnerData = partnerDoc.data()!;
            final partner = AppUser(
              id: partnerId,
              name: partnerData['name'] ?? 'Unknown',
              email: partnerData['email'] ?? '',
              password: '',
              goals: (partnerData['goals'] as List?)?.map((g) => Goal.fromMap(Map<String, dynamic>.from(g))).toList() ?? [],
            );
            
            // Save partnership locally
            await storageService.createPartnership(partnership);
            
            setState(() {
              _user = user;
              _partnership = partnership;
              _partner = partner;
              _isLoading = false;
            });
          } else {
            print('Partner document not found in Firebase');
            setState(() {
              _user = user;
              _partnership = partnership;
              _partner = null;
              _isLoading = false;
            });
          }
        } else {
          // Use the forward partnership
          final partnershipData = partnershipQuery.docs.first.data();
          final partnership = Partnership(
            id: partnershipQuery.docs.first.id,
            user1Id: partnershipData['user1Id'],
            user2Id: partnershipData['user2Id'],
            startDate: DateTime.parse(partnershipData['startDate']),
            endDate: DateTime.parse(partnershipData['endDate']),
            streak: partnershipData['streak'] ?? 0,
          );
          
          // Get partner info from Firebase
          final partnerDoc = await firebaseService.firestore.collection('users').doc(partnerId).get();
          if (partnerDoc.exists) {
            final partnerData = partnerDoc.data()!;
            final partner = AppUser(
              id: partnerId,
              name: partnerData['name'] ?? 'Unknown',
              email: partnerData['email'] ?? '',
              password: '',
              goals: (partnerData['goals'] as List?)?.map((g) => Goal.fromMap(Map<String, dynamic>.from(g))).toList() ?? [],
            );
            
            // Save partnership locally
            await storageService.createPartnership(partnership);
            
            setState(() {
              _user = user;
              _partnership = partnership;
              _partner = partner;
              _isLoading = false;
            });
          } else {
            print('Partner document not found in Firebase');
            setState(() {
              _user = user;
              _partnership = partnership;
              _partner = null;
              _isLoading = false;
            });
          }
        }
      } else {
        // No partner ID in Firebase, check local storage
        final localPartnership = await storageService.getPartnership(user.id);
        if (localPartnership != null) {
          // If partnership exists locally but not in Firebase, delete it
          await storageService.deletePartnership(localPartnership.id);
        }
        setState(() {
          _user = user;
          _partnership = null;
          _partner = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
      setState(() { _isLoading = false; });
    }
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade900,
            Colors.blue.shade700,
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, ${_user?.name ?? 'User'}!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          if (_partnership != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: Colors.orange,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Streak',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      Text(
                        '${_partnership!.streak} Days',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanetSection() {
    if (_planet == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Planet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Level ${_planet!.level}',
                  style: TextStyle(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: SimplePlanet(
              size: 120,
              color: Colors.blue,
              level: _planet!.level,
            ),
          ),
          const SizedBox(height: 20),
          _buildProgressBar(
            'Experience',
            _planet!.experience,
            100,
            Colors.blue,
          ),
          const SizedBox(height: 12),
          Text(
            'Evolution Stage: ${_planet!.evolutionStage}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnershipSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Partnership',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
          const SizedBox(height: 20),
          if (_partnership != null) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    'P',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Partner: ${_partner?.name ?? 'Loading...'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Streak: ${_partnership!.streak} days',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MessagesScreen()),
                    );
                  },
                  icon: const Icon(Icons.message),
                  color: Colors.blue,
                ),
              ],
            ),
          ] else ...[
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Partnership Yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _findPartner,
                    icon: const Icon(Icons.add),
                    label: const Text('Find a Partner'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _findPartner() async {
    try {
      final storageService = Provider.of<StorageService>(context, listen: false);
      final firebaseService = FirebaseService();
      final currentUser = await storageService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      print('\n=== Finding Partner Process ===');
      print('Current user: ${currentUser.name} (${currentUser.id})');

      // Get all users from Firebase
      print('\nFetching users from Firebase...');
      final usersSnapshot = await firebaseService.firestore.collection('users').get();
      print('Found ${usersSnapshot.docs.length} total users in Firebase');
      
      final availableUsers = <AppUser>[];
      
      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        final userId = doc.id;
        
        print('\nChecking user: ${data['name']} (${userId})');
        print('User data: $data');
        
        // Skip current user
        if (userId == currentUser.id) {
          print('Skipping current user');
          continue;
        }
        
        // Check if user already has a partner
        final partnerId = data['partnerId'];
        print('Partner ID: $partnerId');
        
        if (partnerId == null || partnerId == '') {
          print('User is available for partnership');
          // Convert Firebase user data to AppUser
          final user = AppUser(
            id: userId,
            name: data['name'] ?? 'Unknown',
            email: data['email'] ?? '',
            password: '', // We don't need the password for matching
            goals: (data['goals'] as List<dynamic>?)?.map((g) => Goal(
              id: UniqueKey().toString(),
              text: g.toString(),
              isCompleted: false,
              createdAt: DateTime.now(),
            )).toList() ?? [],
          );
          availableUsers.add(user);
        } else {
          print('User already has a partner');
        }
      }

      print('\nAvailable users for partnership: ${availableUsers.length}');
      for (final user in availableUsers) {
        print('- ${user.name} (${user.id})');
      }

      if (availableUsers.isEmpty) {
        throw Exception('No available partners found');
      }

      // Randomly select a partner
      final random = Random();
      final partner = availableUsers[random.nextInt(availableUsers.length)];
      print('\nSelected partner: ${partner.name} (${partner.id})');

      // Create partnership
      final partnership = Partnership(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        user1Id: currentUser.id,
        user2Id: partner.id,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        streak: 0,
      );

      print('\nCreating partnership...');
      
      // First, verify both users are still available
      final currentUserDoc = await firebaseService.firestore.collection('users').doc(currentUser.id).get();
      final partnerDoc = await firebaseService.firestore.collection('users').doc(partner.id).get();
      
      if (currentUserDoc.data()?['partnerId'] != null || partnerDoc.data()?['partnerId'] != null) {
        throw Exception('One of the users is no longer available for partnership');
      }

      // Create partnership in Firebase first
      await firebaseService.firestore.collection('partnerships').doc(partnership.id).set({
        'id': partnership.id,
        'user1Id': partnership.user1Id,
        'user2Id': partnership.user2Id,
        'startDate': partnership.startDate.toIso8601String(),
        'endDate': partnership.endDate.toIso8601String(),
        'streak': partnership.streak,
      });

      // Update both users with partner IDs in Firebase
      await firebaseService.firestore.collection('users').doc(currentUser.id).update({
        'partnerId': partner.id,
      });
      await firebaseService.firestore.collection('users').doc(partner.id).update({
        'partnerId': currentUser.id,
      });

      // Verify the updates
      final updatedCurrentUserDoc = await firebaseService.firestore.collection('users').doc(currentUser.id).get();
      final updatedPartnerDoc = await firebaseService.firestore.collection('users').doc(partner.id).get();
      
      if (updatedCurrentUserDoc.data()?['partnerId'] != partner.id || 
          updatedPartnerDoc.data()?['partnerId'] != currentUser.id) {
        // If verification fails, clean up the partnership
        await firebaseService.firestore.collection('partnerships').doc(partnership.id).delete();
        await firebaseService.firestore.collection('users').doc(currentUser.id).update({'partnerId': null});
        await firebaseService.firestore.collection('users').doc(partner.id).update({'partnerId': null});
        throw Exception('Failed to create partnership: partner IDs not properly set');
      }

      // Create initial messages
      final initialMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        partnershipId: partnership.id,
        senderId: currentUser.id,
        receiverId: partner.id,
        text: 'Hi! I\'m ${currentUser.name}. Here are my goals:\n${currentUser.goals.map((g) => '- ${g.text}').join('\n')}',
        timestamp: DateTime.now(),
      );
      final partnerMessage = Message(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        partnershipId: partnership.id,
        senderId: partner.id,
        receiverId: currentUser.id,
        text: 'Hi! I\'m ${partner.name}. Here are my goals:\n${partner.goals.map((g) => '- ${g.text}').join('\n')}',
        timestamp: DateTime.now(),
      );

      // Send initial messages
      await firebaseService.sendMessage(initialMessage);
      await firebaseService.sendMessage(partnerMessage);

      print('Saving partnership locally...');
      // Save partnership locally too
      await storageService.createPartnership(partnership);

      // Update local storage for offline support
      final updatedUser = currentUser.copyWith(partnerId: partner.id);
      await storageService.updateUser(updatedUser);
      await storageService.setCurrentUser(updatedUser);

      print('Reloading data...');
      // Reload local data so UI updates
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found a partner: ${partner.name}!')),
        );
        // Navigate to MainScreen with messages tab selected
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MainLayout(),
          ),
        );
      }
    } catch (e) {
      print('Error finding partner: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error finding partner: $e')),
        );
      }
    }
  }

  Widget _buildProgressBar(String label, int value, int max, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$value/$max',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: value / max,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // If still loading, show spinner
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // If no user, show a message and a logout button
    if (_user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No user data found. Please log out and log in again.'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final firebaseService = FirebaseService();
                  await firebaseService.signOut();
                },
                child: const Text('Log Out'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Show confirmation dialog
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () {
                          Navigator.of(context).pop(false);
                        },
                      ),
                      TextButton(
                        child: const Text('Logout'),
                        onPressed: () {
                          Navigator.of(context).pop(true);
                        },
                      ),
                    ],
                  );
                },
              );

              if (shouldLogout == true) {
                final storageService = Provider.of<StorageService>(context, listen: false);
                final firebaseService = FirebaseService(); // Instantiate FirebaseService
                await firebaseService.signOut(); // Sign out from Firebase
                await storageService.setCurrentUser(null);
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/'); // Navigate to AuthScreen (login/register)
                }
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            children: [
              _buildWelcomeSection(),
              const SizedBox(height: 20),
              _buildPlanetSection(),
              const SizedBox(height: 20),
              _buildPartnershipSection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
