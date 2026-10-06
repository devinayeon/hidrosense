import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/panen_model.dart';
import '../../viewmodels/panen_viewmodel.dart';
import '../widgets/custom_input_field.dart';
import '../widgets/custom_text_area.dart';
import '../widgets/row_button.dart';

class PanenFormBody extends ConsumerStatefulWidget {
  final PanenItem? itemToEdit;

  const PanenFormBody({super.key, this.itemToEdit});

  @override
  ConsumerState<PanenFormBody> createState() => _PanenFormBodyState();
}

class _PanenFormBodyState extends ConsumerState<PanenFormBody> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _mejaController;
  late TextEditingController _tanggalController;
  late TextEditingController _beratTotalController;
  late TextEditingController _hargaEstimasiController;
  late TextEditingController _layakController;
  late TextEditingController _rejectController;
  late TextEditingController _catatanController;

  bool get isEdit => widget.itemToEdit != null;

  @override
  void initState() {
    super.initState();
    final item = widget.itemToEdit;

    _mejaController = TextEditingController(text: item?.asalMejaTanam ?? '');
    _tanggalController = TextEditingController(text: item?.processedDate ?? '');
    _beratTotalController = TextEditingController(
      text: item?.totalWeight.replaceAll(RegExp(r'[^0-9.]'), '') ?? '',
    );
    _hargaEstimasiController = TextEditingController(
      text: item?.hargaEstimasi ?? '',
    );
    _layakController = TextEditingController(text: item?.jumlahLayak ?? '');
    _rejectController = TextEditingController(text: item?.jumlahReject ?? '');
    _catatanController = TextEditingController(text: item?.catatanPanen ?? '');
  }

  @override
  void dispose() {
    _mejaController.dispose();
    _tanggalController.dispose();
    _beratTotalController.dispose();
    _hargaEstimasiController.dispose();
    _layakController.dispose();
    _rejectController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  void _saveForm() {
    final meja = _mejaController.text.trim();
    final tanggal = _tanggalController.text.trim();
    final berat = _beratTotalController.text.trim();
    final harga = _hargaEstimasiController.text.trim();
    final layak = _layakController.text.trim();
    final reject = _rejectController.text.trim();
    final catatan = _catatanController.text.trim();

    if (meja.isEmpty || berat.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap isi asal meja dan berat total')),
      );
      return;
    }

    final double totalW = double.tryParse(berat) ?? 0;
    final double rejectW = double.tryParse(reject) ?? 0;
    final double layakPercentNum = totalW > 0
        ? ((totalW - rejectW) / totalW) * 100
        : 100;
    final double rejectPercentNum = totalW > 0 ? (rejectW / totalW) * 100 : 0;

    if (isEdit) {
      final updatedItem = widget.itemToEdit!.copyWith(
        asalMejaTanam: meja,
        processedDate: tanggal.isEmpty ? 'Hari ini' : tanggal,
        totalWeight: '$berat Kg',
        hargaEstimasi: harga,
        jumlahLayak: layak,
        jumlahReject: reject,
        catatanPanen: catatan,
        layakPercent: '${layakPercentNum.toStringAsFixed(1)}%',
        rejectPercent: '${rejectPercentNum.toStringAsFixed(1)}%',
        rejectWeight: '$reject Kg',
        status: PanenStatus.selesai,
      );
      ref.read(panenViewModelProvider.notifier).updatePanen(updatedItem);
    } else {
      final newItem = PanenItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Panen $meja',
        batchName: 'Batch Baru',
        mejaInfo: meja,
        dateText: 'Hari ini',
        processedDate: tanggal.isEmpty ? 'Hari ini' : tanggal,
        resultText: 'Hasil: $berat Kg • Catat Baru',
        status: PanenStatus.selesai,
        totalWeight: '$berat Kg',
        targetWeight: '$berat Kg',
        layakPercent: '${layakPercentNum.toStringAsFixed(1)}%',
        rejectPercent: '${rejectPercentNum.toStringAsFixed(1)}%',
        rejectWeight: '$reject Kg',
        asalMejaTanam: meja,
        varietas: 'Selada Hydroponic',
        lamaBudidaya: '30 Hari',
        gradeKualitas: 'A (Layak Jual)',
        hargaEstimasi: harga,
        jumlahLayak: layak,
        jumlahReject: reject,
        catatanPanen: catatan,
      );
      ref.read(panenViewModelProvider.notifier).addPanen(newItem);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color.fromRGBO(250, 250, 247, 1),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Pilih Meja / Batch Semai
              CustomInputField(
                label: 'Pilih Meja / Batch Semai',
                hintText: 'Pilih asal meja NFT atau Batch semaian',
                controller: _mejaController,
              ),
              const SizedBox(height: 16),

              // 2. Tanggal Panen
              CustomInputField(
                label: 'Tanggal Panen',
                hintText: 'Masukkan tanggal panen (Hari ini)',
                controller: _tanggalController,
              ),
              const SizedBox(height: 16),

              // 3. Row Berat Total & Harga Estimasi
              Row(
                children: [
                  Expanded(
                    child: CustomInputField(
                      label: 'Berat Total (Kg)',
                      hintText: '0.0',
                      controller: _beratTotalController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomInputField(
                      label: 'Harga Estimasi / Kg (Rp)',
                      hintText: 'Rp 20.000',
                      controller: _hargaEstimasiController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 4. Row Jumlah Layak Jual & Reject/Rusak
              Row(
                children: [
                  Expanded(
                    child: CustomInputField(
                      label: 'Jumlah Layak Jual',
                      hintText: '0 ikat/pcs',
                      controller: _layakController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomInputField(
                      label: 'Jumlah Reject/Rusak',
                      hintText: '0 ikat/pcs',
                      controller: _rejectController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 5. Catatan Panen
              CustomTextArea(
                label: 'Catatan Panen',
                hintText: 'Tuliskan catatan kondisi tanaman pasca-panen',
                controller: _catatanController,
              ),
              const SizedBox(height: 28),

              // 6. Button Simpan
              RowButton(
                label: isEdit ? 'Simpan Perubahan' : 'Simpan Hasil Panen',
                backgroundColor: const Color.fromRGBO(57, 198, 195, 1),
                textColor: Colors.white,
                borderRadius: 24,
                height: 52,
                onTap: _saveForm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
