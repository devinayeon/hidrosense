import 'package:flutter/material.dart';

import '../../../core/formatting.dart';
import '../components/v2_meja_data.dart';
import '../components/v2_semaian_assets.dart';
import '../components/v2_semaian_data.dart';
import '../components/v2_semaian_date_sheet.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_option_row.dart';
import '../widgets/v2_select_field.dart';
import '../widgets/v2_stepper.dart';

/// Form "Pindah ke meja" (frame 5.17, 5.21, 5.24).
///
/// Susunannya: daftar meja (baris terpilih biru, meja penuh/perawatan kelabu dan
/// tidak bisa diketuk), "Jumlah tanaman", "Tanggal pindah", lalu kartu tint
/// "Estimasi panen". Kartu tint hilang saat jumlah melebihi lubang kosong
/// (frame 5.21) dan galat muncul 8 di bawah stepper.
///
/// Tombol "Pindahkan" mengembalikan [V2SemaianPindah] ke halaman detail; halaman
/// hasil (5.18/5.22) dibuka dulu supaya alurnya sama dengan desain.
class V2PindahMejaFormPage extends StatefulWidget {
  const V2PindahMejaFormPage({
    super.key,
    required this.item,
    this.mejaAwal = 0,
    this.jumlahAwal,
    this.previewSisa = false,
    this.previewLubangKurang = false,
    this.daftarMeja,
    this.initialDate,
    this.onPindahkan,
    this.showResultPage = true,
  });

  /// Frame `5.17 Pindah ke meja`: Meja A2 terpilih, 200 tanaman.
  V2PindahMejaFormPage.form({Key? key})
    : this(key: key, item: designSemaianRomaineSiapPindah);

  /// Frame `5.21 Pindah, lubang kurang`: Meja A3 (120 kosong) dengan 200 tanaman.
  V2PindahMejaFormPage.lubangKurang({Key? key})
    : this(
        key: key,
        item: designSemaianRomaineSiapPindah,
        mejaAwal: 1,
        previewLubangKurang: true,
      );

  /// Frame `5.24 Pindah sisa`: sisa 80 benih, Meja A3 sudah penuh.
  V2PindahMejaFormPage.sisa({Key? key})
    : this(
        key: key,
        item: designSemaianSisa,
        jumlahAwal: 80,
        previewSisa: true,
      );

  /// Semaian yang dipindah; sisa benihnya menentukan jumlah awal.
  final V2SemaianItem item;

  /// Indeks meja yang terpilih saat halaman dibuka.
  final int mejaAwal;

  /// Jumlah tanaman awal; kosong berarti semua benih yang masih di semaian.
  final int? jumlahAwal;

  /// Memakai daftar meja frame 5.24 (Meja A3 penuh).
  final bool previewSisa;

  /// Membuka halaman dengan galat "Lubang kosong hanya 120" (frame 5.21).
  final bool previewLubangKurang;

  /// Meja yang bisa dipilih; null berarti daftar contoh galeri.
  final List<V2SemaianMeja>? daftarMeja;

  /// Tanggal pindah awal; null berarti tanggal acuan galeri.
  final DateTime? initialDate;

  /// Kirim pemindahan ke backend; null berarti hanya pratinjau galeri.
  final Future<void> Function(V2SemaianPindah pindah)? onPindahkan;

  /// Buka halaman hasil (5.18/5.22) setelah pindah. `false` membuat form
  /// langsung menutup dan mengembalikan [V2SemaianPindah] ke pemanggil — dipakai
  /// alur "Tambah tanaman" dari Detail meja (D-25) yang punya konteksnya sendiri.
  final bool showResultPage;

  @override
  State<V2PindahMejaFormPage> createState() => _V2PindahMejaFormPageState();
}

