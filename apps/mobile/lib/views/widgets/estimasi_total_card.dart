import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EstimasiTotalCard extends StatelessWidget {
  final double totalAmount;

  const EstimasiTotalCard({super.key, required this.totalAmount});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color.fromRGBO(229, 231, 235, 1),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Estimasi Total (Otomatis)',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color.fromRGBO(23, 34, 49, 1),
            ),
          ),
          Text(
            currencyFormatter.format(totalAmount),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color.fromRGBO(23, 34, 49, 1),
            ),
          ),
        ],
      ),
    );
  }
}
