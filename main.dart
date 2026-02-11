import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'auth_service.dart';
import 'auth_screen.dart';
import 'dashboard.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const CrookWatchApp());
}

class CrookWatchApp extends StatelessWidget {
  const CrookWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: "CrookWatch",
      home: AuthService().currentUser == null
          ? const AuthScreen()
          : DashboardScreen(),
    );
  }
}
