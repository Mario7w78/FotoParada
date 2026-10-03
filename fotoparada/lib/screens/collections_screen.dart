import 'package:flutter/material.dart';

class CollectionsScreen extends StatelessWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Colecciones'),
        centerTitle: true,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.collections_bookmark, size: 100, color: Colors.blueGrey),
            SizedBox(height: 20),
            Text(
              'Tus lugares y fotos guardadas',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
