import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../theme/app_theme.dart';
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
      color: AppColors.canvasWarm,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BaseColCard(
              backgroundColor: Colors.white,
              borderColor: AppColors.borderLight,
              borderRadius: AppRadius.modal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.lg,
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryMint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    user.name,
                    style: AppTypography.title2.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkNavy,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  CapsuleBadge(
                    label: roleLabel,
                    textColor: AppColors.accentLime,
                    backgroundColor: AppColors.darkNavy,
                    size: CapsuleSize.medium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.borderSubtle,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _detailRow(
                    icon: Icons.alternate_email_rounded,
                    bgColor: AppColors.accentMintSoft,
                    iconColor: AppColors.primaryDarkTeal,
                    text: 'Username: ${user.username}',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _detailRow(
                    icon: Icons.badge_outlined,
                    bgColor: AppColors.warningBg,
                    iconColor: AppColors.warningOrange,
                    text: 'ID Pengguna: ${user.id}',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _detailRow(
                    icon: Icons.vpn_key_outlined,
                    bgColor: AppColors.successBg,
                    iconColor: AppColors.successGreen,
                    text: 'Izin: ${user.permissions.join(', ')}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            RowInfoCardMd(
              backgroundColor: Colors.white,
              borderColor: AppColors.borderLight,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const CardIconBox(
                    iconData: Icons.shield_outlined,
                    backgroundColor: AppColors.accentMintSoft,
                    iconColor: AppColors.primaryDarkTeal,
                    width: 40,
                    height: 40,
                    borderRadius: AppRadius.input,
                    iconSize: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status Sesi',
                          style: AppTypography.headline.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Terhubung dengan otentikasi JWT backend.',
                          style: AppTypography.footnote.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: session.busy
                    ? null
                    : () {
                        HapticFeedback.heavyImpact();
                        ref.read(sessionProvider.notifier).logout();
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                icon: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.dangerRed,
                  size: 20,
                ),
                label: Text(
                  session.busy ? 'Mengeluarkan...' : 'Keluar Dari Akun',
                  style: AppTypography.headline.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.dangerRed,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.dangerBg.withOpacity(0.5),
                  side: BorderSide(
                    color: AppColors.dangerRed.withOpacity(0.4),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
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
          borderRadius: AppRadius.badge,
          iconSize: 18,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTypography.caption1.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
