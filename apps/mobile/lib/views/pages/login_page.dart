import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/widgets/login_header_hero.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../theme/app_theme.dart';
import '../v2/pages/v2_login_page.dart';
import '../v2/pages/v2_onboarding_page.dart';
import '../v2/v2_ui_mode.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  static const _logoAsset = 'assets/logo/hidrosense-miaw.png';
  static const _introDuration = Duration(milliseconds: 280);
  static const _logoSize = 80.0;
  static const _minimumWordmarkWidth = 160.0;
  // The supplied PNG has a black margin around the rounded artwork.
  static const _logoCropScale = 1.28;

  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  late final AnimationController _intro;
  late final Animation<double> _introFade;
  late final Animation<double> _logoScale;
  bool _introStarted = false;
  bool _hidePassword = true;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: _introDuration);
    _introFade = _intro.drive(CurveTween(curve: Curves.easeOutCubic));
    _logoScale = _introFade.drive(Tween(begin: 0.96, end: 1.0));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
      _introStarted = true;
    } else if (!_introStarted) {
      _introStarted = true;
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _username.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(sessionProvider).busy) return;
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    // Form lama = alur v1. Ditandai sebelum menunggu layanan supaya AppGate
    // tidak sempat membangun beranda v2 saat sesi baru terpasang.
    ref.read(v2UiModeProvider.notifier).state = false;
    await ref
        .read(sessionProvider.notifier)
        .login(_username.text.trim(), _password.text);
    if (mounted && ref.read(sessionProvider).user != null) {
      TextInput.finishAutofillContext();
    }
  }

  /// Login sungguhan untuk halaman v2: memakai `SessionViewModel` yang sama
  /// dengan form lama, lalu menerjemahkan kegagalannya ke layar alur v2
  /// (1.7 salah, 1.8 akun nonaktif, 1.9 perlu internet).
  ///
  /// Alur v2 ditandai **sebelum** menunggu layanan. Begitu sesi terpasang,
  /// `AppGate` mengganti seluruh layar dan melepas halaman ini — kalau mode
  /// disetel setelah `login()` selesai, penandaannya tidak pernah terjadi dan
  /// pengguna mendarat di beranda v1. Karena itu sisa pekerjaan memakai
  /// `ProviderContainer` yang dipegang di awal, bukan `ref` milik halaman.
  /// Kalau login gagal, penanda dikembalikan (halaman masih hidup karena sesi
  /// masih kosong).
  Future<V2LoginResult> _v2Login(String username, String password) async {
    final container = ProviderScope.containerOf(context, listen: false);
    container.read(v2UiModeProvider.notifier).state = true;
    await container.read(sessionProvider.notifier).login(username, password);
    final session = container.read(sessionProvider);
    if (session.user != null) return const V2LoginResult.success();
    container.read(v2UiModeProvider.notifier).state = false;
    return switch (session.failure) {
      SessionFailure.invalidCredentials => const V2LoginResult(
        V2LoginOutcome.rejected,
      ),
      SessionFailure.accountDeactivated => const V2LoginResult(
        V2LoginOutcome.inactiveAccount,
      ),
      SessionFailure.offline => const V2LoginResult(V2LoginOutcome.offline),
      // Sisa kegagalan (mis. kuota permintaan) ditampilkan apa adanya.
      _ => V2LoginResult(V2LoginOutcome.rejected, message: session.error),
    };
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final canvas = isDark ? scheme.surface : AppColors.canvasWarm;
    final ink = isDark ? scheme.onSurface : AppColors.darkNavy;
    final secondary = isDark
        ? scheme.onSurfaceVariant
        : AppColors.textSecondary;
    final accent = isDark ? AppColors.primaryMint : AppColors.primaryDarkTeal;

    return Scaffold(
      backgroundColor: canvas,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LoginHeaderHero(),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: AppSpacing.xxl),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: AutofillGroup(
                        onDisposeAction: AutofillContextAction.cancel,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FadeTransition(
                                opacity: _introFade,
                                child: _brand(ink, secondary, accent),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              Semantics(
                                header: true,
                                child: Text(
                                  'Selamat datang\nkembali.',
                                  style: AppTypography.title1.copyWith(
                                    color: ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Masuk untuk memantau dan merawat kebun hidroponik Anda.',
                                style: AppTypography.subheadline.copyWith(
                                  color: secondary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              _inputField(
                                controller: _username,
                                label: 'Nama Pengguna',
                                hintText: 'Masukkan username',
                                icon: CupertinoIcons.person,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) =>
                                    _passwordFocus.requestFocus(),
                                enabled: !session.busy,
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Username tidak boleh kosong'
                                    : null,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _inputField(
                                controller: _password,
                                label: 'Kata Sandi',
                                hintText: 'Masukkan kata sandi',
                                icon: CupertinoIcons.lock,
                                focusNode: _passwordFocus,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                isPassword: true,
                                enabled: !session.busy,
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Kata sandi tidak boleh kosong'
                                    : null,
                              ),
                              if (session.error != null) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Semantics(
                                  liveRegion: true,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ExcludeSemantics(
                                        child: Icon(
                                          CupertinoIcons
                                              .exclamationmark_circle_fill,
                                          size: 20,
                                          color: scheme.error,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Expanded(
                                        child: Text(
                                          session.error!,
                                          style: AppTypography.footnote
                                              .copyWith(color: scheme.error),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.xl),
                              FilledButton(
                                onPressed: session.busy ? null : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.darkNavy,
                                  foregroundColor: AppColors.accentLime,
                                  disabledBackgroundColor: AppColors.darkNavy,
                                  disabledForegroundColor: AppColors.accentLime,
                                  minimumSize: const Size.fromHeight(56),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xl,
                                    vertical: AppSpacing.md,
                                  ),
                                  shape: RoundedSuperellipseBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.card,
                                    ),
                                  ),
                                  textStyle: AppTypography.headline,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (session.busy) ...[
                                      const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.accentLime,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                    ],
                                    Flexible(
                                      child: Text(
                                        session.busy ? 'Memproses...' : 'Masuk',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              TextButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  V2OnboardingPage.route(onLogin: _v2Login),
                                ),
                                icon: const Icon(
                                  Icons.auto_awesome_outlined,
                                  size: 18,
                                ),
                                label: const Text('Coba tampilan v2'),
                                style: TextButton.styleFrom(
                                  foregroundColor: accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _brand(Color ink, Color secondary, Color accent) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wordmarkWidth =
            constraints.maxWidth >=
                MediaQuery.textScalerOf(context).scale(_minimumWordmarkWidth) +
                    _logoSize +
                    AppSpacing.md
            ? constraints.maxWidth - _logoSize - AppSpacing.md
            : constraints.maxWidth;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ExcludeSemantics(
              child: ScaleTransition(
                scale: _logoScale,
                child: ClipRSuperellipse(
                  borderRadius: BorderRadius.circular(AppRadius.modal),
                  child: SizedBox.square(
                    dimension: _logoSize,
                    child: Transform.scale(
                      scale: _logoCropScale,
                      child: Image.asset(
                        _logoAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: AppColors.accentMintSoft,
                          child: Center(
                            child: Text('H', style: AppTypography.title1),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: wordmarkWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Hidro',
                          style: TextStyle(color: ink),
                        ),
                        TextSpan(
                          text: 'Sense',
                          style: TextStyle(color: accent),
                        ),
                      ],
                    ),
                    semanticsLabel: 'HidroSense',
                    style: AppTypography.title2.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Monitoring & Manajemen\nBudidaya Hidroponik',
                    style: AppTypography.footnote.copyWith(color: secondary),
                  ),
                ],
              ),
            ),
          ],
        );
      },
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final ink = isDark ? scheme.onSurface : AppColors.darkNavy;
    final secondary = isDark
        ? scheme.onSurfaceVariant
        : AppColors.textSecondary;
    final accent = isDark ? AppColors.primaryMint : AppColors.primaryDarkTeal;
    final shape = BorderRadius.circular(AppRadius.input);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            style: AppTypography.subheadline.copyWith(
              color: ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          label: label,
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            focusNode: focusNode,
            textInputAction: textInputAction,
            onFieldSubmitted: onFieldSubmitted,
            autofillHints: [
              isPassword ? AutofillHints.password : AutofillHints.username,
            ],
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            obscureText: isPassword && _hidePassword,
            validator: validator,
            style: AppTypography.body.copyWith(color: ink),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark
                  ? scheme.surfaceContainerHighest
                  : AppColors.cardSurface,
              prefixIcon: ExcludeSemantics(
                child: Icon(icon, size: 20, color: secondary),
              ),
              suffixIcon: isPassword
                  ? IconButton(
                      tooltip: _hidePassword
                          ? 'Tampilkan kata sandi'
                          : 'Sembunyikan kata sandi',
                      icon: Icon(
                        _hidePassword
                            ? CupertinoIcons.eye
                            : CupertinoIcons.eye_slash,
                        size: 20,
                        color: secondary,
                      ),
                      onPressed: enabled
                          ? () => setState(() => _hidePassword = !_hidePassword)
                          : null,
                    )
                  : null,
              hintText: hintText,
              hintStyle: AppTypography.callout.copyWith(color: secondary),
              errorStyle: AppTypography.footnote.copyWith(color: scheme.error),
              errorMaxLines: 3,
              border: OutlineInputBorder(borderRadius: shape),
              enabledBorder: OutlineInputBorder(
                borderRadius: shape,
                borderSide: BorderSide(color: scheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: shape,
                borderSide: BorderSide(color: accent, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
