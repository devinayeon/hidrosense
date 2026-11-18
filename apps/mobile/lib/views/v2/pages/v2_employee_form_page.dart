import 'package:flutter/material.dart';

import '../components/v2_akun_action_bar.dart';
import '../components/v2_akun_employee.dart';
import '../components/v2_akun_employee_store.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_dialog.dart';
import '../widgets/v2_text_field.dart';

/// Form akun pegawai: frame 3.7 (tambah), 3.8 (validasi), 3.12 (ubah),
/// 3.9 (konfirmasi buang perubahan), dan 3.13 (data sudah berubah).
///
/// Satu halaman menangani tambah dan ubah karena desainnya sama; yang berbeda
/// hanya judul dan label password. Hasil simpan dikembalikan sebagai
/// [V2Employee] lewat `Navigator.pop`. Kalau [store] diisi, tombol Simpan
/// mengirim ke backend dan galat server ditampilkan sebagai snackbar.
class V2EmployeeFormPage extends StatefulWidget {
  const V2EmployeeFormPage({
    super.key,
    this.initial,
    this.takenUsernames = const <String>{},
    this.previewValidation = false,
    this.previewConflict = false,
    this.previewDiscard = false,
    this.store,
  });

  /// Frame `3.7 Tambah pegawai`.
  const V2EmployeeFormPage.create({
    super.key,
    this.takenUsernames = const <String>{},
    this.store,
  }) : initial = null,
       previewValidation = false,
       previewConflict = false,
       previewDiscard = false;

  /// Frame `3.8 Tambah pegawai, validasi`.
  const V2EmployeeFormPage.validation({super.key})
    : initial = null,
      takenUsernames = const <String>{'sari.dewi'},
      previewValidation = true,
      previewConflict = false,
      previewDiscard = false,
      store = null;

  /// Frame `3.12 Ubah pegawai`.
  const V2EmployeeFormPage.edit(
    V2Employee employee, {
    super.key,
    this.takenUsernames = const <String>{},
    this.store,
  }) : initial = employee,
       previewValidation = false,
       previewConflict = false,
       previewDiscard = false;

  /// Frame `3.13 Data sudah berubah`.
  const V2EmployeeFormPage.conflict(
    V2Employee employee, {
    super.key,
    this.takenUsernames = const <String>{},
  }) : initial = employee,
       store = null,
       previewValidation = false,
       previewConflict = true,
       previewDiscard = false;

  /// Frame `3.9 Buang perubahan, konfirmasi`.
  const V2EmployeeFormPage.discard(
    V2Employee employee, {
    super.key,
    this.takenUsernames = const <String>{},
  }) : initial = employee,
       store = null,
       previewValidation = false,
       previewConflict = false,
       previewDiscard = true;

  /// Data awal; null berarti menambah pegawai baru.
  final V2Employee? initial;

  /// Username yang sudah dipakai pegawai lain (huruf kecil).
  final Set<String> takenUsernames;

  final bool previewValidation;
  final bool previewConflict;
  final bool previewDiscard;

  /// Backend akun; null berarti mode pratinjau (hanya di memori).
  final V2EmployeeStore? store;

  bool get isEdit => initial != null;

  static Route<V2Employee> route({
    V2Employee? initial,
    Set<String> takenUsernames = const <String>{},
    V2EmployeeStore? store,
  }) {
    return MaterialPageRoute<V2Employee>(
      builder: (_) => V2EmployeeFormPage(
        initial: initial,
        takenUsernames: takenUsernames,
        store: store,
      ),
    );
  }

  @override
  State<V2EmployeeFormPage> createState() => _V2EmployeeFormPageState();
}

class _V2EmployeeFormPageState extends State<V2EmployeeFormPage> {
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _phone;
  late final TextEditingController _address;

  String? _nameError;
  String? _usernameError;
  String? _passwordError;

  /// Menandai isian sudah disentuh, supaya tombol kembali meminta konfirmasi.
  bool _dirty = false;

  /// Sedang mengirim ke backend.
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final validation = widget.previewValidation;

    _name = TextEditingController(
      text: validation ? '' : initial?.name ?? '',
    );
    _username = TextEditingController(
      text: validation ? 'sari.dewi' : initial?.username ?? '',
    );
    _password = TextEditingController(text: validation ? 'rahasia' : '');
    _phone = TextEditingController(text: initial?.phone ?? '');
    _address = TextEditingController(text: initial?.address ?? '');

    for (final controller in [_name, _username, _password, _phone, _address]) {
      controller.addListener(_markDirty);
    }

