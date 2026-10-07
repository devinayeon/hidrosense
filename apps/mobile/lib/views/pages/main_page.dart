import 'package:flutter/material.dart';
import 'package:hidrosense_mobile/views/components/inventaris_body.dart';
import 'package:hidrosense_mobile/views/components/penyemaian_body.dart'; // Import baru
import '../components/header.dart';
import '../components/dashboard_body.dart';
import '../components/custom_bottom_navigation_bar.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  final List<Widget> _pages = const [
    DashboardBody(),
    InventarisBody(),
    PenyemaianBody(), // Menggunakan widget PenyemaianBody
  ];

  // Mengembalikan judul header berdasarkan index aktif
  String get _headerTitle {
    switch (_selectedIndex) {
      case 1:
        return 'Daftar Inventaris';
      case 2:
        return 'Daftar Penyemaian';
      case 0:
      default:
        return 'HidroSense';
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Header(titleText: _headerTitle, largeTitle: _selectedIndex == 0),
      body: _pages[_selectedIndex],
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
