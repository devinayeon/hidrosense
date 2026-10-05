import 'package:flutter/material.dart';
import '../../models/panen_model.dart';
import '../components/header.dart';
import '../components/panen_form_body.dart';

class PanenFormPage extends StatelessWidget {
  final PanenItem? itemToEdit;

  const PanenFormPage({super.key, this.itemToEdit});

  @override
  Widget build(BuildContext context) {
    final bool isEdit = itemToEdit != null;

    return Scaffold(
      appBar: Header(
        titleText: isEdit ? 'Edit Hasil Panen' : 'Tambah Hasil Panen',
        showBackButton: true,
      ),
      body: PanenFormBody(itemToEdit: itemToEdit),
    );
  }
}
