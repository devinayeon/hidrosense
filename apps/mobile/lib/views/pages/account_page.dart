import 'package:flutter/material.dart';
import '../components/account_body.dart';
import '../components/header.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: Header(
        titleText: 'Pengguna',
        showBackButton: true,
        showUserIcon: false, // Icon user hilang saat berada di menu Akun
      ),
      body: AccountBody(),
    );
  }
}
