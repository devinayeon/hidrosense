import 'dart:async';

import 'package:flutter/material.dart';

import '../components/v2_meja_data.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_list_item.dart';
import '../widgets/v2_text_field.dart';
import 'v2_tanaman_rusak_page.dart';

/// Detail satu baris tanaman di meja (frame 6.21 dan 6.23).
///
/// Kartu ringkasan biru memperlihatkan HST, bilah umur menuju panen HST 45,
/// lalu tanggal panen. Kartu putih di bawahnya memuat jumlah tanaman aktif dan
/// tanggal pindah dari semaian. Baris "Tanaman rusak" membuka daftar kerusakan
/// (frame 6.24).
///
/// Footer: Primary "Catat rusak" dan Tertiary "Ubah" untuk catatan tanaman
/// (frame 6.22); setelah catatan disimpan muncul toast "Perubahan tersimpan"
/// (frame 6.23).
class V2DetailTanamanPage extends StatefulWidget {
  const V2DetailTanamanPage({
    super.key,
    required this.tanaman,
    required this.meja,
    this.onUbah,
    this.toast,
    this.onSimpanCatatan,
    this.onCatatRusak,
    this.onUbahRusak,
  });

  /// Frame `6.21 Detail tanaman`: Romaine Meja A2, HST 8.
  V2DetailTanamanPage.biasa({Key? key})
    : this(key: key, tanaman: designTanamanRomaineA2, meja: designMejaA2);

  /// Frame `6.23 Catatan tersimpan`: detail dengan toast.
  V2DetailTanamanPage.tersimpan({Key? key})
    : this(
        key: key,
        tanaman: designTanamanRomaineA2,
        meja: designMejaA2,
        toast: 'Perubahan tersimpan',
      );

  final V2TanamanItem tanaman;
  final V2MejaItem meja;

  /// Dipanggil saat catatan tanaman berubah supaya halaman meja ikut segar.
  final ValueChanged<String?>? onUbah;

  /// Simpan catatan tanaman ke batch pemindahan; null berarti hanya di layar.
  final Future<void> Function(String? catatan)? onSimpanCatatan;

  /// Simpan kerusakan baru ke backend; null berarti hanya di layar.
  final Future<V2KerusakanItem> Function(V2KerusakanItem draft)? onCatatRusak;

  /// Simpan perubahan kerusakan ke backend; null berarti hanya di layar.
  final Future<V2KerusakanItem> Function(V2KerusakanItem draft)? onUbahRusak;

  /// Toast yang sudah tampil saat halaman dibuka (frame 6.23).
  final String? toast;

  @override
  State<V2DetailTanamanPage> createState() => _V2DetailTanamanPageState();
}

class _V2DetailTanamanPageState extends State<V2DetailTanamanPage> {
  late V2TanamanItem _tanaman = widget.tanaman;
  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _toast = widget.toast;
    if (_toast != null) _scheduleToastDismiss();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void _scheduleToastDismiss() {
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _scheduleToastDismiss();
  }

  Future<void> _ubahCatatan() async {
    final catatan = await Navigator.of(
      context,
    ).push<String>(V2UbahCatatanTanamanPage.route(_tanaman.keterangan));
    if (!mounted || catatan == null) return;
    final simpan = widget.onSimpanCatatan;
    if (simpan != null) {
      try {
        await simpan(catatan);
        if (!mounted) return;
      } catch (error) {
        if (!mounted) return;
        _pesan('$error');
        return;
      }
    }
    setState(() => _tanaman = _tanaman.copyWith(keterangan: catatan));
    widget.onUbah?.call(catatan);
    _showToast('Perubahan tersimpan');
  }

  void _bukaRusak() {
    final rusak = widget.meja.rusak
        .where((item) => item.transferId == _tanaman.transferId)
        .toList();
    Navigator.of(context).push(
      V2TanamanRusakPage.route(
        item: widget.meja.copyWith(rusak: rusak),
        transferId: _tanaman.transferId,
        onCatat: widget.onCatatRusak,
        onUbah: widget.onUbahRusak,
      ),
    );
  }

  Future<void> _catatRusak() async {
    final hasil = await Navigator.of(context).push<V2KerusakanItem>(
      V2CatatRusakPage.route(
        meja: widget.meja,
        transferId: _tanaman.transferId,
      ),
    );
    if (!mounted || hasil == null) return;
    final simpan = widget.onCatatRusak;
    if (simpan == null) {
      _showToast('Kerusakan dicatat');
      return;
    }
    try {
      await simpan(hasil);
      if (mounted) _showToast('Kerusakan dicatat');
    } catch (error) {
      if (mounted) _pesan('$error');
    }
  }

