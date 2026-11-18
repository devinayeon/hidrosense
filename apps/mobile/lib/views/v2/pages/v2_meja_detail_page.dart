import 'dart:async';

import 'package:flutter/material.dart';

import '../components/v2_meja_data.dart';
import '../components/v2_meja_detail_cards.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_bottom_sheet.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_option_row.dart';
import 'v2_detail_tanaman_page.dart';
import 'v2_meja_form_page.dart';
import 'v2_pilih_semaian_page.dart';

/// Detail satu meja tanam (frame 6.10–6.13, 6.16, 6.17, 6.20).
///
/// Susunannya: kartu grid lubang biru, kartu "Tanaman di meja", lalu dua tombol
/// tersier "Ubah status"/"Ubah meja". Footer mengikuti keadaan meja:
///
/// - tersedia: "Tambah tanaman" aktif (6.10/6.11/6.20);
/// - perawatan: catatan "tidak menerima tanaman baru" + tombol mati (6.13);
/// - penuh: catatan "Kosongkan lubang lewat panen atau catat rusak" + tombol
///   mati (6.16), kecuali ada tanaman siap panen: footer diganti "Catat panen"
///   (6.17).
///
/// Halaman memegang salinan meja supaya hasil ubah status/meja langsung terlihat
/// sebelum kembali ke daftar.
class V2MejaDetailPage extends StatefulWidget {
  const V2MejaDetailPage({
    super.key,
    required this.item,
    this.toast,
    this.openStatusOnStart = false,
    this.onCatatPanen,
    this.onUbahStatus,
    this.onUbahMeja,
    this.onTambahTanaman,
  });

  /// Frame `6.10 Detail meja kosong`: Meja C1, 0 dari 180.
  V2MejaDetailPage.kosong({Key? key}) : this(key: key, item: designMejaC1);

  /// Frame `6.11 Detail meja`: Meja A2, 40 dari 240, satu tanaman Romaine.
  V2MejaDetailPage.biasa({Key? key}) : this(key: key, item: designMejaA2);

  /// Frame `6.12 Ubah status meja`: sheet status terbuka di atas detail.
  V2MejaDetailPage.statusSheet({Key? key})
    : this(key: key, item: designMejaA2, openStatusOnStart: true);

  /// Frame `6.13 Status diubah`: Meja A2 berstatus Perawatan + toast.
  V2MejaDetailPage.status({Key? key})
    : this(key: key, item: designMejaA2Perawatan, toast: 'Status diubah');

  /// Frame `6.16 Detail meja penuh`: Meja A2, 240 dari 240, dua tanaman.
  V2MejaDetailPage.penuh({Key? key}) : this(key: key, item: designMejaA2Penuh);

  /// Frame `6.17 Detail meja siap panen`: Meja B1, panen hari ini.
  V2MejaDetailPage.siapPanen({Key? key}) : this(key: key, item: designMejaB1);

  /// Frame `6.20 Meja diubah`: Meja A2 setelah form ubah + toast.
  V2MejaDetailPage.diubah({Key? key})
    : this(key: key, item: designMejaA2, toast: 'Perubahan tersimpan');

  /// Meja yang ditampilkan; halaman memegang salinan untuk perubahan lokal.
  final V2MejaItem item;

  /// Toast yang sudah tampil saat halaman dibuka (frame 6.13/6.20).
  final String? toast;

  /// Membuka sheet "Ubah status meja" begitu halaman tampil (frame 6.12).
  final bool openStatusOnStart;

  /// Aksi "Catat panen"; null berarti hanya pratinjau.
  final VoidCallback? onCatatPanen;

  /// Simpan status baru ke backend; null berarti perubahan hanya di layar.
  final Future<void> Function(V2MejaStatus status)? onUbahStatus;

  /// Simpan hasil form "Ubah meja" ke backend; null berarti hanya di layar.
  final Future<void> Function(V2MejaItem meja)? onUbahMeja;

  /// Tambah tanaman lewat alur backend; null berarti alur contoh galeri.
  final Future<V2MejaItem?> Function()? onTambahTanaman;

  static Route<V2MejaItem> route(V2MejaItem item) {
    return MaterialPageRoute<V2MejaItem>(
      builder: (_) => V2MejaDetailPage(item: item),
    );
  }

  @override
  State<V2MejaDetailPage> createState() => _V2MejaDetailPageState();
}

