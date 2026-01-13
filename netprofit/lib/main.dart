import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // This will be generated after 'flutterfire configure'
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const RukmalFishApp());
}

class RukmalFishApp extends StatelessWidget {
  const RukmalFishApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rukmal Fish Delivery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      home: SplashScreen(),
    );
  }
}