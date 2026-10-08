import 'package:flutter/material.dart';
import '../../../../views/theme/app_theme.dart';
import '../../../../views/widgets/base_col_card.dart';
import '../../../../views/widgets/capsule_badge.dart';
import '../../data/models/employee_model.dart';

class EmployeeTile extends StatelessWidget {
  const EmployeeTile({
    super.key,
    required this.employee,
    required this.onEdit,
    required this.onToggleStatus,
  });

  final EmployeeModel employee;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final isActive = employee.isActive;

    return BaseColCard(
      backgroundColor: Colors.white,
      borderColor: AppColors.borderLight,
      borderRadius: AppRadius.card,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.accentMintSoft : AppColors.secondarySurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: isActive ? AppColors.primaryDarkTeal : AppColors.textTertiary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.nama,
                      style: AppTypography.headline.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isActive ? AppColors.textPrimary : AppColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${employee.username}',
                      style: AppTypography.footnote.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              CapsuleBadge(
                label: isActive ? 'Aktif' : 'Nonaktif',
                textColor: isActive ? AppColors.successGreen : AppColors.textSecondary,
                backgroundColor: isActive ? AppColors.successBg : AppColors.secondarySurface,
                size: CapsuleSize.small,
              ),
              const SizedBox(width: AppSpacing.xs),
              SizedBox(
                width: 44,
                height: 44,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.input),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'toggle') {
                      onToggleStatus();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: AppColors.textPrimary),
                          SizedBox(width: AppSpacing.xs),
                          Text('Ubah Data', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                            size: 18,
                            color: isActive ? AppColors.dangerRed : AppColors.primaryDarkTeal,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            isActive ? 'Nonaktifkan' : 'Aktifkan Kembali',
                            style: TextStyle(
                              fontSize: 14,
                              color: isActive ? AppColors.dangerRed : AppColors.primaryDarkTeal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (employee.noTelepon != null || employee.email != null) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1, thickness: 1, color: AppColors.borderSubtle),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xxs,
              children: [
                if (employee.noTelepon != null && employee.noTelepon!.isNotEmpty)
                  _infoChip(Icons.phone_outlined, employee.noTelepon!),
                if (employee.email != null && employee.email!.isNotEmpty)
                  _infoChip(Icons.email_outlined, employee.email!),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTypography.caption1.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
