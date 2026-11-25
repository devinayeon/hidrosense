import 'package:flutter/material.dart';

import 'v2_meja_connected.dart';
import 'v2_panen_connected.dart';
import 'v2_semaian_connected.dart';

/// Tab Tanam dengan tiga segmen desain (Semaian/Meja/Panen) yang semuanya
/// membaca dan menulis ke backend.
///
/// Galeri tetap memakai tiap `*TabView` sendiri per frame; halaman beranda
/// tersambung memakai pembungkus ini supaya ketiga segmen bisa dibuka.
class V2TanamConnectedTab extends StatefulWidget {
  const V2TanamConnectedTab({super.key});

  @override
  State<V2TanamConnectedTab> createState() => _V2TanamConnectedTabState();
}

class _V2TanamConnectedTabState extends State<V2TanamConnectedTab> {
  int _segmen = 0;

  void _pilihSegmen(int index) {
    if (index == _segmen) return;
    setState(() => _segmen = index);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_segmen) {
      1 => V2MejaConnectedTab(onSegmentChanged: _pilihSegmen),
      2 => V2PanenConnectedTab(onSegmentChanged: _pilihSegmen),
      _ => V2SemaianConnectedTab(onSegmentChanged: _pilihSegmen),
    };
  }
}