class _V2PindahMejaFormPageState extends State<V2PindahMejaFormPage> {
  late final List<V2SemaianMeja> _meja;
  late int _mejaIndex;
  late int _jumlah =
      widget.jumlahAwal ?? widget.item.sisaBenih ?? widget.item.jumlahBenih;
  late DateTime _tanggal = widget.initialDate ?? DateTime(2026, 11, 15);
  String? _error;

  V2SemaianMeja get _terpilih => _meja[_mejaIndex];

  @override
  void initState() {
    super.initState();
    final sumber = widget.daftarMeja?.isNotEmpty == true
        ? widget.daftarMeja!
        : widget.previewSisa
        ? designMejaPindahSisa
        : designMejaPindah;
    final awal = widget.mejaAwal.clamp(0, sumber.length - 1);
    final acuan = sumber[awal];
    // Urutkan daftar sesuai D-27, lalu cari lagi meja awal supaya pilihannya
    // tidak meleset setelah urutan berubah.
    _meja = urutkanMejaPindah(sumber);
    var terpilih = _meja.indexWhere(
      (meja) => acuan.tableId != null
          ? meja.tableId == acuan.tableId
          : meja.nama == acuan.nama,
    );
    if (terpilih < 0) terpilih = 0;
    // Bawaan tidak boleh meja penuh/perawatan: pilih meja tersedia pertama
    // kalau pilihan awal tidak bisa dipakai (BUG-29).
    if (!_meja[terpilih].tersedia) {
      final pertama = _meja.indexWhere((meja) => meja.tersedia);
      if (pertama >= 0) terpilih = pertama;
    }
    _mejaIndex = terpilih;
    if (widget.previewLubangKurang) {
      _error = _pesanLubang(200);
    }
  }

  /// Pesan galat bila jumlah melebihi lubang kosong meja terpilih.
  String? _pesanLubang(int jumlah) {
    final meja = _terpilih;
    if (jumlah <= meja.lubangKosong) return null;
    return 'Lubang kosong hanya ${meja.lubangKosong}';
  }

  void _setJumlah(int value) {
    setState(() {
      _jumlah = value;
      _error = _pesanLubang(value);
    });
  }

  void _pilihMeja(int index) {
    if (!_meja[index].tersedia) return;
    setState(() {
      _mejaIndex = index;
      _error = _pesanLubang(_jumlah);
    });
  }

  Future<void> _pickTanggal() async {
    final result = await showV2SemaianDateSheet(context, selected: _tanggal);
    if (!mounted || result == null) return;
    setState(() => _tanggal = result);
  }

