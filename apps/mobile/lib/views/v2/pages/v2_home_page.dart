import 'package:flutter/material.dart';

import '../components/v2_home_empty_state.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_tab_bar.dart';
import 'v2_meja_form_page.dart';

/// Frame `1.11 Beranda kosong (Petani)`.
///
/// Petani yang baru masuk belum punya meja tanam. Isi layar berupa sapaan,
/// checklist tiga langkah, tombol tambah meja, dan tab bar dengan Beranda aktif.
class V2HomePage extends StatelessWidget {
  const V2HomePage({super.key, this.onAddTable, this.onOpenNotifications});

  final VoidCallback? onAddTable;
  final VoidCallback? onOpenNotifications;

  static Route<void> route({
    VoidCallback? onAddTable,
    VoidCallback? onOpenNotifications,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => V2HomePage(
        onAddTable: onAddTable,
        onOpenNotifications: onOpenNotifications,
      ),
    );
  }

  static const List<V2TabItem> _tabs = [
    V2TabItem(label: 'Beranda', icon: V2IconName.home),
    V2TabItem(label: 'Tanam', icon: V2IconName.sprout),
    V2TabItem(label: 'Stok', icon: V2IconName.box),
    V2TabItem(label: 'Rawat', icon: V2IconName.care),
    V2TabItem(label: 'Lainnya', icon: V2IconName.more),
  ];

  void _addTable(BuildContext context) {
    if (onAddTable != null) {
      onAddTable!();
      return;
    }
    Navigator.of(context).push(V2MejaFormPage.route());
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    V2Space.xl,
                    V2Space.lg,
                    V2Space.xl,
                    V2Space.lg,
                  ),
                  child: V2HomeEmptyState(
                    onOpenNotifications: onOpenNotifications,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  V2Space.xl,
                  0,
                  V2Space.xl,
                  V2Space.xl,
                ),
                child: V2Button(
                  label: 'Tambah meja tanam',
                  onPressed: () => _addTable(context),
                ),
              ),
              const V2TabBar(items: _tabs, activeIndex: 0),
            ],
          ),
        ),
      ),
    );
  }
}
