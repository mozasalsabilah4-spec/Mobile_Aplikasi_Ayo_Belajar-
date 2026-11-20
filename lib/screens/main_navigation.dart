import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'add_card_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // (BARU) layar "Progres Hafalan" dihapus, tersisa Beranda dan Buat Kartu
  final List<Widget> _screens = [
    const HomeScreen(),
    const AddCardScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF6C5CE7),
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: 'Buat Kartu'),
          // (BARU) tombol "Progres" dihapus
        ],
      ),
    );
  }
}