import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Already initialized — safe to ignore
  }
  
  runApp(const DealDiveApp());
}

class DealDiveApp extends StatelessWidget {
  const DealDiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DealDive',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF00C4E6),
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00C4E6),
        ),
      ),
      home: const AuthGate(),
    );
  }
}