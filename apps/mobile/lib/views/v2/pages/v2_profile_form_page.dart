import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/validators.dart';
import '../../../data/services/api_client.dart';
import '../../../features/accounts/data/models/profile_model.dart';
import '../../../features/accounts/data/repositories/profile_repository.dart';
import '../../../viewmodels/session_viewmodel.dart';
import '../components/v2_akun_action_bar.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_dialog.dart';
import '../widgets/v2_text_field.dart';

/// Ubah profil sendiri: mirip frame `3.12 Ubah pegawai`, dengan tambahan
/// isian "Password saat ini" karena backend mewajibkannya saat username atau
/// password diganti.
///
/// Password baru yang sama dengan password lama ditolak sebelum dikirim dan
/// juga dijaga backend (`PASSWORD_UNCHANGED`). Mengubah username/password
/// mencabut semua sesi server, jadi aplikasi kembali ke layar masuk.
class V2ProfileFormPage extends ConsumerStatefulWidget {
  const V2ProfileFormPage({super.key, required this.initial});

  final ProfileModel initial;

  static Route<ProfileModel> route({required ProfileModel initial}) {
    return MaterialPageRoute<ProfileModel>(
      builder: (_) => V2ProfileFormPage(initial: initial),
    );
  }

  @override
  ConsumerState<V2ProfileFormPage> createState() => _V2ProfileFormPageState();
}

class _V2ProfileFormPageState extends ConsumerState<V2ProfileFormPage> {
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _currentPassword;
  late final TextEditingController _password;
  late final TextEditingController _phone;
  late final TextEditingController _address;

  String? _nameError;
  String? _usernameError;
  String? _currentPasswordError;
  String? _passwordError;
  String? _phoneError;
  String? _addressError;

