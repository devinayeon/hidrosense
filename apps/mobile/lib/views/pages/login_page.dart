import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../widgets/row_button.dart';
import '../theme/app_theme.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _hidePassword = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(sessionProvider).busy) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    await ref
        .read(sessionProvider.notifier)
        .login(_username.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    return Scaffold(
      backgroundColor: AppColors.canvasWarm,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xxl,
            ),
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
                          color: AppColors.primaryMint.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.borderAccent,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.spa_rounded,
                          size: 38,
                          color: AppColors.primaryDarkTeal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'HidroSense',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                        letterSpacing: -0.5,
                        color: AppColors.darkNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Monitoring & Manajemen Budidaya Hidroponik',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 36),
                    _inputField(
                      controller: _username,
                      label: 'Nama Pengguna',
                      hintText: 'Masukkan username',
                      icon: Icons.person_outline_rounded,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                      enabled: !session.busy,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Username tidak boleh kosong'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _inputField(
                      controller: _password,
                      label: 'Kata Sandi',
                      hintText: 'Masukkan kata sandi',
                      icon: Icons.lock_outline_rounded,
                      focusNode: _passwordFocus,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      isPassword: true,
                      enabled: !session.busy,
                      validator: (v) => v == null || v.isEmpty
                          ? 'Kata sandi tidak boleh kosong'
                          : null,
                    ),
                    if (session.error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.dangerBg,
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          border: Border.all(color: AppColors.dangerRed),
                        ),
                        child: Text(
                          session.error!,
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.dangerRed,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    RowButton(
                      label: session.busy ? 'Memproses...' : 'Masuk',
                      height: 52,
                      borderRadius: 26,
                      backgroundColor: AppColors.darkNavy,
                      textColor: AppColors.accentLime,
                      onTap: session.busy ? null : _submit,
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
    FocusNode? focusNode,
    required TextInputAction textInputAction,
    required ValueChanged<String> onFieldSubmitted,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderLight, width: 1.2),
          ),
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            focusNode: focusNode,
            textInputAction: textInputAction,
            onFieldSubmitted: onFieldSubmitted,
            obscureText: isPassword && _hidePassword,
            validator: validator,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 14,
              color: Colors.black,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 20, color: AppColors.textTertiary),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: AppColors.textTertiary,
                      ),
                      onPressed: enabled
                          ? () => setState(() => _hidePassword = !_hidePassword)
                          : null,
                    )
                  : null,
              hintText: hintText,
              hintStyle: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
