import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../components/inventaris_body.dart';
import '../components/penyemaian_body.dart';
import '../components/penjualan_body.dart';
import '../components/header.dart';
import '../components/dashboard_body.dart';
import '../components/custom_bottom_navigation_bar.dart';

class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  // Mengembalikan judul header berdasarkan index aktif
  String get _headerTitle {
    switch (_selectedIndex) {
      case 1:
        return 'Daftar Inventaris';
      case 2:
        return 'Daftar Penyemaian';
      case 3:
        return 'Penjualan';
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
    final canReadSales =
        ref
            .watch(sessionProvider)
            .user
            ?.permissions
            .contains('penjualan:read') ??
        false;
    final pages = [
      DashboardBody(onInventoryTap: () => _onItemTapped(1)),
      const InventarisBody(),
      const PenyemaianBody(),
      if (canReadSales) const PenjualanBody(),
    ];
    if (_selectedIndex < 0 || _selectedIndex >= pages.length) {
      _selectedIndex = 0;
    }
    return Scaffold(
      appBar: _selectedIndex == 1
          ? const InventoryHeader()
          : Header(titleText: _headerTitle, largeTitle: _selectedIndex == 0),
      body: pages[_selectedIndex],
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Inventaris',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.eco_outlined),
            activeIcon: Icon(Icons.eco),
            label: 'Semaian',
          ),
          if (canReadSales)
            const BottomNavigationBarItem(
              icon: Icon(Icons.point_of_sale_outlined),
              activeIcon: Icon(Icons.point_of_sale),
              label: 'Penjualan',
            ),
        ],
      ),
    );
  }
}
