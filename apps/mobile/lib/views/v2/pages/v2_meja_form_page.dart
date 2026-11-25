import 'package:flutter/material.dart';

import '../components/v2_meja_data.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_dialog.dart';
import '../widgets/v2_text_field.dart';

/// Form "Tambah meja" (frame 6.6/6.7) dan "Ubah meja" (6.18/6.19), plus
/// dialog konflik data (6.30).
///
/// Tiga isian tetap: kode meja, jumlah lubang, dan keterangan opsional. Galat
/// menambah baris pesan 28 di bawah field tanpa mengubah jarak antarbagian
/// (frame 6.7/6.19). Pada mode ubah, catatan "Status diubah lewat Ubah status."
/// duduk 16 di bawah isian terakhir.
class V2MejaFormPage extends StatefulWidget {
  const V2MejaFormPage({
    super.key,
    this.meja,
    this.takenCodes = const <String>{},
    this.previewValidation = false,
    this.previewLubangKurang = false,
    this.previewKonflik = false,
  });

  /// Frame `6.6 Tambah meja`.
  const V2MejaFormPage.create({super.key})
    : meja = null,
      takenCodes = const <String>{},
      previewValidation = false,
      previewLubangKurang = false,
      previewKonflik = false;

  /// Frame `6.7 Tambah meja, validasi`: kode sudah dipakai dan jumlah 0.
  const V2MejaFormPage.validation({super.key})
    : meja = null,
      takenCodes = const <String>{},
      previewValidation = true,
      previewLubangKurang = false,
      previewKonflik = false;

  /// Frame `6.18 Ubah meja`: Meja A2 terisi 240 lubang.
  V2MejaFormPage.ubah({super.key})
    : meja = designMejaA2,
      takenCodes = const <String>{},
      previewValidation = false,
      previewLubangKurang = false,
      previewKonflik = false;

  /// Frame `6.19 Ubah meja, lubang kurang`: 30 lubang, minimal 40.
  V2MejaFormPage.lubangKurang({super.key})
    : meja = designMejaA2,
      takenCodes = const <String>{},
      previewValidation = false,
      previewLubangKurang = true,
      previewKonflik = false;

  /// Frame `6.30 Data sudah berubah`: dialog konflik di atas form ubah.
  V2MejaFormPage.konflik({super.key})
    : meja = designMejaA2,
      takenCodes = const <String>{},
      previewValidation = false,
      previewLubangKurang = false,
      previewKonflik = true;

  /// Meja yang diubah; null berarti form tambah.
  final V2MejaItem? meja;

  /// Kode meja yang sudah ada di server (huruf besar). Digunakan untuk
  /// menolak duplikat sebelum form ditutup, supaya isian lain tidak hilang
  /// dan tidak perlu diisi ulang dari awal (K-14).
  final Set<String> takenCodes;

  /// Kode terisi "A2" dan dua field pertama menyala galat (frame 6.7).
  final bool previewValidation;

  /// Jumlah 30 dengan galat "Minimal 40, ada 40 tanaman aktif" (frame 6.19).
  final bool previewLubangKurang;

  /// Dialog "Data sudah berubah" tampil saat halaman dibuka (frame 6.30).
  final bool previewKonflik;

  static Route<V2MejaItem> route({
    V2MejaItem? meja,
    Set<String> takenCodes = const <String>{},
  }) {
    return MaterialPageRoute<V2MejaItem>(
      builder: (_) => V2MejaFormPage(meja: meja, takenCodes: takenCodes),
    );
  }

  @override
  State<V2MejaFormPage> createState() => _V2MejaFormPageState();
}

class _V2MejaFormPageState extends State<V2MejaFormPage> {
  late final TextEditingController _kode = TextEditingController(
    text: widget.meja?.kode ?? (widget.previewValidation ? 'A2' : ''),
  );
  late final TextEditingController _lubang = TextEditingController(
    text: widget.previewValidation
        ? '0'
        : widget.previewLubangKurang
        ? '30'
        : widget.meja?.jumlahLubang.toString() ?? '',
  );
  late final TextEditingController _keterangan = TextEditingController(
    text: widget.meja?.keterangan ?? '',
  );

  String? _kodeError;
  String? _lubangError;
  String? _keteranganError;
  late bool _showKonflik = widget.previewKonflik;

  bool get _ubah => widget.meja != null;

