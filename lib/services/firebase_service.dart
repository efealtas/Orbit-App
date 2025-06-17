import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../models/partnership_model.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Public getter for Firestore
  FirebaseFirestore get firestore => _firestore;

  // Auth methods
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    }
  }

  Future<UserCredential?> createUserWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  // Firestore methods
  Future<void> addUserData(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).set(data);
    } catch (e) {
      print('Error adding user data: $e');
      rethrow;
    }
  }

  Future<DocumentSnapshot> getUserData(String userId) async {
    try {
      return await _firestore.collection('users').doc(userId).get();
    } catch (e) {
      print('Error getting user data: $e');
      rethrow;
    }
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Chat methods
  Future<void> sendMessage(Message message) async {
    try {
      print('Sending message: ${message.text}');
      await _firestore
          .collection('messages')
          .doc(message.id)
          .set({
            'partnershipId': message.partnershipId,
            'senderId': message.senderId,
            'receiverId': message.receiverId,
            'text': message.text,
            'timestamp': message.timestamp.toIso8601String(),
          });
      print('Message sent successfully');
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  Stream<List<Message>> getMessages(String partnershipId) {
    if (partnershipId.isEmpty) {
      print('Error: Empty partnership ID provided to getMessages');
      return Stream.value([]);
    }
    print('Getting messages for partnership: $partnershipId');
    return _firestore
        .collection('messages')
        .where('partnershipId', isEqualTo: partnershipId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          print('Received ${snapshot.docs.length} messages');
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return Message(
              id: doc.id,
              partnershipId: data['partnershipId'],
              senderId: data['senderId'],
              receiverId: data['receiverId'],
              text: data['text'],
              timestamp: DateTime.parse(data['timestamp']),
            );
          }).toList();
        });
  }

  // Partnership methods
  Future<void> createPartnership(Partnership partnership) async {
    try {
      await _firestore
          .collection('partnerships')
          .doc(partnership.id)
          .set({
            'user1Id': partnership.user1Id,
            'user2Id': partnership.user2Id,
            'startDate': partnership.startDate.toIso8601String(),
            'endDate': partnership.endDate.toIso8601String(),
          });
      
      // Update both users with partner IDs
      await _firestore.collection('users').doc(partnership.user1Id).update({
        'partnerId': partnership.user2Id,
      });
      
      await _firestore.collection('users').doc(partnership.user2Id).update({
        'partnerId': partnership.user1Id,
      });
    } catch (e) {
      print('Error creating partnership: $e');
    }
  }

  Future<void> deletePartnership(String partnershipId, String user1Id, String user2Id) async {
    try {
      // Delete partnership
      await _firestore.collection('partnerships').doc(partnershipId).delete();
      
      // Delete all messages
      final messages = await _firestore
          .collection('messages')
          .where('partnershipId', isEqualTo: partnershipId)
          .get();
      
      for (var doc in messages.docs) {
        await doc.reference.delete();
      }
      
      // Update users to remove partner IDs
      await _firestore.collection('users').doc(user1Id).update({
        'partnerId': null,
      });
      
      await _firestore.collection('users').doc(user2Id).update({
        'partnerId': null,
      });
    } catch (e) {
      print('Error deleting partnership: $e');
    }
  }

  /// Fetches a partnership for a user from Firestore (by user1Id or user2Id)
  Future<Partnership?> getPartnershipForUser(String userId) async {
    // Try user1Id
    final snapshot = await _firestore.collection('partnerships')
        .where('user1Id', isEqualTo: userId)
        .get();
    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      data['id'] = snapshot.docs.first.id; // Ensure ID is set
      return Partnership.fromMap(data);
    }
    // Try user2Id
    final snapshot2 = await _firestore.collection('partnerships')
        .where('user2Id', isEqualTo: userId)
        .get();
    if (snapshot2.docs.isNotEmpty) {
      final data = snapshot2.docs.first.data();
      data['id'] = snapshot2.docs.first.id; // Ensure ID is set
      return Partnership.fromMap(data);
    }
    return null;
  }
} 