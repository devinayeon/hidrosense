import 'dart:async';

import 'package:flutter/material.dart';

import '../components/v2_inventaris_catat_sheet.dart';
import '../components/v2_inventaris_data.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_badge.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_dialog.dart';
import '../widgets/v2_summary_card.dart';
import 'v2_inventaris_form_page.dart';

/// Detail satu barang stok (frame 4.17–4.23, 4.25, 4.26, 4.29).
///
/// Susunannya sama untuk semua keadaan: kartu ringkasan biru (nama + jenis,
/// jumlah, stok minimum, badge keadaan), kartu putih "Riwayat", lalu baris aksi
/// "Ubah"/"Arsipkan". Footer "Catat stok" melayang di bawah; barang habis
/// memakai label "Catat stok masuk" dan barang arsip tidak punya baris aksi
/// maupun footer (frame 4.29).
///
/// Halaman ini menyimpan jumlah barang di memori supaya "Catat stok" (sheet
/// 4.21) bisa langsung memperbarui kartu, badge, dan riwayat, lalu memunculkan
/// toast "Stok dicatat" (frame 4.23). "Ubah" membuka form 4.24 dan kembali
/// dengan toast "Perubahan tersimpan" (frame 4.25); "Arsipkan" minta
/// konfirmasi (frame 4.26) lalu menutup halaman sambil membawa barang yang
/// sudah ditandai arsip. Jumlah/keadaan terbaru dikembalikan lewat `pop` agar
/// baris di daftar ikut berubah.
class V2InventarisDetailPage extends StatefulWidget {
  const V2InventarisDetailPage({
    super.key,
    required this.item,
    this.footerLabel,
    this.showAksi = true,
    this.onCatatStok,
    this.onUbah,
    this.onArsipkan,
    this.onAktifkan,
    this.toast,
    this.openCatatOnStart = false,
    this.catatJumlah,
    this.openArsipOnStart = false,
  });

  /// Frame `4.17 Detail barang baru`: Benih Lollo Rossa baru masuk.
  const V2InventarisDetailPage.baru({Key? key})
    : this(key: key, item: designDetailBaru, footerLabel: 'Catat stok');

  /// Frame `4.18 Detail barang menipis`: Benih Butterhead sisa 2 pak.
  const V2InventarisDetailPage.menipis({Key? key})
    : this(key: key, item: designDetailMenipis, footerLabel: 'Catat stok');

  /// Frame `4.19 Detail barang`: Benih Romaine stoknya cukup.
  const V2InventarisDetailPage.biasa({Key? key})
    : this(key: key, item: designDetailBiasa, footerLabel: 'Catat stok');

  /// Frame `4.20 Detail barang habis`: Rockwool ludes.
  const V2InventarisDetailPage.habis({Key? key})
    : this(key: key, item: designDetailHabis, footerLabel: 'Catat stok masuk');

  /// Frame `4.29 Detail barang arsip`: Benih Romaine sudah diarsipkan.
  const V2InventarisDetailPage.arsip({Key? key})
    : this(
        key: key,
        item: designDetailArsip,
        footerLabel: null,
        showAksi: false,
      );

  /// Frame `4.21 Catat stok`: sheet terbuka dengan jumlah bawaan 2 pak.
  const V2InventarisDetailPage.catatSheet({Key? key})
    : this(
        key: key,
        item: designDetailBiasa,
        footerLabel: 'Catat stok',
        openCatatOnStart: true,
      );

  /// Frame `4.22 Stok kurang`: jumlah 15 pak melebihi stok 12, field bergalat.
  const V2InventarisDetailPage.catatError({Key? key})
    : this(
        key: key,
        item: designDetailBiasa,
        footerLabel: 'Catat stok',
        openCatatOnStart: true,
        catatJumlah: 15,
      );

  /// Frame `4.23 Stok tercatat`: Benih Romaine jadi 10 pak plus toast.
  const V2InventarisDetailPage.tercatat({Key? key})
    : this(
        key: key,
        item: designDetailTercatat,
        footerLabel: 'Catat stok',
        toast: 'Stok dicatat',
      );

  /// Frame `4.25 Perubahan tersimpan`: detail dengan toast setelah "Ubah".
  const V2InventarisDetailPage.perubahan({Key? key})
    : this(
        key: key,
        item: designDetailBiasa,
        footerLabel: 'Catat stok',
        toast: 'Perubahan tersimpan',
      );

