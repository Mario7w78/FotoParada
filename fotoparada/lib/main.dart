import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Espera a que Firebase restaure la sesión guardada antes de decidir la ruta.
  final user = await FirebaseAuth.instance.authStateChanges().first;

  runApp(
    FotoParadaApp(
      initialRoute: user != null ? AppRoutes.main : AppRoutes.login,
    ),
  );
}

class FotoParadaApp extends StatelessWidget {
  const FotoParadaApp({super.key, required this.initialRoute});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FotoParada',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        scaffoldBackgroundColor: const Color(0xFFEAF7FC),
        useMaterial3: true,
      ),
      initialRoute: initialRoute,
      routes: AppRoutes.routes,
    );
  }
}
