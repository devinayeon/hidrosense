import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../widgets/row_button.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(sessionProvider).busy || !_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    await ref
        .read(sessionProvider.notifier)
        .login(_username.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(57, 198, 195, 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color.fromRGBO(57, 198, 195, 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.spa_rounded,
                          size: 38,
                          color: Color.fromRGBO(22, 134, 129, 1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'HidroSense',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                        letterSpacing: -0.5,
                        color: Color.fromRGBO(23, 34, 49, 1),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Monitoring & Manajemen Budidaya Hidroponik',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Color.fromRGBO(107, 114, 128, 1),
                      ),
                    ),
                    const SizedBox(height: 36),
                    _inputField(
                      controller: _username,
                      label: 'Nama Pengguna',
                      hintText: 'Masukkan username',
                      icon: Icons.person_outline_rounded,
                      enabled: !session.busy,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Username tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 16),
                    _inputField(
                      controller: _password,
                      label: 'Kata Sandi',
                      hintText: 'Masukkan kata sandi',
                      icon: Icons.lock_outline_rounded,
                      isPassword: true,
                      enabled: !session.busy,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Kata sandi tidak boleh kosong' : null,
                    ),
                    if (session.error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(254, 242, 242, 1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color.fromRGBO(252, 165, 165, 1),
                          ),
                        ),
                        child: Text(
                          session.error!,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color.fromRGBO(220, 38, 38, 1),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    RowButton(
                      label: session.busy ? 'Memproses...' : 'Masuk',
                      height: 52,
                      borderRadius: 26,
                      backgroundColor: const Color.fromRGBO(23, 34, 49, 1),
                      textColor: const Color.fromRGBO(221, 244, 90, 1),
                      onTap: session.busy ? () {} : _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Color.fromRGBO(55, 65, 81, 1),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color.fromRGBO(229, 231, 235, 1), width: 1.2),
          ),
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            obscureText: isPassword && _hidePassword,
            validator: validator,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Colors.black),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 20, color: const Color.fromRGBO(156, 163, 175, 1)),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        _hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 20,
                        color: const Color.fromRGBO(156, 163, 175, 1),
                      ),
                      onPressed: () => setState(() => _hidePassword = !_hidePassword),
                    )
                  : null,
              hintText: hintText,
              hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color.fromRGBO(156, 163, 175, 1)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
