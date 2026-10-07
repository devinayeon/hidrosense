// lib/views/components/form_catat_kerusakan_body.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/baris_tanam_model.dart';
import '../../models/laporan_kerusakan_model.dart';
import '../../models/meja_nft_model.dart';
import '../../viewmodels/baris_tanam_viewmodel.dart';
import '../widgets/custom_input_field.dart';
import '../widgets/item_image_placeholder.dart';
import '../widgets/row_button.dart';

class FormCatatKerusakanBody extends ConsumerStatefulWidget {
  final MejaNft mejaItem;
  final BarisTanam? initialBaris;

  const FormCatatKerusakanBody({
    super.key,
    required this.mejaItem,
    this.initialBaris,
  });

  @override
  ConsumerState<FormCatatKerusakanBody> createState() =>
      _FormCatatKerusakanBodyState();
}

class _FormCatatKerusakanBodyState
    extends ConsumerState<FormCatatKerusakanBody> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _mejaController;
  late TextEditingController _barisController;
  late TextEditingController _jumlahRusakController;
  late TextEditingController _kategoriController;
  late TextEditingController _tanggalController;
  late TextEditingController _penyebabController;

  BarisTanam? _selectedBaris;
  DateTime _selectedDate = DateTime.now();
  String? _uploadedPhotoPath;

  final List<String> _kategoriOptions = [
    'Gagal Tumbuh / Busuk Akar',
    'Terserang Hama Ulat / Kutu',
    'Daun Menguning / Layu',
    'Batang Patah / Damaged',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _selectedBaris = widget.initialBaris;

    _mejaController = TextEditingController(text: widget.mejaItem.name);
    _barisController = TextEditingController(
      text: _selectedBaris != null
          ? '${_selectedBaris!.name} (${_selectedBaris!.holesRange})'
          : '',
    );
    _jumlahRusakController = TextEditingController();
    _kategoriController = TextEditingController(
      text: 'Gagal Tumbuh / Busuk Akar',
    );
    _tanggalController = TextEditingController(
      text: _formatDate(_selectedDate),
    );
    _penyebabController = TextEditingController();
  }

  @override
  void dispose() {
    _mejaController.dispose();
    _barisController.dispose();
    _jumlahRusakController.dispose();
    _kategoriController.dispose();
    _tanggalController.dispose();
    _penyebabController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    return '$day $month ${date.year}';
  }

  void _selectBarisDialog(List<BarisTanam> allBaris) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih Baris / Rentang Lubang',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Color.fromRGBO(23, 34, 49, 1),
                ),
              ),
              const SizedBox(height: 12),
              ...allBaris.map((baris) {
                return ListTile(
                  title: Text(
                    '${baris.name} (${baris.holesRange})',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedBaris = baris;
                      _barisController.text =
                          '${baris.name} (${baris.holesRange})';
                    });
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _selectKategoriDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih Kategori Kegagalan',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Color.fromRGBO(23, 34, 49, 1),
                ),
              ),
              const SizedBox(height: 12),
              ..._kategoriOptions.map((kat) {
                return ListTile(
                  title: Text(
                    kat,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _kategoriController.text = kat;
                    });
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color.fromRGBO(57, 198, 195, 1),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _tanggalController.text = _formatDate(picked);
      });
    }
  }

  void _handleSubmit() {
    if (_selectedBaris == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih baris terlebih dahulu')),
      );
      return;
    }

    final jumlahText = _jumlahRusakController.text.trim();
    final int? jumlah = int.tryParse(jumlahText);

    if (jumlah == null || jumlah <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan jumlah rusak yang valid')),
      );
      return;
    }

    final laporan = LaporanKerusakan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      mejaId: widget.mejaItem.id,
      mejaName: widget.mejaItem.name,
      barisId: _selectedBaris!.id,
      barisName: _selectedBaris!.name,
      jumlahRusak: jumlah,
      kategoriKegagalan: _kategoriController.text,
      tanggalDitemukan: _selectedDate,
      penyebabUtama: _penyebabController.text.isNotEmpty
          ? _penyebabController.text
          : null,
      fotoUrl: _uploadedPhotoPath,
    );

    // Update state via Riverpod ViewModel
    ref
        .read(barisTanamViewModelProvider.notifier)
        .submitLaporanKerusakan(laporan);

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Laporan kerusakan berhasil disimpan'),
        backgroundColor: Color.fromRGBO(57, 198, 195, 1),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final allBaris = ref.watch(barisTanamViewModelProvider);

    return Container(
      color: const Color.fromRGBO(250, 250, 247, 1),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Pilih Meja / Lokasi (Read Only)
              CustomInputField(
                label: 'Pilih Meja / Lokasi',
                hintText: 'Meja NFT #01',
                controller: _mejaController,
                readOnly: true,
              ),
              const SizedBox(height: 16),

              // 2. Pilih Baris / Rentang Lubang
              CustomInputField(
                label: 'Pilih Baris / Rentang Lubang',
                hintText: 'Pilih Baris',
                controller: _barisController,
                readOnly: true,
                suffixIcon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color.fromRGBO(156, 163, 175, 1),
                ),
                onTap: () => _selectBarisDialog(allBaris),
              ),
              const SizedBox(height: 16),

              // 3. Jumlah Rusak (Lubang)
              CustomInputField(
                label: 'Jumlah Rusak (Lubang)',
                hintText: 'Masukkan jumlah bibit rusak (misal: 4)',
                controller: _jumlahRusakController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // 4. Kategori Kegagalan
              CustomInputField(
                label: 'Kategori Kegagalan',
                hintText: 'Pilih Kategori',
                controller: _kategoriController,
                readOnly: true,
                suffixIcon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color.fromRGBO(156, 163, 175, 1),
                ),
                onTap: _selectKategoriDialog,
              ),
              const SizedBox(height: 16),

              // 5. Tanggal Ditemukan
              CustomInputField(
                label: 'Tanggal Ditemukan',
                hintText: 'Pilih Tanggal',
                controller: _tanggalController,
                readOnly: true,
                suffixIcon: const Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: Color.fromRGBO(156, 163, 175, 1),
                ),
                onTap: _pickDate,
              ),
              const SizedBox(height: 16),

              // 6. Penyebab Utama (Estimasi)
              CustomInputField(
                label: 'Penyebab Utama (Estimasi)',
                hintText: 'Sumbatan air nutrisi / Hama ulat',
                controller: _penyebabController,
              ),
              const SizedBox(height: 16),

              // 7. Bukti Foto (Opsional)
              const Text(
                'Bukti Foto (Opsional)',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color.fromRGBO(23, 34, 49, 1),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  // Action upload foto
                },
                child: ItemImagePlaceholder(
                  imageUrl: _uploadedPhotoPath,
                  height: 100,
                  placeholderText: 'UNGGAH FOTO DAUN/AKAR YANG RUSAK',
                ),
              ),
              const SizedBox(height: 24),

              // 8. Tombol Simpan Laporan Kerusakan
              RowButton(
                label: 'Simpan Laporan Kerusakan',
                backgroundColor: const Color.fromRGBO(57, 198, 195, 1),
                textColor: Colors.white,
                borderRadius: 24,
                height: 50,
                onTap: _handleSubmit,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