    if (validation) {
      _dirty = true;
      _nameError = 'Isi nama';
      _usernameError = 'Username sudah dipakai';
      _passwordError = 'Minimal 12 karakter';
    }

    if (widget.previewConflict) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showConflict());
    }
    if (widget.previewDiscard) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _confirmDiscard(),
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _password.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  void _resetToInitial() {
    final initial = widget.initial;
    _dirty = false;
    _name.text = initial?.name ?? '';
    _username.text = initial?.username ?? '';
    _password.clear();
    _phone.text = initial?.phone ?? '';
    _address.text = initial?.address ?? '';
    setState(() {
      _nameError = null;
      _usernameError = null;
      _passwordError = null;
    });
  }

  Future<void> _showConflict() async {
    final confirmed = await showV2Dialog(
      context,
      title: 'Data sudah berubah',
      body: 'Pegawai lain baru mengubah data ini. Muat ulang, lalu ulangi '
          'perubahan.',
      primaryLabel: 'Muat ulang',
      secondaryLabel: 'Batal',
    );
    if (confirmed == true && mounted) _resetToInitial();
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

  void _pop() {
    _dirty = false;
    Navigator.of(context).pop();
  }

  void _back() {
    if (!_dirty) {
      _pop();
      return;
    }
    _confirmDiscard();
  }

  void _save() {
    FocusScope.of(context).unfocus();

    final name = _name.text.trim();
    final username = _username.text.trim();
    final password = _password.text;
    final ownUsername = widget.initial?.username.toLowerCase();

    setState(() {
      _nameError = name.isEmpty ? 'Isi nama' : null;
      _usernameError = username.isEmpty
          ? 'Isi username'
          : (username.toLowerCase() != ownUsername &&
                    widget.takenUsernames.contains(username.toLowerCase())
                ? 'Username sudah dipakai'
                : null);
      if (widget.isEdit) {
        _passwordError = password.isNotEmpty && password.length < 12
            ? 'Minimal 12 karakter'
            : null;
      } else {
        _passwordError = switch (password) {
          '' => 'Isi password',
          _ when password.length < 12 => 'Minimal 12 karakter',
          _ => null,
        };
      }
    });

    if (_nameError != null ||
        _usernameError != null ||
        _passwordError != null) {
      return;
    }

    final store = widget.store;
    if (store == null) {
      _popWithPreview(name, username, password);
      return;
    }
    _submitToStore(store, name, username, password);
  }

  /// Mode pratinjau: hasil dirangkai di memori, tanpa backend.
  void _popWithPreview(String name, String username, String password) {
    _dirty = false;
    Navigator.of(context).pop(
      V2Employee(
        id: widget.initial?.id ?? 'emp-${username.toLowerCase()}',
        name: name,
        username: username,
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        active: widget.initial?.active ?? true,
      ),
    );
  }

  Future<void> _submitToStore(
    V2EmployeeStore store,
    String name,
    String username,
    String password,
  ) async {
    setState(() => _saving = true);
    final draft = V2EmployeeDraft(
      name: name,
      username: username,
      password: password.isEmpty ? null : password,
      phone: _phone.text.trim(),
      address: _address.text.trim(),
    );
    try {
      final result = widget.isEdit
          ? await store.update(widget.initial!.id, draft)
          : await store.create(draft);
      if (!mounted) return;
      _dirty = false;
      Navigator.of(context).pop(result);
    } on V2EmployeeStoreException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: V2Theme.light,
      child: PopScope<V2Employee>(
        canPop: !_dirty && !_saving,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _back();
        },
        child: Scaffold(
          backgroundColor: V2Colors.canvas,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                V2AppBar(
                  title: widget.isEdit ? 'Ubah pegawai' : 'Tambah pegawai',
                  onBack: _back,
                ),
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
                          label: widget.isEdit
                              ? 'Password baru (opsional)'
                              : 'Password',
                          hint: widget.isEdit
                              ? 'Kosongkan jika tetap'
                              : 'Minimal 12 karakter',
                          controller: _password,
                          error: _passwordError,
                        ),
                        const SizedBox(height: V2Space.lg),
                        V2TextField(
                          label: 'Telepon (opsional)',
                          hint: '08xx xxxx xxxx',
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: V2Space.lg),
                        V2TextField(
                          label: 'Alamat (opsional)',
                          hint: 'Jalan dan kota',
                          controller: _address,
                        ),
                      ],
                    ),
                  ),
                ),
                V2AkunActionBar(
                  safeBottom: true,
                  actions: [
                    V2Button(
                      label: 'Simpan',
                      state: _saving
                          ? V2ButtonState.loading
                          : V2ButtonState.normal,
                      onPressed: _saving ? null : _save,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
