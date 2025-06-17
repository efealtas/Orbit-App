import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'services/storage_service.dart';
import 'services/firebase_service.dart';
import 'screens/auth_screen.dart';
import 'screens/main_layout.dart';
import 'utils/cleanup_users.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initializeFirebase();

  // Run the cleanup before starting the app
  await cleanupNonFirebaseUsers();

  runApp(const MyApp());
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyDEnOUt9zIoK9rKAnIgHnUhiKRCFOOfOtw',
        appId: '1:777761980180:android:28bdfde0e7df1576574c01',
        messagingSenderId: '777761980180',
        projectId: 'orbit-111cc',
        storageBucket: 'orbit-111cc.appspot.com',
      ),
    );
    debugPrint('✅ Firebase initialized');
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      debugPrint('ℹ️ Firebase already initialized');
    } else {
      debugPrint('❌ Error initializing Firebase: $e');
      rethrow;
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StorageService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Orbit',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const AuthScreen(),
      ),
    );
  }
}
