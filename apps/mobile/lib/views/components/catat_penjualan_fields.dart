import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatting.dart';
import '../../models/penjualan_model.dart';
import '../../viewmodels/catat_penjualan_viewmodel.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_dropdown_field.dart';
import '../widgets/custom_input_field.dart';
import '../widgets/custom_text_area.dart';
import '../widgets/estimasi_total_card.dart';
import '../widgets/row_button.dart';
import '../widgets/sale_multi_batch_notice.dart';

/// Tombol simpan di bawah formulir (Apple HIG 52pt pill button).
class CatatPenjualanSaveBar extends StatelessWidget {
  const CatatPenjualanSaveBar({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.canvasWarm,
      child: SafeArea(
        child: RowButton(
          label: label,
          backgroundColor: AppColors.primaryMint,
          textColor: Colors.white,
          borderRadius: AppRadius.pill,
          height: 52,
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Kolom-kolom formulir penjualan. Saat [locked], isian tidak bisa diubah lewat
/// sentuhan maupun papan ketik, dan stok tidak ditampilkan karena batch yang
/// dipulihkan belum tentu punya angka stok asli.
class CatatPenjualanFields extends StatelessWidget {
  const CatatPenjualanFields({
    super.key,
    required this.formState,
    required this.formVm,
    required this.batchList,
    required this.itemToEdit,
    required this.locked,
    required this.pembeli,
    required this.tanggal,
    required this.berat,
    required this.harga,
    required this.catatan,
    required this.onPickTanggal,
  });

  final CatatPenjualanState formState;
  final CatatPenjualanViewModel formVm;
  final List<BatchPanen> batchList;
  final PenjualanItem? itemToEdit;
  final bool locked;
  final TextEditingController pembeli, tanggal, berat, harga, catatan;
  final VoidCallback onPickTanggal;

  @override
  Widget build(BuildContext context) {
    final item = itemToEdit;
    final headerOnly = item != null && item.details.length != 1;
    final selected = formState.selectedBatch;
    return IgnorePointer(
      key: const ValueKey('sale-form-fields'),
      ignoring: locked,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Nama Pembeli / Klien
          CustomInputField(
            label: 'Nama Pembeli / Klien',
            hintText: 'Contoh: Supermarket Jaya Makmur',
            controller: pembeli,
            readOnly: locked,
          ),
          const SizedBox(height: AppSpacing.md),

          // 2. Tanggal Transaksi (readOnly, pilih lewat date picker)
          CustomInputField(
            label: 'Tanggal Transaksi',
            hintText: 'Pilih tanggal transaksi',
            controller: tanggal,
            readOnly: true,
            suffixIcon: const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: AppColors.textTertiary,
            ),
            onTap: locked ? null : onPickTanggal,
          ),
          const SizedBox(height: AppSpacing.md),

          // 3. Pilih Hasil Panen — hanya untuk transaksi satu batch.
          if (!headerOnly) ...[
            CustomDropdownField(
              label: 'Pilih Hasil Panen',
              hintText: 'Pilih batch panen yang tersedia di gudang',
              value: selected?.nama,
              items: batchList.map((batch) => batch.nama).toList(),
              onChanged: (val) {
                if (val == null) return;
                formVm.setBatch(
                  batchList.firstWhere(
                    (batch) => batch.nama == val,
                    orElse: () => batchList.first,
                  ),
                );
              },
            ),
            if (selected != null && !locked) ...[
              const SizedBox(height: 4),
              Text(
                'Stok tersedia: ${formatAngka(selected.stokTersedia)} Kg',
                style: AppTypography.footnote.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ] else
            SaleMultiBatchNotice(item: item),
          if (item != null && !item.canEdit) ...[
            const SizedBox(height: 8),
            Text(
              'Data versi transaksi tidak tersedia. Muat ulang daftar '
              'sebelum mengedit.',
              style: AppTypography.footnote.copyWith(
                color: AppColors.dangerRed,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),

          // 4. Baris Berat Jual (Kg) & Harga Per Kg (Rp)
          if (!headerOnly) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _decimalField('Berat Jual (Kg)', '0.0', berat)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _decimalField(
                    'Harga Per Kg (Rp)',
                    'Rp 20000.50',
                    harga,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // 5. Card Estimasi Total (Otomatis)
            EstimasiTotalCard(totalAmount: formState.totalEstimasi),
          ],
          const SizedBox(height: AppSpacing.md),

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
          const SizedBox(height: AppSpacing.md),

          // 7. Catatan Transaksi
          CustomTextArea(
            label: 'Catatan Transaksi',
            hintText: 'Keterangan tambahan (Metode transfer, dll)',
            controller: catatan,
            maxLines: 3,
            readOnly: locked,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _decimalField(
    String label,
    String hint,
    TextEditingController controller,
  ) {
    return CustomInputField(
      label: label,
      hintText: hint,
      controller: controller,
      readOnly: locked,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
    );
  }
}