  /// Frame `4.26 Arsipkan, konfirmasi`: dialog arsip terbuka di atas detail.
  const V2InventarisDetailPage.arsipkanKonfirmasi({Key? key})
    : this(
        key: key,
        item: designDetailBiasa,
        footerLabel: 'Catat stok',
        openArsipOnStart: true,
      );

  final V2InventarisItem item;

  /// Label tombol footer; null berarti tanpa footer (frame 4.29).
  final String? footerLabel;

  /// Baris "Ubah"/"Arsipkan"; false pada frame 4.29.
  final bool showAksi;

  /// Ketukan pada tombol aksi; null berarti aksi bawaan halaman dipakai.
  final VoidCallback? onCatatStok;
  final VoidCallback? onUbah;
  final VoidCallback? onArsipkan;

  /// Ketukan tombol "Aktifkan kembali" barang arsip (frame 4.29 dirancang tanpa
  /// footer, jadi tombol ini hanya muncul di alur nyata yang mengisinya).
  final VoidCallback? onAktifkan;

  /// Toast yang sudah tampil saat halaman dibuka (frame 4.23).
  final String? toast;

  /// Membuka sheet "Catat stok" begitu halaman tampil (frame 4.21/4.22).
  final bool openCatatOnStart;

  /// Jumlah bawaan di sheet; null berarti 2 pak (frame 4.21).
  final int? catatJumlah;

  /// Membuka dialog "Arsipkan barang?" begitu halaman tampil (frame 4.26).
  final bool openArsipOnStart;

  /// Label footer untuk satu barang: arsip tanpa footer, barang habis
  /// "Catat stok masuk", sisanya "Catat stok".
  static String? footerLabelFor(V2InventarisItem item) => item.arsip
      ? null
      : item.status == V2InventarisStatus.habis
      ? 'Catat stok masuk'
      : 'Catat stok';

  static Route<V2InventarisItem> route(
    V2InventarisItem item, {
    VoidCallback? onCatatStok,
    VoidCallback? onUbah,
    VoidCallback? onArsipkan,
  }) {
    return MaterialPageRoute<V2InventarisItem>(
      builder: (_) => V2InventarisDetailPage(
        item: item,
        footerLabel: footerLabelFor(item),
        showAksi: !item.arsip,
        onCatatStok: onCatatStok,
        onUbah: onUbah,
        onArsipkan: onArsipkan,
      ),
    );
  }

  @override
  State<V2InventarisDetailPage> createState() => _V2InventarisDetailPageState();
}

class _V2InventarisDetailPageState extends State<V2InventarisDetailPage> {
  late V2InventarisItem _item = widget.item;
  Timer? _toastTimer;
  String? _toast;