  void _pesan(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              V2AppBar(
                title: 'Detail tanaman',
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
                      _RingkasanCard(tanaman: _tanaman, meja: widget.meja.nama),
                      const SizedBox(height: V2Space.lg),
                      _InfoCard(tanaman: _tanaman),
                      const SizedBox(height: V2Space.lg),
                      V2ListItem(
                        title: 'Tanaman rusak',
                        subtitle:
                            '${widget.meja.rusak.where((item) => item.transferId == _tanaman.transferId).fold<int>(0, (total, rusak) => total + rusak.jumlah)} tanaman. Lihat daftar',
                        icon: V2IconName.warning,
                        iconTone: V2ListItemIconTone.warning,
                        onTap: _bukaRusak,
                      ),
                    ],
                  ),
                ),
              ),
              V2ActionBar(
                toast: _toast,
                actions: [
                  V2Button(
                    label: 'Catat rusak',
                    onPressed: () => _catatRusak(),
                  ),
                  V2Button(
                    label: 'Ubah',
                    type: V2ButtonType.tertiary,
                    onPressed: _ubahCatatan,
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

/// Kartu ringkasan biru dengan bilah umur (frame 6.21).
class _RingkasanCard extends StatelessWidget {
  const _RingkasanCard({required this.tanaman, required this.meja});

  final V2TanamanItem tanaman;
  final String meja;

  @override
  Widget build(BuildContext context) {
    final progress = tanaman.umurPanenHst == 0
        ? 0.0
        : (tanaman.hst / tanaman.umurPanenHst).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(V2Space.xl),
      decoration: BoxDecoration(
        color: V2Colors.blue500,
        borderRadius: BorderRadius.circular(V2Radius.sheet),
        boxShadow: V2Shadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${tanaman.varietas}, $meja',
            style: V2Type.label.copyWith(color: V2Colors.white),
          ),
          const SizedBox(height: V2Space.sm),
          Text(
            tanaman.labelHst,
            style: V2Type.display.copyWith(color: V2Colors.white),
          ),
          const SizedBox(height: V2Space.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 12,
              color: V2Colors.blue600,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: V2Colors.lime400,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: V2Space.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tanam',
                  style: V2Type.label.copyWith(color: V2Colors.white),
                ),
              ),
              Text(
                'Panen HST ${tanaman.umurPanenHst}',
                style: V2Type.label.copyWith(color: V2Colors.white),
              ),
            ],
          ),
          const SizedBox(height: V2Space.sm),
          Text(
            tanaman.labelPanenLengkap,
            style: V2Type.bodyStrong.copyWith(color: V2Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Kartu putih dua baris: tanaman aktif dan tanggal pindah (frame 6.21).
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.tanaman});

  final V2TanamanItem tanaman;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: V2Space.xl,
        vertical: V2Space.lg,
      ),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
        boxShadow: V2Shadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _InfoRow(label: 'Tanaman aktif', value: tanaman.labelAktif),
          const SizedBox(height: V2Space.md),
          _InfoRow(label: 'Pindah', value: tanaman.labelPindah),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: V2Type.label.copyWith(color: V2Colors.muted)),
        Text(value, style: V2Type.body),
      ],
    );
  }
}

/// Form "Ubah catatan" tanaman (frame 6.22).
///
/// Hanya keterangan yang bisa diubah; jumlah dan tanggal pindah dikunci dengan
/// catatan di bawah field. Halaman mengembalikan keterangan baru lewat `pop`.
class V2UbahCatatanTanamanPage extends StatefulWidget {
  const V2UbahCatatanTanamanPage({super.key, this.keterangan});

  /// Frame `6.22 Ubah catatan tanaman`.
  const V2UbahCatatanTanamanPage.biasa({super.key}) : keterangan = 'Rak bawah';

  final String? keterangan;

  static Route<String> route(String? keterangan) {
    return MaterialPageRoute<String>(
      builder: (_) => V2UbahCatatanTanamanPage(keterangan: keterangan),
    );
  }

  @override
  State<V2UbahCatatanTanamanPage> createState() =>
      _V2UbahCatatanTanamanPageState();
}

class _V2UbahCatatanTanamanPageState extends State<V2UbahCatatanTanamanPage> {
  late final TextEditingController _keterangan = TextEditingController(
    text: widget.keterangan ?? '',
  );

  @override
  void dispose() {
    _keterangan.dispose();
    super.dispose();
  }

  void _simpan() => Navigator.of(context).pop(_keterangan.text.trim());

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              V2AppBar(
                title: 'Ubah catatan',
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
                        label: 'Keterangan (opsional)',
                        hint: 'Contoh: rak bawah',
                        controller: _keterangan,
                      ),
                      const SizedBox(height: V2Space.lg),
                      Text(
                        'Jumlah dan tanggal pindah tidak bisa diubah.',
                        style: V2Type.label.copyWith(color: V2Colors.muted),
                      ),
                    ],
                  ),
                ),
              ),
              V2ActionBar(
                actions: [V2Button(label: 'Simpan', onPressed: _simpan)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
