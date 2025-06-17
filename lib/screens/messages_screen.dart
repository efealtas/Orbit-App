import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../models/message_model.dart';
import '../models/partnership_model.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _messageController = TextEditingController();
  final _firebaseService = FirebaseService();
  Stream<List<Message>>? _messagesStream;
  AppUser? _user;
  AppUser? _partner;
  Partnership? _partnership;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<List<Goal>> _fetchGoalsFromFirebase(String userId) async {
    final firebaseService = FirebaseService();
    final doc = await firebaseService.firestore.collection('users').doc(userId).get();
    final data = doc.data();
    if (data != null && data['goals'] != null) {
      return (data['goals'] as List)
          .map((g) => Goal.fromMap(Map<String, dynamic>.from(g)))
          .toList();
    }
    return [];
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; });
    try {
      final storageService = Provider.of<StorageService>(context, listen: false);
      final user = await storageService.getCurrentUser();
      if (user == null) {
        print('No current user found');
        setState(() {
          _user = null;
          _partner = null;
          _partnership = null;
          _messagesStream = null;
          _isLoading = false;
        });
        return;
      }
      print('Loading partnership for user: ${user.id}');
      final partnership = await storageService.getPartnership(user.id);
      if (partnership == null) {
        print('No partnership found for user: ${user.id}');
        setState(() {
          _user = user;
          _partner = null;
          _partnership = null;
          _messagesStream = null;
          _isLoading = false;
        });
        return;
      }
      print('Found partnership: ${partnership.id}');
      final partnerId = partnership.user1Id == user.id ? partnership.user2Id : partnership.user1Id;
      print('Partner ID: $partnerId');
      
      // Fetch latest goals for both users from Firebase
      final userGoals = await _fetchGoalsFromFirebase(user.id);
      final partnerGoals = await _fetchGoalsFromFirebase(partnerId);
      final allUsers = await storageService.getAllUsers();
      final partner = allUsers.firstWhere(
        (u) => u.id == partnerId,
        orElse: () {
          print('Partner not found in local storage, creating placeholder');
          return AppUser(id: partnerId, name: 'Partner', email: '', password: '', goals: []);
        }
      );
      
      if (partnership.id.isEmpty) {
        print('Error: Partnership ID is empty');
        throw Exception('Invalid partnership ID');
      }
      
      setState(() {
        _user = user.copyWith(goals: userGoals);
        _partner = partner.copyWith(goals: partnerGoals);
        _partnership = partnership;
        _messagesStream = _firebaseService.getMessages(partnership.id);
        _isLoading = false;
      });
    } catch (e) {
      print('Error in _loadData: $e');
      setState(() { _isLoading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chat: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _user == null || _partner == null || _partnership == null) return;
    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      partnershipId: _partnership!.id,
      senderId: _user!.id,
      receiverId: _partner!.id,
      text: _messageController.text.trim(),
      timestamp: DateTime.now(),
    );
    await _firebaseService.sendMessage(message);
    _messageController.clear();
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_user == null) {
      return const Scaffold(
        body: Center(child: Text('No user found. Please log in.')),
      );
    }
    if (_partner == null || _partnership == null) {
      return const Scaffold(
        body: Center(child: Text('No partner found. Find a partner to start chatting!')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(child: Text(_partner != null && _partner!.name.isNotEmpty ? _partner!.name : 'Partner')),
            if (_partnership != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orange, size: 18),
                    const SizedBox(width: 4),
                    Text('${_partnership!.streak} Day Streak', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          // Removed break partnership button
        ],
      ),
      body: Column(
        children: [
          // Goals section with checkboxes
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseService().firestore.collection('users').doc(_user!.id).snapshots(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (userSnapshot.hasError) {
                print('Error loading user goals: ${userSnapshot.error}');
                return Center(child: Text('Error loading goals: ${userSnapshot.error}'));
              }
              final data = userSnapshot.data!.data() as Map<String, dynamic>?;
              if (data == null) {
                print('No data found for user');
                return const Center(child: Text('No goals found'));
              }
              final userGoals = (data['goals'] as List?)?.map((g) => Goal.fromMap(Map<String, dynamic>.from(g))).toList() ?? [];
              print('Loaded ${userGoals.length} user goals');
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseService().firestore.collection('users').doc(_partner!.id).snapshots(),
                builder: (context, partnerSnapshot) {
                  if (!partnerSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (partnerSnapshot.hasError) {
                    print('Error loading partner goals: ${partnerSnapshot.error}');
                    return Center(child: Text('Error loading partner goals: ${partnerSnapshot.error}'));
                  }
                  final partnerData = partnerSnapshot.data!.data() as Map<String, dynamic>?;
                  if (partnerData == null) {
                    print('No data found for partner');
                    return const Center(child: Text('No partner goals found'));
                  }
                  final partnerGoals = (partnerData['goals'] as List?)?.map((g) => Goal.fromMap(Map<String, dynamic>.from(g))).toList() ?? [];
                  print('Loaded ${partnerGoals.length} partner goals');
                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User goals
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${_user!.name.isNotEmpty ? _user!.name : 'You'}\'s Goals:', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              ...userGoals.map((goal) {
                                final todayKey = '${DateTime.now().toIso8601String().substring(0, 10)}_${_user!.id}';
                                final checked = goal.completionStatusByDate?[todayKey] ?? false;
                                print('Goal ${goal.id}: checked=$checked, status=${goal.completionStatusByDate}');
                                return Row(
                                  children: [
                                    Checkbox(
                                      value: checked,
                                      onChanged: (value) async {
                                        try {
                                          final firebaseService = FirebaseService();
                                          final newCompletionStatus = Map<String, bool>.from(goal.completionStatusByDate ?? {});
                                          newCompletionStatus[todayKey] = value ?? false;
                                          final updatedGoal = goal.copyWith(completionStatusByDate: newCompletionStatus);
                                          final updatedGoals = List<Goal>.from(userGoals);
                                          final idx = updatedGoals.indexWhere((g) => g.id == goal.id);
                                          updatedGoals[idx] = updatedGoal;
                                          print('Updating goal ${goal.id} with new status: $newCompletionStatus');
                                          await firebaseService.firestore.collection('users').doc(_user!.id).set({
                                            'goals': updatedGoals.map((g) => g.toMap()).toList(),
                                          }, SetOptions(merge: true));
                                          await _checkAndUpdateStreakFirestore(updatedGoals, partnerGoals);
                                        } catch (e) {
                                          print('Error updating goal: $e');
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Error updating goal: $e')),
                                            );
                                          }
                                        }
                                      },
                                      activeColor: Colors.green,
                                    ),
                                    Expanded(
                                      child: Text(
                                        goal.text,
                                        style: TextStyle(
                                          decoration: checked ? TextDecoration.lineThrough : null,
                                          color: checked ? Colors.grey : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                        const Divider(),
                        // Partner goals
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${_partner!.name.isNotEmpty ? _partner!.name : 'Partner'}\'s Goals:', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              ...partnerGoals.map((goal) {
                                final todayKey = '${DateTime.now().toIso8601String().substring(0, 10)}_${_partner!.id}';
                                final checked = goal.completionStatusByDate?[todayKey] ?? false;
                                return Row(
                                  children: [
                                    Checkbox(
                                      value: checked,
                                      onChanged: null, // Partner's goals can't be checked by the user
                                      activeColor: Colors.green,
                                    ),
                                    Expanded(
                                      child: Text(
                                        goal.text,
                                        style: TextStyle(
                                          decoration: checked ? TextDecoration.lineThrough : null,
                                          color: checked ? Colors.grey : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          // Messages section
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == _user!.id;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          message.text,
                          style: TextStyle(color: isMe ? Colors.white : Colors.black),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Message input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message to \\${_partner != null && _partner!.name.isNotEmpty ? _partner!.name : 'your partner'}...',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAndUpdateStreakFirestore(List<Goal> userGoals, List<Goal> partnerGoals) async {
    if (_user == null || _partner == null || _partnership == null) return;
    final todayKeyUser = '${DateTime.now().toIso8601String().substring(0, 10)}_${_user!.id}';
    final todayKeyPartner = '${DateTime.now().toIso8601String().substring(0, 10)}_${_partner!.id}';
    final allUserGoalsChecked = userGoals.isNotEmpty && userGoals.every((g) => g.completionStatusByDate?[todayKeyUser] ?? false);
    final allPartnerGoalsChecked = partnerGoals.isNotEmpty && partnerGoals.every((g) => g.completionStatusByDate?[todayKeyPartner] ?? false);
    if (allUserGoalsChecked && allPartnerGoalsChecked) {
      // Increment streak
      final newStreak = (_partnership!.streak) + 1;
      final updatedPartnership = _partnership!.copyWith(streak: newStreak);
      await FirebaseService().firestore.collection('partnerships').doc(_partnership!.id).update({'streak': newStreak});
      setState(() { _partnership = updatedPartnership; });
    }
  }
} 