import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/v2_auth_assets.dart';
import '../components/v2_onboarding_slide.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_pagination.dart';
import 'v2_login_page.dart';

/// Alur pembuka aplikasi: splash lalu tiga layar perkenalan.
///
/// Frame FigCraft: `1.1 Splash`, `1.2–1.4 Welcome`. Splash berpindah sendiri
/// ke Welcome 1; tiap layar punya Lanjut dan (kecuali layar terakhir) Lewati.
///
/// Hanya ilustrasi + teks yang ada di dalam [PageView]. Pagination dan tombol
/// berada di luar pager supaya saat digulir tidak ikut tergeser: pagination
/// bermorfosis antar-indeks, sedangkan tombol hanya beranimasi kalau
/// susunannya berubah (Lanjut/Lewati tetap, Masuk memudar masuk).
class V2OnboardingPage extends StatefulWidget {
  const V2OnboardingPage({super.key, this.initialSlide = 0, this.onLogin});

  /// 0 = splash, 1–3 = Welcome 1–3. Dipakai saat kembali dari login ke 1.4.
  final int initialSlide;

  /// Diteruskan ke [V2LoginPage]. kosong = cabang demo pratinjau.
  final V2LoginHandler? onLogin;

  static Route<void> route({int initialSlide = 0, V2LoginHandler? onLogin}) {
    return MaterialPageRoute<void>(
      builder: (_) =>
          V2OnboardingPage(initialSlide: initialSlide, onLogin: onLogin),
    );
  }

  @override
  State<V2OnboardingPage> createState() => _V2OnboardingPageState();
}

class _V2OnboardingPageState extends State<V2OnboardingPage> {
  static const Duration _splashDelay = Duration(milliseconds: 1600);
  static const Duration _switcherDuration = Duration(milliseconds: 260);

  /// Tinggi area teks terbesar (judul 36 + jarak 16 + badan 48).
  static const double _textAreaHeight = 100;

  late final PageController _controller;
  late int _index;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _index = widget.initialSlide.clamp(0, 3);
    _controller = PageController(initialPage: _index);
    if (_index == 0) {
      _splashTimer = Timer(_splashDelay, () => _animateTo(1));
    }
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _cancelSplashTimer() {
    _splashTimer?.cancel();
    _splashTimer = null;
  }

  Future<void> _animateTo(int page) async {
    _cancelSplashTimer();
    // Perbarui indeks lebih dulu supaya pagination dan tombol ikut berganti
    // tanpa menunggu `onPageChanged` (mis. saat splash auto-lanjut).
    if (_index != page) setState(() => _index = page);
    if (!_controller.hasClients) return;
    await _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  /// Membuka login. Kalau pengguna menekan Kembali di login, onboarding
  /// kembali ke Welcome 3 (alur `1.7 → 1.4`).
  Future<void> _openLogin() async {
    final result = await Navigator.of(
      context,
    ).push<bool>(V2LoginPage.route(onLogin: widget.onLogin));
    if (!mounted || result != true) return;
    await _animateTo(3);
  }

  List<Widget> _slides(double heroHeight) {
    return [
      V2OnboardingSlide(
        illustration: V2AuthAssets.splash,
        title: 'HidroSense',
        body: 'Kebun selada NFT, rapi.',
        titleStyle: V2Type.display,
        heroHeight: heroHeight,
      ),
      V2OnboardingSlide(
        illustration: V2AuthAssets.welcomeStock,
        title: 'Stok tertata',
        body: 'Catat benih, nutrisi, obat. Stok berkurang otomatis.',
        titleStyle: V2Type.h1,
        heroHeight: heroHeight,
      ),
      V2OnboardingSlide(
        illustration: V2AuthAssets.welcomeCycle,
        title: 'Semai sampai panen',
        body: '60 hari dalam satu layar. Pantau HSS tiap meja.',
        titleStyle: V2Type.h1,
        heroHeight: heroHeight,
      ),
      V2OnboardingSlide(
        illustration: V2AuthAssets.welcomeWeather,
        title: 'Hama dan cuaca',
        body: 'Petani dapat saran hama dan cuaca BMKG.',
        titleStyle: V2Type.h1,
        heroHeight: heroHeight,
      ),
    ];
  }

  Widget _pagination() {
    return SizedBox(
      height: 24,
      child: Padding(
        padding: const EdgeInsets.only(top: V2Space.lg),
        child: AnimatedSwitcher(
          duration: _switcherDuration,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: _index == 0
              ? const SizedBox.shrink(key: ValueKey('pagination-off'))
              : V2Pagination(
                  key: const ValueKey('pagination-on'),
                  count: 3,
                  index: _index - 1,
                ),
        ),
      ),
    );
  }

  /// Transisi satu slot tombol: gambar lama memudar keluar sambil turun,
  /// gambar baru memudar masuk dari bawah.
  Widget _buttonSwitcher(Widget child) {
    return AnimatedSwitcher(
      duration: _switcherDuration,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }

  Widget _actions() {
    final (String? primary, String? secondary) = switch (_index) {
      1 || 2 => ('Lanjut', 'Lewati'),
      3 => ('Masuk', null),
      _ => (null, null),
    };

    // Kedua slot selalu memesan tinggi (56 dan 48) supaya tombol utama tidak
    // bergeser saat tombol kedua muncul/hilang. Di desain, tombol utama tetap
    // di y690 baik di 1.2 (Lanjut + Lewati) maupun 1.4 (Masuk saja).
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        V2Space.xl,
        V2Space.xl,
        V2Space.xl,
        V2Space.xxxl + 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buttonSwitcher(
            primary == null
                ? const SizedBox(key: ValueKey('primary-none'), height: 56)
                : V2Button(
                    // Kunci dari label: Lanjut → Lanjut tidak beranimasi,
                    // Lanjut → Masuk memudar di tempat yang sama.
                    key: ValueKey('primary-$primary'),
                    label: primary,
                    onPressed: primary == 'Masuk'
                        ? _openLogin
                        : () => _animateTo(_index + 1),
                  ),
          ),
          const SizedBox(height: V2Space.sm),
          _buttonSwitcher(
            secondary == null
                ? const SizedBox(key: ValueKey('secondary-none'), height: 48)
                : V2Button(
                    key: ValueKey('secondary-$secondary'),
                    label: secondary,
                    type: V2ButtonType.ghost,
                    onPressed: _openLogin,
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
          ),
          child: SafeArea(
            top: false,
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final heroHeight = constraints.maxHeight >= 760
                    ? 460.0
                    : math.max(330.0, constraints.maxHeight * 0.545);

                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: heroHeight + _textAreaHeight,
                            child: PageView(
                              controller: _controller,
                              onPageChanged: (page) {
                                _cancelSplashTimer();
                                setState(() => _index = page);
                              },
                              children: _slides(heroHeight),
                            ),
                          ),
                          _pagination(),
                          const Spacer(),
                          _actions(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