  Future<void> _pindahkan() async {
    final galat = _pesanLubang(_jumlah);
    setState(() => _error = galat);
    if (galat != null) return;

    final pindah = V2SemaianPindah(
      meja: _terpilih.nama,
      jumlah: _jumlah,
      tanggal: _tanggal,
      tableId: _terpilih.tableId,
    );
    final kirim = widget.onPindahkan;
    if (kirim != null) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await kirim(pindah);
      } catch (error) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('$error')));
        return;
      }
    }
    if (!mounted) return;

    // Alur "Tambah tanaman" (D-25) tidak menampilkan halaman hasil: form
    // langsung menutup dan aksi diteruskan ke Detail meja pemanggil.
    if (!widget.showResultPage) {
      Navigator.of(context).pop(
        V2SemaianPindah(
          meja: pindah.meja,
          jumlah: pindah.jumlah,
          tanggal: pindah.tanggal,
          tableId: pindah.tableId,
        ),
      );
      return;
    }

    final sisa = (widget.item.sisaBenih ?? widget.item.jumlahBenih) - _jumlah;
    // Perkiraan panen dihitung dari tanggal pindah nyata, bukan tanggal contoh
    // "30 Des" yang tetap (BUG-36).
    final perkiraanPanen = DateTime(
      pindah.tanggal.year,
      pindah.tanggal.month,
      pindah.tanggal.day + v2MejaUmurPanenHst,
    );

    // Tombol halaman sukses tidak boleh mati (BUG-28): masing-masing
    // mengembalikan aksi yang lalu diteruskan ke pemanggil.
    final aksi =
        await Navigator.of(context).push<V2PindahMejaAksi>(
          MaterialPageRoute<V2PindahMejaAksi>(
            builder: (_) => V2PindahMejaResultPage(
              title: sisa > 0
                  ? 'Sudah pindah ${pindah.jumlah} ke ${pindah.meja}'
                  : 'Sudah pindah ke ${pindah.meja}',
              body: sisa > 0
                  ? '$sisa benih masih di semaian.'
                  : '${pindah.jumlah} tanaman. '
                        'Panen sekitar ${labelTanggalMeja(perkiraanPanen)}.',
              primaryLabel: sisa > 0 ? 'Pindahkan sisa' : 'Lihat meja',
              onPrimary: () => Navigator.of(context).pop(
                sisa > 0
                    ? V2PindahMejaAksi.pindahkanSisa
                    : V2PindahMejaAksi.lihatMeja,
              ),
              secondaryLabel: 'Ke daftar semaian',
              onSecondary: () =>
                  Navigator.of(context).pop(V2PindahMejaAksi.keDaftarSemaian),
            ),
          ),
        ) ??
        V2PindahMejaAksi.selesai;
    if (!mounted) return;

    // "Pindahkan sisa" tidak lagi membuka form di sini dengan daftar meja lama:
    // aksi dikembalikan ke pemanggil (halaman detail) supaya form dibuka ulang
    // dengan data meja yang sudah disegarkan setelah pindah (BUG-34a).
    Navigator.of(context).pop(
      V2SemaianPindah(
        meja: pindah.meja,
        jumlah: pindah.jumlah,
        tanggal: pindah.tanggal,
        tableId: pindah.tableId,
        aksi: aksi,
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
          child: Column(
            children: [
              V2AppBar(
                title: 'Pindah ke meja',
                onBack: () => Navigator.of(context).maybePop(),
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
                      _mejaList(),
                      const SizedBox(height: V2Space.lg),
                      _jumlahField(),
                      const SizedBox(height: V2Space.lg),
                      V2SelectField(
                        label: 'Tanggal pindah',
                        value: formatTanggalIndo(_tanggal, singkat: true),
                        icon: V2IconName.calendar,
                        onTap: _pickTanggal,
                      ),
                      // Kartu tint menerangkan perkiraan panen; tidak tampil saat
                      // jumlah melebihi lubang kosong (frame 5.21).
                      if (_error == null) ...[
                        const SizedBox(height: V2Space.lg),
                        _tintCard(),
                      ],
                    ],
                  ),
                ),
              ),
              V2ActionBar(
                actions: [V2Button(label: 'Pindahkan', onPressed: _pindahkan)],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mejaList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Meja', style: V2Type.label.copyWith(color: V2Colors.ink)),
        const SizedBox(height: V2Space.sm),
        for (var index = 0; index < _meja.length; index++) ...[
          if (index > 0) const SizedBox(height: V2Space.sm),
          V2OptionRow(
            label: _meja[index].label,
            state: index == _mejaIndex
                ? V2OptionState.selected
                : _meja[index].tersedia
                ? V2OptionState.normal
                : V2OptionState.disabled,
            onTap: () => _pilihMeja(index),
          ),
        ],
      ],
    );
  }

  /// "Jumlah tanaman": label, stepper 56, lalu helper galat bila ada (5.21).
  Widget _jumlahField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Jumlah tanaman',
          style: V2Type.label.copyWith(color: V2Colors.ink),
        ),
        const SizedBox(height: V2Space.sm),
        V2QtyField(
          value: _jumlah,
          unit: 'tanaman',
          error: _error != null,
          onChanged: _setJumlah,
          onMinus: _jumlah <= 1 ? null : () => _setJumlah(_jumlah - 1),
          onPlus: () => _setJumlah(_jumlah + 1),
        ),
        if (_error != null) ...[
          const SizedBox(height: V2Space.sm),
          Row(
            children: [
              const V2Icon(
                V2IconName.error,
                size: V2Icons.small,
                color: V2Colors.red700,
              ),
              const SizedBox(width: V2Space.sm),
              Flexible(
                child: Text(
                  _error!,
                  style: V2Type.label.copyWith(color: V2Colors.red700),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Kartu `Card Type=Tint` "Estimasi panen" (frame 5.17/5.24).
  Widget _tintCard() {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(V2Space.xl),
      decoration: BoxDecoration(
        color: V2Colors.blue50,
        borderRadius: BorderRadius.circular(V2Radius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Estimasi panen', style: V2Type.h2),
          const SizedBox(height: V2Space.sm),
          Text(
            designEstimasiPanen,
            style: V2Type.body.copyWith(color: V2Colors.slate600),
          ),
        ],
      ),
    );
  }
}

/// Halaman hasil pindah (frame 5.18, 5.20, 5.22).
///
/// Ilustrasi meja tanam 160, judul 28/36 centered, lalu keterangan 16/24 abu.
/// Frame 5.18/5.22 tidak ber-AppBar dan ilustrasinya 136 dari puncak konten;
/// frame 5.20 ber-AppBar dan ilustrasinya 185 dari puncak konten.
class V2PindahMejaResultPage extends StatelessWidget {
  const V2PindahMejaResultPage({
    super.key,
    required this.title,
    required this.body,
    required this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.showAppBar = false,
    this.topOffset = 136,
  });

  /// Frame `5.18 Pindah berhasil`: 200 tanaman pindah ke Meja A2.
  const V2PindahMejaResultPage.berhasil({Key? key})
    : this(
        key: key,
        title: 'Sudah pindah ke Meja A2',
        body: '200 tanaman. Panen sekitar 30 Des.',
        primaryLabel: 'Lihat meja',
        secondaryLabel: 'Ke daftar semaian',
      );

  /// Frame `5.22 Pindah sebagian`: 120 pindah, 80 masih di semaian.
  const V2PindahMejaResultPage.sebagian({Key? key})
    : this(
        key: key,
        title: 'Sudah pindah 120 ke Meja A3',
        body: '80 benih masih di semaian.',
        primaryLabel: 'Pindahkan sisa',
        secondaryLabel: 'Ke daftar semaian',
      );

  /// Frame `5.20 Tidak ada meja kosong`.
  const V2PindahMejaResultPage.tidakAdaMeja({Key? key})
    : this(
        key: key,
        title: 'Tidak ada meja kosong',
        body: 'Tambah meja, atau kosongkan meja lain.',
        primaryLabel: 'Tambah meja',
        showAppBar: true,
        topOffset: 185,
      );

  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool showAppBar;

  /// Jarak ilustrasi dari puncak area konten.
  final double topOffset;

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
              if (showAppBar)
                V2AppBar(
                  title: 'Pindah ke meja',
                  onBack: () => Navigator.of(context).maybePop(),
                )
              else
                // Layar hasil tanpa AppBar tetap memulai konten di y116.
                const SizedBox(height: 72),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
                  child: Column(
                    children: [
                      SizedBox(height: topOffset),
                      Image.asset(
                        V2SemaianAssets.growingTable,
                        width: 160,
                        height: 160,
                      ),
                      const SizedBox(height: V2Space.lg),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: V2Type.h1,
                      ),
                      const SizedBox(height: V2Space.lg),
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: V2Type.body.copyWith(color: V2Colors.muted),
                      ),
                    ],
                  ),
                ),
              ),
              V2ActionBar(
                actions: [
                  V2Button(label: primaryLabel, onPressed: onPrimary),
                  if (secondaryLabel != null)
                    V2Button(
                      label: secondaryLabel!,
                      type: V2ButtonType.ghost,
                      onPressed: onSecondary,
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
