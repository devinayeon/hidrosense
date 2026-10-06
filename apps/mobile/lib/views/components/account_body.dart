import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../widgets/base_col_card.dart';
import '../widgets/capsule_badge.dart';
import '../widgets/card_icon_box.dart';
import '../widgets/row_info_card_md.dart';

class AccountBody extends ConsumerWidget {
  const AccountBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = session.user;
    if (user == null) return const SizedBox.shrink();

    final roleLabel = user.role == 'petani' ? 'Petani' : 'Pegawai';

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color.fromRGBO(250, 250, 247, 1),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BaseColCard(
              backgroundColor: Colors.white,
              borderColor: const Color.fromRGBO(230, 230, 225, 1),
              borderRadius: 24,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color.fromRGBO(57, 198, 195, 1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_outline, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: Color.fromRGBO(23, 34, 49, 1),
                    ),
                  ),
                  const SizedBox(height: 6),
                  CapsuleBadge(
                    label: roleLabel,
                    textColor: const Color.fromRGBO(221, 244, 90, 1),
                    backgroundColor: const Color.fromRGBO(23, 34, 49, 1),
                    size: CapsuleSize.medium,
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, thickness: 1, color: Color.fromRGBO(240, 240, 235, 1)),
                  const SizedBox(height: 16),
                  _detailRow(
                    icon: Icons.alternate_email_rounded,
                    bgColor: const Color.fromRGBO(230, 247, 247, 1),
                    iconColor: const Color.fromRGBO(57, 198, 195, 1),
                    text: 'Username: ${user.username}',
                  ),
                  const SizedBox(height: 12),
                  _detailRow(
                    icon: Icons.badge_outlined,
                    bgColor: const Color.fromRGBO(255, 243, 236, 1),
                    iconColor: const Color.fromRGBO(255, 154, 85, 1),
                    text: 'ID Pengguna: ${user.id}',
                  ),
                  const SizedBox(height: 12),
                  _detailRow(
                    icon: Icons.vpn_key_outlined,
                    bgColor: const Color.fromRGBO(240, 250, 220, 1),
                    iconColor: const Color.fromRGBO(130, 180, 20, 1),
                    text: 'Izin: ${user.permissions.join(', ')}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const RowInfoCardMd(
              backgroundColor: Color.fromRGBO(240, 251, 251, 1),
              borderColor: Color.fromRGBO(57, 198, 195, 1),
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  CardIconBox(
                    iconData: Icons.adjust_rounded,
                    backgroundColor: Color.fromRGBO(57, 198, 195, 1),
                    iconColor: Colors.white,
                    width: 40,
                    height: 40,
                    borderRadius: 12,
                    iconSize: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status Sesi',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Terhubung dengan otentikasi JWT backend.',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: session.busy
                    ? null
                    : () {
                        ref.read(sessionProvider.notifier).logout();
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Color.fromRGBO(255, 154, 85, 1),
                  size: 20,
                ),
                label: Text(
                  session.busy ? 'Mengeluarkan...' : 'Keluar Dari Akun',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color.fromRGBO(255, 154, 85, 1),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(255, 248, 242, 1),
                  side: const BorderSide(color: Color.fromRGBO(255, 154, 85, 1), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  static Widget _detailRow({
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required String text,
  }) {
    return Row(
      children: [
        CardIconBox(
          iconData: icon,
          backgroundColor: bgColor,
          iconColor: iconColor,
          width: 32,
          height: 32,
          borderRadius: 10,
          iconSize: 18,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
