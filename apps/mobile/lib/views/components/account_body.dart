import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/account_viewmodel.dart';
import '../widgets/base_col_card.dart';
import '../widgets/capsule_badge.dart';
import '../widgets/card_icon_box.dart';
import '../widgets/row_info_card_md.dart';

class AccountBody extends ConsumerWidget {
  const AccountBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(accountViewModelProvider);

    if (accountState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color.fromRGBO(57, 198, 195, 1),
        ),
      );
    }

    final user = accountState.data;
    if (user == null) return const SizedBox.shrink();

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
            // 1. Profil Main Card
            BaseColCard(
              backgroundColor: Colors.white,
              borderColor: const Color.fromRGBO(230, 230, 225, 1),
              borderRadius: 24,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color.fromRGBO(57, 198, 195, 1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Nama User
                  Text(
                    user.nama,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: Color.fromRGBO(23, 34, 49, 1),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Badge Peran
                  CapsuleBadge(
                    label: user.peran,
                    textColor: const Color.fromRGBO(221, 244, 90, 1),
                    backgroundColor: const Color.fromRGBO(23, 34, 49, 1),
                    size: CapsuleSize.medium,
                  ),
                  const SizedBox(height: 16),

                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color.fromRGBO(240, 240, 235, 1),
                  ),
                  const SizedBox(height: 16),

                  // List Detail Kontak & Perkebunan
                  _buildDetailRow(
                    icon: Icons.alternate_email_rounded,
                    bgColor: const Color.fromRGBO(230, 247, 247, 1),
                    iconColor: const Color.fromRGBO(57, 198, 195, 1),
                    text: 'Nama Pengguna: ${user.username}',
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    icon: Icons.phone_outlined,
                    bgColor: const Color.fromRGBO(255, 243, 236, 1),
                    iconColor: const Color.fromRGBO(255, 154, 85, 1),
                    text: 'Kontak WhatsApp: ${user.noWhatsApp}',
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    icon: Icons.location_on_outlined,
                    bgColor: const Color.fromRGBO(240, 250, 220, 1),
                    iconColor: const Color.fromRGBO(130, 180, 20, 1),
                    text: 'ID Perkebunan: ${user.idPerkebunan}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Status Sinkronisasi Card
            RowInfoCardMd(
              backgroundColor: const Color.fromRGBO(240, 251, 251, 1),
              borderColor: const Color.fromRGBO(57, 198, 195, 1),
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CardIconBox(
                    iconData: Icons.adjust_rounded,
                    backgroundColor: Color.fromRGBO(57, 198, 195, 1),
                    iconColor: Colors.white,
                    width: 40,
                    height: 40,
                    borderRadius: 12,
                    iconSize: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status Sinkronisasi',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.statusSinkronisasi,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            fontSize: 11,
                            height: 1.3,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. Section Pengaturan Dasar
            const Text(
              'PENGATURAN DASAR',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color.fromRGBO(57, 198, 195, 1),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),

            BaseColCard(
              backgroundColor: Colors.white,
              borderColor: const Color.fromRGBO(230, 230, 225, 1),
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.shield_outlined,
                    bgColor: const Color.fromRGBO(230, 247, 247, 1),
                    iconColor: const Color.fromRGBO(57, 198, 195, 1),
                    title: 'Keamanan & Kata Sandi',
                    onTap: () {},
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color.fromRGBO(240, 240, 235, 1),
                  ),
                  _buildMenuItem(
                    icon: Icons.settings_outlined,
                    bgColor: const Color.fromRGBO(255, 243, 236, 1),
                    iconColor: const Color.fromRGBO(255, 154, 85, 1),
                    title: 'Konfigurasi Alat & BMKG',
                    onTap: () {},
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color.fromRGBO(240, 240, 235, 1),
                  ),
                  _buildMenuItem(
                    icon: Icons.notifications_none_rounded,
                    bgColor: const Color.fromRGBO(240, 250, 220, 1),
                    iconColor: const Color.fromRGBO(130, 180, 20, 1),
                    title: 'Pemberitahuan Sistem (Telegram)',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. Tombol Keluar
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Color.fromRGBO(255, 154, 85, 1),
                  size: 20,
                ),
                label: const Text(
                  'Keluar Dari Akun',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color.fromRGBO(255, 154, 85, 1),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(255, 248, 242, 1),
                  side: const BorderSide(
                    color: Color.fromRGBO(255, 154, 85, 1),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Helper untuk baris detail kontak
  Widget _buildDetailRow({
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

  // Helper untuk item menu pengaturan
  Widget _buildMenuItem({
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            CardIconBox(
              iconData: icon,
              backgroundColor: bgColor,
              iconColor: iconColor,
              width: 36,
              height: 36,
              borderRadius: 12,
              iconSize: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Colors.black38,
            ),
          ],
        ),
      ),
    );
  }
}
