import 'package:flutter/material.dart';
import 'package:fotoparada/viewmodel/map_viewmodel.dart';

import 'collections_view.dart';
import 'feed_view.dart';
import 'Map/map_home_view.dart';
import 'profile_view.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  int _currentIndex = 0;

  // MainView es el dueño del viewmodel del mapa: lo crea y lo libera.
  final MapViewModel _mapViewModel = MapViewModel();

  late final List<Widget> _views = [
    MapHomeView(mapViewModel: _mapViewModel),
    const FeedView(),
    const CollectionsView(),
    const ProfileView(),
  ];

  @override
  void dispose() {
    _mapViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack mantiene vivas todas las pestañas al cambiar entre ellas.
      body: IndexedStack(index: _currentIndex, children: _views),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Abriendo cámara para hacer Check-in...')),
          );
        },
        backgroundColor: Colors.blue,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNavItem(
                    icon: Icons.map_outlined,
                    activeIcon: Icons.map,
                    label: 'Mapa',
                    index: 0,
                  ),
                  _buildNavItem(
                    icon: Icons.grid_view_outlined,
                    activeIcon: Icons.grid_view,
                    label: 'Explorar',
                    index: 1,
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNavItem(
                    icon: Icons.bookmark_outline,
                    activeIcon: Icons.bookmark,
                    label: 'Guardado',
                    index: 2,
                  ),
                  _buildNavItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: 'Perfil',
                    index: 3,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    return MaterialButton(
      minWidth: 80,
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
