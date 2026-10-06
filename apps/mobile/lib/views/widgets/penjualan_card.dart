import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/penjualan_model.dart';
import 'capsule_badge.dart';

class PenjualanCard extends StatelessWidget {
  final PenjualanItem item;
  final VoidCallback? onTap;

  const PenjualanCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final String statusText = item.isLunas ? 'LUNAS' : 'BELUM LUNAS';
    final Color badgeBg = item.isLunas
        ? const Color.fromRGBO(240, 251, 251, 1)
        : const Color.fromRGBO(255, 243, 236, 1);
    final Color badgeText = item.isLunas
        ? const Color.fromRGBO(57, 198, 195, 1)
        : const Color.fromRGBO(255, 154, 85, 1);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color.fromRGBO(240, 240, 235, 1),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Info Pembeli & Tanggal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.pembeli,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color.fromRGBO(23, 34, 49, 1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.tanggal} • ${item.kuantitas}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                        color: Color.fromRGBO(107, 114, 128, 1),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Total Harga & Badge Status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currencyFormatter.format(item.totalHarga),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color.fromRGBO(23, 34, 49, 1),
                    ),
                  ),
                  const SizedBox(height: 4),
                  CapsuleBadge(
                    label: statusText,
                    textColor: badgeText,
                    backgroundColor: badgeBg,
                    borderColor: badgeText,
                    size: CapsuleSize.small,
                    fontWeight: FontWeight.w700,
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
