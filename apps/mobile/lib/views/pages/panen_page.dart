import 'package:flutter/material.dart';
import '../components/header.dart';
import '../components/panen_body.dart';
import '../widgets/harvest_access.dart';

class PanenPage extends StatelessWidget {
  const PanenPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: Header(
      titleText: 'Data Panen',
      showBackButton: true,
      showUserIcon: false,
      toolbarHeight:
          56 + (MediaQuery.textScalerOf(context).scale(24) - 24) * 4.2,
      titleMaxLines: 3,
      useThemeColors: true,
    ),
    body: HarvestAccess(child: PanenBody()),
  );
}
