import 'package:flutter/material.dart';

import '../components/v2_semaian_data.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_action_bar.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_bottom_sheet.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_dialog.dart';
import '../widgets/v2_option_row.dart';
import '../widgets/v2_select_field.dart';
import '../widgets/v2_text_field.dart';

/// Form "Ubah semaian" (frame 5.25, 5.27, 5.28, 5.31).
///
/// Hanya tiga isian yang bisa diubah: jumlah benih, keterangan, dan status.
/// Tanggal semai dan bahan tidak bisa diubah, seperti catatan kecil di bawah
/// kolom status (frame 5.25).
///
/// Memilih status "Selesai" memunculkan dialog destruktif "Tandai selesai?"
/// (frame 5.28). [previewKonflik] menampilkan dialog "Data sudah berubah"
/// (frame 5.31), yaitu saat data diubah di perangkat lain.
class V2SemaianEditPage extends StatefulWidget {
  const V2SemaianEditPage({
    super.key,
    required this.item,
    this.previewTandaiSelesai = false,
    this.previewKonflik = false,
  });

  /// Frame `5.25 Ubah semaian (Butterhead)`: 150 benih, Rak 2, Aktif.
  V2SemaianEditPage.butterhead({Key? key})
    : this(key: key, item: designSemaianButterhead);

  /// Frame `5.27 Ubah semaian (Romaine)`: 200 benih, Rak 2, Aktif.
  V2SemaianEditPage.romaine({Key? key})
    : this(key: key, item: designSemaianRomaineSiapPindah);

  /// Frame `5.28 Tandai selesai, konfirmasi`: status "Selesai" dan dialog
  /// destruktif terbuka.
  V2SemaianEditPage.tandaiSelesai({Key? key})
    : this(
        key: key,
        item: designSemaianSisa,
        previewTandaiSelesai: true,
      );

  /// Frame `5.31 Data sudah berubah`: dialog konfirmasi bentrok data.
  V2SemaianEditPage.konflik({Key? key})
    : this(key: key, item: designSemaianButterhead, previewKonflik: true);

  final V2SemaianItem item;

  /// Membuka dialog "Tandai selesai?" begitu halaman tampil (frame 5.28).
  final bool previewTandaiSelesai;

  /// Membuka dialog "Data sudah berubah" begitu halaman tampil (frame 5.31).
  final bool previewKonflik;

  @override
  State<V2SemaianEditPage> createState() => _V2SemaianEditPageState();
}

class _V2SemaianEditPageState extends State<V2SemaianEditPage> {
  late final TextEditingController _jumlah = TextEditingController(
    text: '${widget.item.jumlahBenih}',
  );
  late final TextEditingController _keterangan = TextEditingController(
    text: widget.item.keterangan ?? '',
  );
  late bool _selesai = widget.item.selesai || widget.previewTandaiSelesai;
  String? _jumlahError;

  @override
  void initState() {
    super.initState();
    if (widget.previewTandaiSelesai) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _konfirmasiSelesai();
      });
    }
    if (widget.previewKonflik) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _konfirmasiUlang();
      });
    }
  }

  @override
  void dispose() {
    _jumlah.dispose();
    _keterangan.dispose();
    super.dispose();
  }

  /// Sheet "Pilih status": Aktif / Selesai. Memilih Selesai meminta konfirmasi
  /// destruktif dulu karena semaian selesai tidak bisa diubah lagi (frame 5.28).
  Future<void> _pickStatus() async {
    var draft = _selesai;
    final result = await showV2BottomSheet<bool>(
      context,
      child: StatefulBuilder(
        builder: (sheetContext, setSheet) => V2BottomSheet(
          title: 'Pilih status',
          actions: V2Button(
            label: 'Pilih',
            onPressed: () => Navigator.of(sheetContext).pop(draft),
          ),
          child: Column(
            children: [
              V2OptionRow(
                label: 'Aktif',
                state: draft ? V2OptionState.normal : V2OptionState.selected,
                onTap: () => setSheet(() => draft = false),
              ),
              const SizedBox(height: V2Space.lg),
              V2OptionRow(
                label: 'Selesai',
                state: draft ? V2OptionState.selected : V2OptionState.normal,
                onTap: () => setSheet(() => draft = true),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (!result) {
      setState(() => _selesai = false);
      return;
    }
    final confirmed = await _konfirmasiSelesai();
    if (confirmed == true) setState(() => _selesai = true);
  }

  /// Dialog destruktif "Tandai selesai?" (frame 5.28).
  Future<bool?> _konfirmasiSelesai() {
    final sisa = widget.item.sisaBenih;
    return showV2Dialog(
      context,
      type: V2DialogType.destructive,
      title: 'Tandai selesai?',
      body: sisa == null
          ? 'Semaian selesai tidak bisa diubah lagi.'
          : 'Sisa $sisa benih tidak bisa dipindah lagi. Semaian selesai tidak '
                'bisa diubah.',
      primaryLabel: 'Tandai selesai',
      secondaryLabel: 'Batal',
    );
  }

  /// Dialog "Data sudah berubah" (frame 5.31).
  Future<void> _konfirmasiUlang() async {
    await showV2Dialog(
      context,
      title: 'Data sudah berubah',
      body:
          'Data ini baru diubah di perangkat lain. Muat ulang untuk melihat '
          'versi terbaru, lalu ubah lagi.',
      primaryLabel: 'Muat ulang',
      secondaryLabel: 'Batal',
    );
  }

  void _simpan() {
    final jumlah = int.tryParse(_jumlah.text.trim());
    if (jumlah == null || jumlah <= 0) {
      setState(() => _jumlahError = 'Isi jumlah benih');
      return;
    }
    Navigator.of(context).pop(
      widget.item.copyWith(
        jumlahBenih: jumlah,
        keterangan: _keterangan.text.trim(),
        selesai: _selesai,
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
                title: 'Ubah semaian',
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
                      V2TextField(
                        label: 'Jumlah benih',
                        controller: _jumlah,
                        error: _jumlahError,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: V2Space.lg),
                      V2TextField(
                        label: 'Keterangan (opsional)',
                        controller: _keterangan,
                      ),
                      const SizedBox(height: V2Space.lg),
                      V2SelectField(
                        label: 'Status',
                        value: _selesai ? 'Selesai' : 'Aktif',
                        onTap: _pickStatus,
                      ),
                      const SizedBox(height: V2Space.lg),
                      Text(
                        'Tanggal dan bahan tidak bisa diubah.',
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