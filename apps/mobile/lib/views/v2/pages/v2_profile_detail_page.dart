import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/accounts/data/models/profile_model.dart';
import '../../../features/accounts/data/repositories/profile_repository.dart';
import '../../../viewmodels/session_viewmodel.dart';
import '../components/v2_akun_action_bar.dart';
import '../components/v2_akun_employee.dart';
import '../components/v2_akun_info_card.dart';
import '../components/v2_akun_profil_card.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_badge.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_dialog.dart';
import 'v2_profile_form_page.dart';

/// Detail profil akun sendiri, dibuka dari menu "Akun saya" pada tab
/// "Lainnya" (petani) atau "Profil" (pegawai).
///
/// Susunannya sama dengan frame `3.11 Detail pegawai`: kartu profil, kartu
/// info akun, lalu "Ubah". Tombol "Nonaktifkan" hanya muncul untuk pegawai
/// (`profil:deactivate`), karena petani tidak boleh menonaktifkan akunnya
/// sendiri.
class V2ProfileDetailPage extends ConsumerStatefulWidget {
  const V2ProfileDetailPage({
    super.key,
    required this.profile,
    this.canDeactivate = false,
  });

  final ProfileModel profile;

  /// Diisi `true` hanya untuk pegawai yang boleh menonaktifkan akun sendiri.
  final bool canDeactivate;

  static Route<ProfileModel> route({
    required ProfileModel profile,
    bool canDeactivate = false,
  }) {
    return MaterialPageRoute<ProfileModel>(
      builder: (_) => V2ProfileDetailPage(
        profile: profile,
        canDeactivate: canDeactivate,
      ),
    );
  }

  @override
  ConsumerState<V2ProfileDetailPage> createState() =>
      _V2ProfileDetailPageState();
}

class _V2ProfileDetailPageState extends ConsumerState<V2ProfileDetailPage> {
  late ProfileModel _profile = widget.profile;
  Timer? _toastTimer;
  String? _toast;

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
    final updated = await Navigator.of(context).push<ProfileModel>(
      V2ProfileFormPage.route(initial: _profile),
    );
    if (updated == null || !mounted) return;
    setState(() => _profile = updated);
    _showToast('Perubahan tersimpan');
  }

  Future<void> _confirmDeactivate() async {
    try {
      final done = await showV2ActionDialog(
        context,
        type: V2DialogType.destructive,
        title: 'Nonaktifkan akun?',
        body:
            'Akun ini tidak bisa masuk lagi. Hubungi petani untuk mengaktifkan kembali.',
        primaryLabel: 'Nonaktifkan',
        secondaryLabel: 'Batal',
        onConfirm: () async {
          await ref.read(profileRepositoryProvider).deactivateSelf();
        },
      );
      if (!mounted || !done) return;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(serviceError(error))));
      return;
    }
    // Sesi server ikut dicabut saat akun dinonaktifkan; kembali ke layar masuk.
    await ref.read(sessionProvider.notifier).clearLocalSession();
  }

  String _value(String? text) {
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? '-' : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final active = _profile.statusAktif == 1;
    final email = _value(_profile.email);
    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              V2AppBar(
                title: 'Profil',
                onBack: () => Navigator.of(context).pop(),
              ),
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
                        initials: v2InitialsOf(_profile.nama),
                        name: _profile.nama,
                        role: _profile.role == 'pegawai' ? 'Pegawai' : 'Petani',
                        badge: active
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
                            value: _profile.username,
                          ),
                          if (email != '-')
                            V2AkunInfoRow(label: 'Email', value: email),
                          V2AkunInfoRow(
                            label: 'Telepon',
                            value: _value(_profile.noTelepon),
                          ),
                          V2AkunInfoRow(
                            label: 'Alamat',
                            value: _value(_profile.alamat),
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
                  if (widget.canDeactivate && active)
                    V2Button(
                      label: 'Nonaktifkan',
                      type: V2ButtonType.destructive,
                      onPressed: _confirmDeactivate,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}