class _V2MejaDetailPageState extends State<V2MejaDetailPage> {
  late V2MejaItem _item = widget.item;
  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _toast = widget.toast;
    if (_toast != null) _scheduleToastDismiss();
    if (widget.openStatusOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ubahStatus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant V2MejaDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.item, oldWidget.item)) {
      _item = widget.item;
    }
    if (widget.toast != null && widget.toast != oldWidget.toast) {
      _toast = widget.toast;
      _scheduleToastDismiss();
    }
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

  void _close() => Navigator.of(context).pop(_item);

  /// Sheet "Ubah status meja" (frame 6.12): Tersedia, Perawatan, dan Penuh
  /// otomatis yang tidak bisa dipilih.
  ///
  /// Scrim 60% mengikuti frame 6.12; helper bersama `showV2BottomSheet` masih
  /// memakai 35% sehingga sheet ini memanggil `showModalBottomSheet` sendiri.
  Future<void> _ubahStatus() async {
    final result = await showModalBottomSheet<V2MejaStatus>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: V2Colors.ink.withValues(alpha: 0.6),
      isScrollControlled: true,
      builder: (_) => V2BottomSheet(
        title: 'Ubah status meja',
        actions: V2Button(
          label: 'Simpan',
          onPressed: () => Navigator.of(context).pop(),
        ),
        child: Column(
          children: [
            V2OptionRow(
              label: 'Tersedia',
              state: _item.status == V2MejaStatus.tersedia
                  ? V2OptionState.selected
                  : V2OptionState.normal,
              onTap: () => Navigator.of(context).pop(V2MejaStatus.tersedia),
            ),
            const SizedBox(height: V2Space.lg),
            V2OptionRow(
              label: 'Perawatan',
              state: _item.status == V2MejaStatus.perawatan
                  ? V2OptionState.selected
                  : V2OptionState.normal,
              onTap: () => Navigator.of(context).pop(V2MejaStatus.perawatan),
            ),
            const SizedBox(height: V2Space.lg),
            const V2OptionRow(
              label: 'Penuh, otomatis',
              state: V2OptionState.disabled,
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    final simpan = widget.onUbahStatus;
    if (simpan != null) {
      try {
        await simpan(result);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text('$error')));
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() => _item = _item.copyWith(status: result));
    _showToast('Status diubah');
  }

  /// Form "Ubah meja" (frame 6.18/6.19); hasilnya menggantikan meja di sini.
  Future<void> _ubahMeja() async {
    final result = await Navigator.of(
      context,
    ).push<V2MejaItem>(V2MejaFormPage.route(meja: _item));
    if (!mounted || result == null) return;
    final simpan = widget.onUbahMeja;
    if (simpan != null) {
      try {
        await simpan(result);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text('$error')));
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() => _item = result);
    _showToast('Perubahan tersimpan');
  }

  /// Buka "Pilih semaian" (6.14) lalu tambahkan semaian terpilih ke meja.
  Future<void> _tambahTanaman() async {
    final tambah = widget.onTambahTanaman;
    if (tambah != null) {
      try {
        final hasil = await tambah();
        if (mounted && hasil != null) setState(() => _item = hasil);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text('$error')));
        }
      }
      return;
    }
    final semaian = await Navigator.of(
      context,
    ).push(V2PilihSemaianPage.route());
    if (!mounted || semaian == null) return;

    final muat = _item.kosong;
    if (muat <= 0) return;
    final jumlah = semaian.jumlahBenih < muat ? semaian.jumlahBenih : muat;
    final tanaman = V2TanamanItem(
      varietas: semaian.nama,
      tanggalTanam: v2MejaHariIni,
      tanggalPanen: DateTime(
        v2MejaHariIni.year,
        v2MejaHariIni.month,
        v2MejaHariIni.day + v2MejaUmurPanenHst,
      ),
      tanggalPindah: v2MejaHariIni,
      jumlahAktif: jumlah,
      jumlahAwal: jumlah,
    );
    final terisi = _item.terisi + jumlah;
    setState(() {
      _item = _item.copyWith(
        terisi: terisi,
        status: terisi >= _item.jumlahLubang
            ? V2MejaStatus.penuh
            : _item.status,
        tanaman: <V2TanamanItem>[..._item.tanaman, tanaman],
      );
    });
  }

  void _bukaTanaman(V2TanamanItem tanaman) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => V2DetailTanamanPage(
          tanaman: tanaman,
          meja: _item,
          onUbah: (catatan) {
            setState(() {
              _item = _item.copyWith(
                tanaman: [
                  for (final baris in _item.tanaman)
                    if (identical(baris, tanaman))
                      baris.copyWith(keterangan: catatan)
                    else
                      baris,
                ],
              );
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final siapPanen =
        _item.status == V2MejaStatus.penuh &&
        _item.tanaman.any((tanaman) => tanaman.hariMenujuPanen <= 0);

    return Theme(
      data: V2Theme.light,
      child: PopScope<V2MejaItem>(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _close();
        },
        child: Scaffold(
          backgroundColor: V2Colors.canvas,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                V2AppBar(title: 'Detail meja', onBack: _close),
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
                        V2MejaGridCard(item: _item),
                        const SizedBox(height: V2Space.md),
                        V2MejaTanamanCard(
                          item: _item,
                          showTitle: _item.status == V2MejaStatus.tersedia,
                          onTapTanaman: _bukaTanaman,
                        ),
                        if (_item.status != V2MejaStatus.penuh) ...[
                          const SizedBox(height: V2Space.md),
                          Row(
                            children: [
                              Expanded(
                                child: V2Button(
                                  label: 'Ubah status',
                                  type: V2ButtonType.tertiary,
                                  onPressed: _ubahStatus,
                                ),
                              ),
                              const SizedBox(width: V2Space.lg),
                              Expanded(
                                child: V2Button(
                                  label: 'Ubah meja',
                                  type: V2ButtonType.tertiary,
                                  onPressed: _ubahMeja,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                _footer(siapPanen: siapPanen),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer({required bool siapPanen}) {
    final tambah = V2Button(
      label: 'Tambah tanaman',
      onPressed: _item.bisaTambahTanaman ? _tambahTanaman : null,
    );

    if (siapPanen) {
      return V2ActionBar(
        toast: _toast,
        actions: [
          V2Button(
            label: 'Catat panen',
            onPressed: widget.onCatatPanen ?? () {},
          ),
        ],
      );
    }

    return V2ActionBar(
      toast: _toast,
      note: switch (_item.status) {
        V2MejaStatus.perawatan => 'Meja Perawatan tidak menerima tanaman baru.',
        V2MejaStatus.penuh =>
          'Meja penuh. Kosongkan lubang lewat panen atau catat rusak.',
        V2MejaStatus.tersedia => null,
      },
      actions: [tambah],
    );
  }
}