  @override
  void initState() {
    super.initState();
    if (widget.previewValidation) {
      _kodeError = 'Kode meja sudah dipakai';
      _lubangError = 'Isi angka lebih dari 0';
    }
    if (widget.previewLubangKurang) {
      final aktif = widget.meja?.tanaman.fold<int>(
        0,
        (total, tanaman) => total + tanaman.jumlahAktif,
      );
      _lubangError = 'Minimal ${aktif ?? 40}, ada ${aktif ?? 40} tanaman aktif';
    }
    // Pesan galat hanya berlaku untuk nilai yang barusan dikirim. Begitu
    // pengguna memperbaiki isian, pesan harus hilang tanpa menekan Simpan lagi
    // (K-15).
    _kode.addListener(_clearKodeError);
    _lubang.addListener(_clearLubangError);
    _keterangan.addListener(_clearKeteranganError);
  }

  void _clearKodeError() {
    if (_kodeError != null) setState(() => _kodeError = null);
  }

  void _clearLubangError() {
    if (_lubangError != null) setState(() => _lubangError = null);
  }

  void _clearKeteranganError() {
    if (_keteranganError != null) setState(() => _keteranganError = null);
  }

  @override
  void dispose() {
    _kode.dispose();
    _lubang.dispose();
    _keterangan.dispose();
    super.dispose();
  }

  void _simpan() {
    final kode = _kode.text.trim().toUpperCase();
    final lubang = int.tryParse(_lubang.text.trim()) ?? 0;

    // Duplikat yang sudah kelihatan dari daftar meja ditolak di sini, sebelum
    // form ditutup, supaya isian tidak hilang (K-14). Server tetap penentu
    // akhir untuk kode yang belum termuat di daftar.
    final kodeSudahDipakai =
        widget.takenCodes.contains(kode) &&
        (!_ubah || widget.meja!.kode.trim().toUpperCase() != kode);

    setState(() {
      _kodeError = kode.isEmpty
          ? 'Isi kode meja'
          : kode.length > 30
          ? 'Maksimal 30 karakter'
          : kodeSudahDipakai
          ? 'Kode meja sudah dipakai'
          : null;
      _lubangError = lubang <= 0
          ? 'Isi angka lebih dari 0'
          : lubang > 1000
          ? 'Maksimal 1.000 lubang'
          : null;
      _keteranganError = _keterangan.text.trim().length > 1000
          ? 'Maksimal 1.000 karakter'
          : null;
    });
    if (_kodeError != null ||
        _lubangError != null ||
        _keteranganError != null) {
      return;
    }

    final meja =
        widget.meja ??
        V2MejaItem(
          kode: kode,
          jumlahLubang: lubang,
          terisi: 0,
          status: V2MejaStatus.tersedia,
        );
    Navigator.of(context).pop(
      meja.copyWith(
        kode: kode,
        jumlahLubang: lubang,
        keterangan: _keterangan.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  V2AppBar(
                    title: _ubah ? 'Ubah meja' : 'Tambah meja',
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
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
                            label: 'Kode meja',
                            hint: 'Contoh: A2',
                            controller: _kode,
                            error: _kodeError,
                          ),
                          const SizedBox(height: V2Space.lg),
                          V2TextField(
                            label: 'Jumlah lubang',
                            hint: 'Contoh: 240 (maksimal 1.000)',
                            controller: _lubang,
                            keyboardType: TextInputType.number,
                            error: _lubangError,
                          ),
                          const SizedBox(height: V2Space.lg),
                          V2TextField(
                            label: 'Keterangan (opsional)',
                            hint: 'Contoh: dekat pintu',
                            controller: _keterangan,
                            error: _keteranganError,
                          ),
                          if (_ubah &&
                              _kodeError == null &&
                              _lubangError == null &&
                              _keteranganError == null) ...[
                            const SizedBox(height: V2Space.lg),
                            Text(
                              'Status diubah lewat Ubah status.',
                              style: V2Type.label.copyWith(
                                color: V2Colors.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  V2ActionBar(
                    actions: [V2Button(label: 'Simpan', onPressed: _simpan)],
                  ),
                ],
              ),
              if (_showKonflik) _konflikLayer(),
            ],
          ),
        ),
      ),
    );
  }

  /// Lapisan gelap dan dialog konflik data (frame 6.30); dialog 342x308 duduk
  /// tepat di tengah layar.
  Widget _konflikLayer() {
    return Positioned.fill(
      child: ColoredBox(
        color: V2Colors.ink.withValues(alpha: 0.6),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
            child: V2Dialog(
              title: 'Data sudah berubah',
              body:
                  'Data ini baru diubah di perangkat lain. Muat ulang untuk '
                  'melihat versi terbaru, lalu ubah lagi.',
              primaryLabel: 'Muat ulang',
              onPrimary: () => setState(() => _showKonflik = false),
              secondaryLabel: 'Batal',
              onSecondary: () => setState(() => _showKonflik = false),
            ),
          ),
        ),
      ),
    );
  }
}
