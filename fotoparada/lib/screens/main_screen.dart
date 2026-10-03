import 'package:flutter/material.dart';
import 'map_screen.dart';
import 'feed_screen.dart'; // Usaremos el feed actual como pestaña "Explorar"
import 'collections_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Lista de las pantallas a mostrar según la pestaña seleccionada
  final List<Widget> _screens = [
    const MapScreen(),
    const FeedScreen(),
    const CollectionsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // El cuerpo principal cambia según el índice actual
      body: _screens[_currentIndex],
      
      // Botón flotante central (Nuestra acción principal: Check-in / Subir Foto)
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Aquí en el futuro abriremos la cámara o seleccionaremos foto
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('📸 Abriendo cámara para hacer Check-in...')),
          );
        },
        backgroundColor: Colors.blue,
        shape: const CircleBorder(), // Lo hacemos perfectamente redondo
        elevation: 4,
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
      // Posiciona el botón en el centro de la barra inferior
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      
      // Barra de navegación inferior
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(), // Crea el hueco para el botón flotante
        notchMargin: 8.0,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Grupo de botones a la izquierda
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNavItem(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Mapa', index: 0),
                  _buildNavItem(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view, label: 'Explorar', index: 1),
                ],
              ),
              // Grupo de botones a la derecha
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNavItem(icon: Icons.bookmark_outline, activeIcon: Icons.bookmark, label: 'Guardado', index: 2),
                  _buildNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Perfil', index: 3),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Método ayudante para construir cada pestaña de navegación
  Widget _buildNavItem({required IconData icon, required IconData activeIcon, required String label, required int index}) {
    final isSelected = _currentIndex == index;
    return MaterialButton(
      minWidth: 80, // Asegura que los botones tengan buen espacio táctil
      onPressed: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? Colors.blue : Colors.grey,
          ),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.blue : Colors.grey,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
