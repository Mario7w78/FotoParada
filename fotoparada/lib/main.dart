import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';

void main() async {
  // Aseguramos que los widgets estén inicializados antes de arrancar Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializamos Firebase con las opciones generadas por la CLI
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const FotoParadaApp());
}

class FotoParadaApp extends StatelessWidget {
  const FotoParadaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FotoParada',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // La app inicia pidiendo credenciales
      home: const LoginScreen(),
    );
  }
}
