import 'package:flutter/material.dart';
import '../../models/weather_model.dart';
import '../components/header.dart';
import '../components/rekomendasi_cuaca_body.dart';

class RekomendasiCuacaPage extends StatelessWidget {
  final PrakiraanHarian prakiraanItem;

  const RekomendasiCuacaPage({super.key, required this.prakiraanItem});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Header(
        titleText: 'Rekomendasi ${prakiraanItem.waktu.split(' ').first}',
        showBackButton: true,
      ),
      body: RekomendasiCuacaBody(item: prakiraanItem),
    );
  }
}