  @override
  void initState() {
    super.initState();
    _toast = widget.toast;
    if (_toast != null) _scheduleToastDismiss();
    if (widget.openCatatOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _catatStok();
      });
    }
    if (widget.openArsipOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _arsipkan();
      });
    }
  }

  /// Halaman penghubung backend memperbarui barang lalu membangun ulang
  /// halaman ini; salinan lokal ikut diganti supaya kartu detail tidak
  /// menampilkan data lama.
  @override
  void didUpdateWidget(covariant V2InventarisDetailPage oldWidget) {
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

  /// Buka sheet "Catat stok" (frame 4.21); jumlah, keadaan, dan riwayat barang
  /// ikut berubah begitu "Simpan" ditekan (frame 4.23).
  Future<void> _catatStok() async {
    if (widget.onCatatStok != null) {
      widget.onCatatStok!();
      return;
    }
    final hasil = await showV2CatatStokSheet(
      context,
      item: _item,
      jumlah: widget.catatJumlah ?? 2,
    );
    if (!mounted || hasil == null) return;
    final jumlahBaru = hasil.masuk
        ? _item.jumlah + hasil.jumlah
        : _item.jumlah - hasil.jumlah;
    setState(() {
      _item = _item.copyWith(
        jumlah: jumlahBaru,
        status: statusStok(jumlahBaru, _item.minimum),
        riwayat: <V2InventarisRiwayat>[
          V2InventarisRiwayat(
            '${hasil.masuk ? 'Masuk' : 'Pakai'} ${hasil.jumlah} ${_item.satuan}',
            'Hari ini',
          ),
          ..._item.riwayat,
        ],
      );
      _toast = 'Stok dicatat';
    });
    _scheduleToastDismiss();
  }

  /// Buka form ubah (frame 4.24); hasilnya menggantikan barang lalu memunculkan
  /// toast "Perubahan tersimpan" (frame 4.25).
  Future<void> _ubah() async {
    if (widget.onUbah != null) {
      widget.onUbah!();
      return;
    }
    final updated = await Navigator.of(
      context,
    ).push<V2InventarisItem>(V2InventarisFormPage.routeUbah(_item));
    if (!mounted || updated == null) return;
    setState(() {
      _item = updated;
      _toast = 'Perubahan tersimpan';
    });
    _scheduleToastDismiss();
  }

  /// Aktifkan kembali barang arsip. Hanya dipakai alur nyata yang mengisi
  /// [onAktifkan]; halaman menutup sambil membawa barang aktif supaya baris di
  /// daftar ikut berubah.
  Future<void> _aktifkan() async {
    if (widget.onAktifkan != null) {
      widget.onAktifkan!();
      return;
    }
  }

  /// Minta konfirmasi arsip (frame 4.26); bila setuju, halaman ditutup sambil
  /// membawa barang yang sudah ditandai arsip supaya hilang dari daftar.
  Future<void> _arsipkan() async {
    if (widget.onArsipkan != null) {
      widget.onArsipkan!();
      return;
    }
    final confirmed = await showV2Dialog(
      context,
      type: V2DialogType.destructive,
      title: 'Arsipkan barang?',
      body:
          '${_item.nama} hilang dari daftar. Riwayat tetap bisa dilihat di '
          'Arsip.',
      primaryLabel: 'Arsipkan',
      secondaryLabel: 'Batal',
    );
    if (!mounted || confirmed != true) return;
    Navigator.of(context).pop(_item.copyWith(arsip: true));
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
                title: 'Detail barang',
                onBack: () => Navigator.of(context).pop(_item),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    V2Space.xl,
                    V2Space.sm,
                    V2Space.xl,
                    V2Space.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      V2SummaryCard(
                        kicker:
                            '${_item.nama}, ${_item.jenis.label.toLowerCase()}',
                        value: _item.kuantitas,
                        meta: _item.minimumLabel,
                        badge: _badge(),
                      ),
                      const SizedBox(height: V2Space.lg),
                      _riwayat(),
                      if (widget.showAksi) ...[
                        const SizedBox(height: V2Space.lg),
                        Row(
                          children: [
                            Expanded(
                              child: V2Button(
                                label: 'Ubah',
                                type: V2ButtonType.tertiary,
                                onPressed: _ubah,
                              ),
                            ),
                            const SizedBox(width: V2Space.lg),
                            Expanded(
                              child: V2Button(
                                label: 'Arsipkan',
                                type: V2ButtonType.destructive,
                                onPressed: _arsipkan,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (widget.footerLabel != null ||
                  (_item.arsip && widget.onAktifkan != null))
                V2ActionBar(
                  toast: _toast,
                  actions: [
                    if (_item.arsip && widget.onAktifkan != null)
                      V2Button(
                        label: 'Aktifkan kembali',
                        onPressed: _aktifkan,
                      )
                    else
                      V2Button(
                        label: widget.footerLabel!,
                        onPressed: _catatStok,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Kartu putih "Riwayat": judul, lalu tiga catatan terbaru.
  Widget _riwayat() {
    return Container(
      padding: const EdgeInsets.all(V2Space.xl),
      decoration: BoxDecoration(
        color: V2Colors.white,
        borderRadius: BorderRadius.circular(V2Radius.card),
        boxShadow: V2Shadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Riwayat', style: V2Type.h2),
          for (final baris in riwayatTampil(_item.riwayat)) ...[
            const SizedBox(height: V2Space.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(baris.label, style: V2Type.body)),
                Text(
                  baris.tanggal,
                  style: V2Type.label.copyWith(color: V2Colors.muted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Keadaan stok: arsip memakai badge netral "Arsip"; sisanya mengikuti
  /// kecukupan stok (frame 4.17–4.20, 4.23).
  Widget _badge() {
    if (_item.arsip) {
      return const V2Badge(label: 'Arsip', status: V2BadgeStatus.neutral);
    }
    return switch (_item.status) {
      V2InventarisStatus.aman => const V2Badge(
        label: 'Cukup',
        status: V2BadgeStatus.success,
      ),
      V2InventarisStatus.menipis => const V2Badge(
        label: 'Menipis',
        status: V2BadgeStatus.warning,
      ),
      V2InventarisStatus.habis => const V2Badge(
        label: 'Habis',
        status: V2BadgeStatus.error,
      ),
    };
  }
}
