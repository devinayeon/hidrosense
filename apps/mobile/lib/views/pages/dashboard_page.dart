import 'package:flutter/material.dart';
import '../components/dashboard_header.dart';
import '../components/dashboard_body.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    DashboardBody(),
    Center(child: Text("Halaman Inventaris")),
    Center(child: Text("Halaman Semaian")),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    const activeColor = Color.fromRGBO(57, 198, 195, 1);
    const inactiveColor = Colors.grey;

    return Scaffold(
      appBar: const DashboardHeader(),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color.fromRGBO(255, 255, 255, 1),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: activeColor,
        unselectedItemColor: inactiveColor,
        selectedLabelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 12,
        ),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined), // Icon tipe chest/pot
            activeIcon: Icon(Icons.inventory_2),
            label: 'Inventaris',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.eco_outlined), // Icon daun
            activeIcon: Icon(Icons.eco),
            label: 'Semaian',
          ),
        ],
      ),
    );
  }
}