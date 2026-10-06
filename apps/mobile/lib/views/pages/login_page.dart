import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/session_viewmodel.dart';

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
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.eco_outlined,
                      size: 56,
                      color: Color(0xFF168681),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'HidroSense',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Masuk untuk melihat inventaris dan saldo stok.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _username,
                      enabled: !session.busy,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Masukkan username.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      enabled: !session.busy,
                      obscureText: _hidePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _hidePassword
                              ? 'Tampilkan password'
                              : 'Sembunyikan password',
                          onPressed: session.busy
                              ? null
                              : () => setState(
                                  () => _hidePassword = !_hidePassword,
                                ),
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Masukkan password.'
                          : null,
                    ),
                    if (session.error != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          session.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: session.busy ? null : _submit,
                      child: Text(session.busy ? 'Memproses...' : 'Masuk'),
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
}
