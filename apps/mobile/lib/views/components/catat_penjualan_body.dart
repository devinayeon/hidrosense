import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/penjualan_model.dart';
import '../../viewmodels/catat_penjualan_viewmodel.dart';
import '../widgets/custom_dropdown_field.dart';
import '../widgets/custom_input_field.dart';
import '../widgets/custom_text_area.dart';
import '../widgets/estimasi_total_card.dart';
import '../widgets/row_button.dart';

class CatatPenjualanBody extends ConsumerStatefulWidget {
  const CatatPenjualanBody({super.key});

  @override
  ConsumerState<CatatPenjualanBody> createState() => _CatatPenjualanBodyState();
}

class _CatatPenjualanBodyState extends ConsumerState<CatatPenjualanBody> {
  late final TextEditingController _pembeliController;
  late final TextEditingController _tanggalController;
  late final TextEditingController _beratController;
  late final TextEditingController _hargaController;
  late final TextEditingController _catatanController;

  @override
  void initState() {
    super.initState();
    _pembeliController = TextEditingController();
    _beratController = TextEditingController();
    _hargaController = TextEditingController();
    _catatanController = TextEditingController();

    // Tanggal default (hari ini) sudah ada di state ViewModel,
    // jadi tampilkan juga di field agar konsisten.
    final defaultTanggal =
        ref.read(catatPenjualanViewModelProvider).tanggal ?? DateTime.now();
    _tanggalController = TextEditingController(
      text: formatTanggalIndo(defaultTanggal),
    );

    _beratController.addListener(() {
      // Terima "2,5" maupun "2.5"
      final text = _beratController.text.replaceAll(',', '.');
      final val = double.tryParse(text) ?? 0.0;
      ref.read(catatPenjualanViewModelProvider.notifier).setBerat(val);
    });

    _hargaController.addListener(() {
      // Ambil hanya digit supaya "20.000" tidak terbaca 20.0
      final digits = _hargaController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final val = double.tryParse(digits) ?? 0.0;
      ref.read(catatPenjualanViewModelProvider.notifier).setHargaPerKg(val);
    });
  }

  @override
  void dispose() {
    _pembeliController.dispose();
    _tanggalController.dispose();
    _beratController.dispose();
    _hargaController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _pickTanggal() async {
    FocusScope.of(context).unfocus();
    final formVm = ref.read(catatPenjualanViewModelProvider.notifier);
    final current = ref.read(catatPenjualanViewModelProvider).tanggal;

    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null && mounted) {
      formVm.setTanggal(picked);
      _tanggalController.text = formatTanggalIndo(picked);
    }
  }

  Future<void> _handleSave() async {
    final formVm = ref.read(catatPenjualanViewModelProvider.notifier);

    // Sync data teks sebelum submit
    formVm.setPembeli(_pembeliController.text);
    formVm.setCatatan(_catatanController.text);

    final success = await formVm.submitPenjualan(ref);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Penjualan berhasil dicatat!'),
          backgroundColor: Color.fromRGBO(57, 198, 195, 1),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            formVm.validationMessage() ??
                'Gagal menyimpan penjualan. Coba lagi.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(catatPenjualanViewModelProvider);
    final formVm = ref.read(catatPenjualanViewModelProvider.notifier);
    final batchList = ref.watch(availableBatchPanenProvider);

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color.fromRGBO(250, 250, 247, 1),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Nama Pembeli / Klien
                  CustomInputField(
                    label: 'Nama Pembeli / Klien',
                    hintText: 'Contoh: Supermarket Jaya Makmur',
                    controller: _pembeliController,
                  ),
                  const SizedBox(height: 16),

                  // 2. Tanggal Transaksi (readOnly, pilih lewat date picker)
                  CustomInputField(
                    label: 'Tanggal Transaksi',
                    hintText: 'Pilih tanggal transaksi',
                    controller: _tanggalController,
                    readOnly: true,
                    suffixIcon: const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: Color.fromRGBO(156, 163, 175, 1),
                    ),
                    onTap: _pickTanggal,
                  ),
                  const SizedBox(height: 16),

                  // 3. Pilih Hasil Panen
                  CustomDropdownField(
                    label: 'Pilih Hasil Panen',
                    hintText: 'Pilih batch panen yang tersedia di gudang',
                    value: formState.selectedBatch?.nama,
                    items: batchList.map((b) => b.nama).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      final selected = batchList.firstWhere(
                        (b) => b.nama == val,
                        orElse: () => batchList.first,
                      );
                      formVm.setBatch(selected);
                    },
                  ),
                  const SizedBox(height: 16),

                  // 4. Baris Berat Jual (Kg) & Harga Per Kg (Rp)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CustomInputField(
                          label: 'Berat Jual (Kg)',
                          hintText: '0.0',
                          controller: _beratController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomInputField(
                          label: 'Harga Per Kg (Rp)',
                          hintText: 'Rp 20000',
                          controller: _hargaController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 5. Card Estimasi Total (Otomatis)
                  EstimasiTotalCard(totalAmount: formState.totalEstimasi),
                  const SizedBox(height: 16),

                  // 6. Status Pembayaran
                  CustomDropdownField(
                    label: 'Status Pembayaran',
                    hintText: 'Pilih Status (Lunas / Belum Lunas)',
                    value: formState.status == null
                        ? null
                        : (formState.status == StatusPenjualan.lunas
                              ? 'Lunas'
                              : 'Belum Lunas'),
                    items: const ['Lunas', 'Belum Lunas'],
                    onChanged: (val) {
                      if (val == 'Lunas') {
                        formVm.setStatus(StatusPenjualan.lunas);
                      } else if (val == 'Belum Lunas') {
                        formVm.setStatus(StatusPenjualan.belumLunas);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // 7. Catatan Transaksi
                  CustomTextArea(
                    label: 'Catatan Transaksi',
                    hintText: 'Keterangan tambahan (Metode transfer, dll)',
                    controller: _catatanController,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // 8. Tombol Simpan Penjualan
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color.fromRGBO(250, 250, 247, 1),
            child: SafeArea(
              child: RowButton(
                label: formState.isLoading
                    ? 'Menyimpan...'
                    : 'Simpan Penjualan',
                backgroundColor: const Color.fromRGBO(57, 198, 195, 1),
                textColor: Colors.white,
                borderRadius: 24,
                height: 50,
                onTap: formState.isLoading ? null : _handleSave,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