  /// Menandai isian sudah disentuh, supaya tombol kembali meminta konfirmasi.
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial.nama);
    _username = TextEditingController(text: initial.username);
    _currentPassword = TextEditingController();
    _password = TextEditingController();
    _phone = TextEditingController(text: initial.noTelepon ?? '');
    _address = TextEditingController(text: initial.alamat ?? '');

    for (final controller in [
      _name,
      _username,
      _currentPassword,
      _password,
      _phone,
      _address,
    ]) {
      controller.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _currentPassword.dispose();
    _password.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  /// Membersihkan pesan galat begitu isiannya diperbaiki.
  void _markDirty() {
    final nama = _nameError != null && _name.text.trim().isNotEmpty;
    final pengguna =
        _usernameError != null && _username.text.trim().isNotEmpty;
    final sandiKini =
        _currentPasswordError != null && _currentPassword.text.isNotEmpty;
    final sandiBaru =
        _passwordError != null &&
        passwordProblem(_password.text, optional: true) == null;
    final telp = _phoneError != null && phoneProblem(_phone.text.trim()) == null;
    final alamat =
        _addressError != null && addressProblem(_address.text.trim()) == null;
    if (_dirty &&
        !nama &&
        !pengguna &&
        !sandiKini &&
        !sandiBaru &&
        !telp &&
        !alamat) {
      return;
    }
    setState(() {
      _dirty = true;
      if (nama) _nameError = null;
      if (pengguna) _usernameError = null;
      if (sandiKini) _currentPasswordError = null;
      if (sandiBaru) _passwordError = null;
      if (telp) _phoneError = null;
      if (alamat) _addressError = null;
    });
  }

  void _pop() {
    _dirty = false;
    Navigator.of(context).pop();
  }

  Future<void> _confirmDiscard() async {
    final discard = await showV2Dialog(
      context,
      type: V2DialogType.destructive,
      title: 'Buang perubahan?',
      body: 'Isian yang diubah akan hilang.',
      primaryLabel: 'Buang',
      secondaryLabel: 'Lanjut isi',
    );
    if (discard == true && mounted) _pop();
  }

  void _back() {
    if (!_dirty) {
      _pop();
      return;
    }
    _confirmDiscard();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final name = _name.text.trim();
    final username = _username.text.trim();
    final currentPassword = _currentPassword.text;
    final newPassword = _password.text;
    final phone = _phone.text.trim();
    final address = _address.text.trim();

    final usernameChanged = username != widget.initial.username;
    final passwordChanged = newPassword.isNotEmpty;
    final credentialChange = usernameChanged || passwordChanged;

    var passwordError = passwordProblem(newPassword, optional: true);
    if (passwordError == null &&
        passwordChanged &&
        newPassword == currentPassword) {
      passwordError = 'Password baru tidak boleh sama dengan password lama';
    }

    setState(() {
      _nameError = name.isEmpty ? 'Isi nama' : null;
      _usernameError = username.isEmpty ? 'Isi username' : null;
      _passwordError = passwordError;
      _currentPasswordError = credentialChange && currentPassword.isEmpty
          ? 'Isi password saat ini'
          : null;
      _phoneError = phoneProblem(phone);
      _addressError = addressProblem(address);
    });

    if (_nameError != null ||
        _usernameError != null ||
        _passwordError != null ||
        _currentPasswordError != null ||
        _phoneError != null ||
        _addressError != null) {
      return;
    }

    final repository = ref.read(profileRepositoryProvider);
    ProfileModel? updated;
    try {
      final done = await showV2ActionDialog(
        context,
        title: 'Simpan perubahan profil?',
        body: credentialChange
            ? 'Username atau password berubah. Kamu akan diminta masuk lagi.'
            : 'Data profil baru akan dikirim ke server.',
        primaryLabel: 'Simpan',
        onConfirm: () async {
          updated = await repository.updateProfile(
            nama: name,
            username: usernameChanged ? username : null,
            password: passwordChanged ? newPassword : null,
            currentPassword: currentPassword.isEmpty ? null : currentPassword,
            email: widget.initial.email,
            noTelepon: phone,
            alamat: address,
          );
        },
      );
      if (!mounted || !done) return;
    } on ApiException catch (error) {
      if (!mounted) return;
      _handleApiError(error);
      return;
    } catch (error) {
      if (!mounted) return;
      _snack(serviceError(error));
      return;
    }

    final result = updated;
    if (!mounted || result == null) return;
    if (credentialChange) {
      await _returnToLogin();
      return;
    }
    ref
        .read(sessionProvider.notifier)
        .updateIdentity(name: result.nama, username: result.username);
    Navigator.of(context).pop(result);
  }

  void _handleApiError(ApiException error) {
    switch (error.code) {
      case 'CURRENT_PASSWORD_INVALID':
        setState(() => _currentPasswordError = 'Password saat ini tidak sesuai');
      case 'PASSWORD_UNCHANGED':
        setState(
          () => _passwordError =
              'Password baru tidak boleh sama dengan password lama',
        );
      case 'USERNAME_TAKEN':
        setState(() => _usernameError = 'Username sudah dipakai');
      case 'EMAIL_TAKEN':
        _snack('Email sudah digunakan akun lain');
      case 'ACCOUNT_CHANGED':
        _snack('Akun berubah di perangkat lain. Muat ulang, lalu ulangi.');
      default:
        _snack(serviceError(error));
    }
  }

  /// Server mencabut semua sesi setelah username/password berubah, jadi token
  /// di perangkat ini sudah mati. Kembali ke layar masuk, bukan memakai token
  /// basi.
  Future<void> _returnToLogin() async {
    await showV2Dialog(
      context,
      title: 'Kredensial diperbarui',
      body: 'Masuk kembali dengan username dan password baru.',
      primaryLabel: 'Masuk',
    );
    if (!mounted) return;
    await ref.read(sessionProvider.notifier).clearLocalSession();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: V2Theme.light,
      child: PopScope<ProfileModel>(
        canPop: !_dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _back();
        },
        child: Scaffold(
          backgroundColor: V2Colors.canvas,
          // Footer dipaku di dasar layar; keyboard tidak menggeser tombol
          // Simpan dan isian tetap bisa digulir di atasnya.
          bottomNavigationBar: V2AkunActionBar(
            safeBottom: true,
            actions: [V2Button(label: 'Simpan', onPressed: _save)],
          ),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                V2AppBar(title: 'Ubah profil', onBack: _back),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(
                      V2Space.xl,
                      V2Space.sm,
                      V2Space.xl,
                      V2Space.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        V2TextField(
                          label: 'Nama lengkap',
                          hint: 'Contoh: Sari Dewi',
                          controller: _name,
                          error: _nameError,
                        ),
                        const SizedBox(height: V2Space.lg),
                        V2TextField(
                          label: 'Username',
                          hint: 'Contoh: sari.dewi',
                          controller: _username,
                          error: _usernameError,
                        ),
                        const SizedBox(height: V2Space.lg),
                        V2PasswordField(
                          label: 'Password saat ini (opsional)',
                          hint: 'Isi bila mengubah username/password',
                          controller: _currentPassword,
                          error: _currentPasswordError,
                        ),
                        const SizedBox(height: V2Space.lg),
                        V2PasswordField(
                          label: 'Password baru (opsional)',
                          hint: 'Kosongkan jika tetap',
                          controller: _password,
                          error: _passwordError,
                        ),
                        const SizedBox(height: V2Space.lg),
                        V2TextField(
                          label: 'Telepon (opsional)',
                          hint: '08xx xxxx xxxx',
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          error: _phoneError,
                        ),
                        const SizedBox(height: V2Space.lg),
                        V2TextField(
                          label: 'Alamat (opsional)',
                          hint: 'Jalan dan kota',
                          controller: _address,
                          error: _addressError,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}