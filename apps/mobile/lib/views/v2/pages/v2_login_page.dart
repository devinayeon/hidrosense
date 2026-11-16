import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/v2_login_brand.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_text_field.dart';
import 'v2_inactive_account_page.dart';
import 'v2_notification_permission_page.dart';
import 'v2_offline_login_page.dart';

/// Hasil percobaan masuk pada alur demo v2.
enum V2LoginOutcome { success, wrongPassword, inactiveAccount, offline }

/// Pengganti proses autentikasi sungguhan saat halaman dipakai untuk pratinjau.
typedef V2LoginHandler =
    Future<V2LoginOutcome> Function(String username, String password);

/// Halaman masuk dari frame `1.5 Login kosong`, `1.6 Login terisi`,
/// `1.7 Login salah`, dan `1.5a Login kosong dikirim`.
///
/// Halaman ini belum memanggil backend. Tanpa [onLogin], username tertentu
/// memicu cabang alur supaya semua status bisa direview:
/// `nonaktif` (1.8), `offline` (1.9), `salah` (1.7); username lain berhasil.
class V2LoginPage extends StatefulWidget {
  const V2LoginPage({super.key, this.onLogin});

  final V2LoginHandler? onLogin;

  static Route<bool> route({V2LoginHandler? onLogin}) {
    return MaterialPageRoute<bool>(
      builder: (_) => V2LoginPage(onLogin: onLogin),
    );
  }

  @override
  State<V2LoginPage> createState() => _V2LoginPageState();
}

class _V2LoginPageState extends State<V2LoginPage> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();

  String? _usernameError;
  String? _passwordError;
  String? _credentialError;
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<V2LoginOutcome> _demoLogin(String username, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return switch (username.toLowerCase()) {
      'nonaktif' => V2LoginOutcome.inactiveAccount,
      'offline' => V2LoginOutcome.offline,
      'salah' => V2LoginOutcome.wrongPassword,
      _ => V2LoginOutcome.success,
    };
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final username = _username.text.trim();
    final password = _password.text;
    setState(() {
      _usernameError = username.isEmpty ? 'Isi username' : null;
      _passwordError = password.isEmpty ? 'Isi password' : null;
      _credentialError = null;
    });
    if (_usernameError != null || _passwordError != null) return;

    setState(() => _busy = true);
    final outcome = await (widget.onLogin ?? _demoLogin)(username, password);
    if (!mounted) return;
    setState(() => _busy = false);

    switch (outcome) {
      case V2LoginOutcome.success:
        Navigator.of(
          context,
        ).pushReplacement(V2NotificationPermissionPage.route());
      case V2LoginOutcome.wrongPassword:
        setState(() => _credentialError = 'Username atau password salah');
      case V2LoginOutcome.inactiveAccount:
        Navigator.of(context).push(V2InactiveAccountPage.route());
      case V2LoginOutcome.offline:
        Navigator.of(context).push(V2OfflineLoginPage.route());
    }
  }

  void _back() => Navigator.of(context).maybePop(true);

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                V2AppBar(title: '', onBack: _back),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(
                      V2Space.xl,
                      0,
                      V2Space.xl,
                      V2Space.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const V2LoginBrand(),
                        const SizedBox(height: V2Space.lg),
                        V2TextField(
                          label: 'Username',
                          hint: 'Ketik username',
                          controller: _username,
                          error: _usernameError,
                          enabled: !_busy,
                        ),
                        const SizedBox(height: V2Space.lg),
                        V2PasswordField(
                          controller: _password,
                          error: _passwordError ?? _credentialError,
                          enabled: !_busy,
                        ),
                        const SizedBox(height: V2Space.lg),
                        Text(
                          'Lupa password? Hubungi petani.',
                          style: V2Type.label.copyWith(color: V2Colors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    V2Space.xl,
                    0,
                    V2Space.xl,
                    keyboardVisible ? V2Space.lg : V2Space.xxxl + 2,
                  ),
                  child: V2Button(
                    label: 'Masuk',
                    state: _busy ? V2ButtonState.loading : V2ButtonState.normal,
                    onPressed: _busy ? null : _submit,
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
