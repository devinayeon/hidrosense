import 'dart:async';

import 'package:flutter/material.dart';

import '../components/v2_akun_action_bar.dart';
import '../components/v2_akun_employee.dart';
import '../components/v2_akun_employee_store.dart';
import '../components/v2_akun_info_card.dart';
import '../components/v2_akun_profil_card.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_badge.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_dialog.dart';
import 'v2_employee_form_page.dart';

/// Detail pegawai: frame 3.11 (aktif), 3.17 (nonaktif), 3.15 (dialog
/// nonaktifkan), dan 3.14 (notifikasi "Perubahan tersimpan" setelah ubah).
///
/// Dua tombol saat pegawai masih aktif (Ubah + Nonaktifkan); pegawai nonaktif
/// dapat diaktifkan kembali lewat tombol "Aktifkan" (D-36) di samping "Ubah".
/// Saat [store] diisi, ubah/nonaktifkan/aktifkan dikirim ke backend.
class V2EmployeeDetailPage extends StatefulWidget {
  const V2EmployeeDetailPage({
    super.key,
    required this.employee,
    this.confirmDeactivate = false,
    this.store,
  });

  final V2Employee employee;

  /// Membuka halaman dengan dialog nonaktifkan sudah tampil (frame 3.15).
  final bool confirmDeactivate;

  /// Backend akun; null berarti mode pratinjau (hanya di memori).
  final V2EmployeeStore? store;

  static Route<V2EmployeeResult> route(
    V2Employee employee, {
    bool confirmDeactivate = false,
    V2EmployeeStore? store,
  }) {
    return MaterialPageRoute<V2EmployeeResult>(
      builder: (_) => V2EmployeeDetailPage(
        employee: employee,
        confirmDeactivate: confirmDeactivate,
        store: store,
      ),
    );
  }

  @override
  State<V2EmployeeDetailPage> createState() => _V2EmployeeDetailPageState();
}

class _V2EmployeeDetailPageState extends State<V2EmployeeDetailPage> {
  late V2Employee _employee = widget.employee;
  Timer? _toastTimer;
  String? _toast;

  /// Data berubah; tombol kembali mengembalikannya ke daftar.
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    if (widget.confirmDeactivate) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _confirmDeactivate());
    }
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<V2Employee>(
      V2EmployeeFormPage.route(
        initial: _employee,
        takenUsernames: {_employee.username.toLowerCase()},
        store: widget.store,
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _employee = updated;
      _changed = true;
    });
    _showToast('Perubahan tersimpan');
  }

  Future<void> _confirmDeactivate() async {
    final store = widget.store;
    if (store == null) {
      final confirmed = await showV2Dialog(
        context,
        type: V2DialogType.destructive,
        title: 'Nonaktifkan ${_employee.firstName}?',
        body:
            '${_employee.firstName} tidak bisa masuk lagi. Data tetap tersimpan.',
        primaryLabel: 'Nonaktifkan',
        secondaryLabel: 'Batal',
      );
      if (confirmed != true || !mounted) return;
      Navigator.of(
        context,
      ).pop(V2EmployeeDeactivated(_employee.copyWith(active: false)));
      return;
    }

    V2Employee? updated;
    try {
      final done = await showV2ActionDialog(
        context,
        type: V2DialogType.destructive,
        title: 'Nonaktifkan ${_employee.firstName}?',
        body:
            '${_employee.firstName} tidak bisa masuk lagi. Data tetap tersimpan.',
        primaryLabel: 'Nonaktifkan',
        secondaryLabel: 'Batal',
        onConfirm: () async {
          updated = await store.deactivate(_employee.id);
        },
      );
      if (!mounted || !done) return;
    } on V2EmployeeStoreException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    Navigator.of(context).pop(V2EmployeeDeactivated(updated!));
  }

  void _back() {
    if (_changed) {
      Navigator.of(context).pop(V2EmployeeSaved(_employee));
      return;
    }
    Navigator.of(context).maybePop();
  }

  /// Mengaktifkan kembali pegawai nonaktif (D-36).
  ///
  /// Ikut memakai pop-up konfirmasi dan loading di tombolnya supaya aksi tulis
  /// ke server tidak berjalan tanpa persetujuan ulang (Sesi 9).
  Future<void> _activate() async {
    final store = widget.store;
    if (store == null) {
      Navigator.of(
        context,
      ).pop(V2EmployeeActivated(_employee.copyWith(active: true)));
      return;
    }

    V2Employee? updated;
    try {
      final done = await showV2ActionDialog(
        context,
        title: 'Aktifkan ${_employee.firstName}?',
        body: '${_employee.firstName} bisa masuk lagi setelah diaktifkan.',
        primaryLabel: 'Aktifkan',
        secondaryLabel: 'Batal',
        onConfirm: () async {
          updated = await store.activate(_employee.id);
        },
      );
      if (!mounted || !done) return;
    } on V2EmployeeStoreException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    Navigator.of(context).pop(V2EmployeeActivated(updated!));
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
              V2AppBar(title: 'Detail pegawai', onBack: _back),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    V2Space.xl,
                    V2Space.sm,
                    V2Space.xl,
                    V2Space.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      V2AkunProfilCard(
                        initials: _employee.initials,
                        name: _employee.name,
                        badge: _employee.active
                            ? const V2Badge(
                                label: 'Aman',
                                status: V2BadgeStatus.success,
                              )
                            : const V2Badge(
                                label: 'Kosong',
                                status: V2BadgeStatus.neutral,
                              ),
                      ),
                      const SizedBox(height: V2Space.lg),
                      V2AkunInfoCard(
                        rows: [
                          V2AkunInfoRow(
                            label: 'Username',
                            value: _employee.username,
                          ),
                          V2AkunInfoRow(
                            label: 'Telepon',
                            value: _employee.phone,
                          ),
                          V2AkunInfoRow(
                            label: 'Alamat',
                            value: _employee.address,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              V2AkunActionBar(
                safeBottom: true,
                toast: _toast,
                actions: [
                  V2Button(
                    label: 'Ubah',
                    type: V2ButtonType.secondary,
                    onPressed: _edit,
                  ),
                  if (_employee.active)
                    V2Button(
                      label: 'Nonaktifkan',
                      type: V2ButtonType.destructive,
                      onPressed: _confirmDeactivate,
                    )
                  else
                    V2Button(label: 'Aktifkan', onPressed: _activate),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
