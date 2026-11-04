import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../views/components/header.dart';
import '../../../../views/theme/app_theme.dart';
import '../../data/models/employee_model.dart';
import '../viewmodels/employee_viewmodel.dart';
import '../widgets/employee_dialogs.dart';
import '../widgets/employee_form_sheet.dart';
import '../widgets/employee_tile.dart';

class EmployeeListPage extends ConsumerStatefulWidget {
  const EmployeeListPage({super.key});

  @override
  ConsumerState<EmployeeListPage> createState() => _EmployeeListPageState();
}

class _EmployeeListPageState extends ConsumerState<EmployeeListPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddSheet() {
    final notifier = ref.read(employeeViewModelProvider.notifier);
    notifier.clearSaveError();
    notifier.startOnboarding();
    EmployeeFormSheet.show(
      context,
      onSubmit:
          ({
            required String nama,
            required String username,
            String? password,
            String? email,
            String? noTelepon,
            String? alamat,
            required Duration duration,
            int retryCount = 0,
          }) {
            return ref
                .read(employeeViewModelProvider.notifier)
                .createEmployee(
                  nama: nama,
                  username: username,
                  password: password!,
                  email: email,
                  noTelepon: noTelepon,
                  alamat: alamat,
                  duration: duration,
                  retryCount: retryCount,
                );
          },
    );
  }

  void _openEditSheet(EmployeeModel employee) {
    ref.read(employeeViewModelProvider.notifier).clearSaveError();
    EmployeeFormSheet.show(
      context,
      employee: employee,
      onSubmit:
          ({
            required String nama,
            required String username,
            String? password,
            String? email,
            String? noTelepon,
            String? alamat,
            required Duration duration,
            int retryCount = 0,
          }) {
            return ref
                .read(employeeViewModelProvider.notifier)
                .updateEmployee(
                  employee.id,
                  nama: nama,
                  username: username,
                  password: password,
                  email: email,
                  noTelepon: noTelepon,
                  alamat: alamat,
                );
          },
    );
  }

  Future<void> _handleToggleStatus(EmployeeModel employee) async {
    final notifier = ref.read(employeeViewModelProvider.notifier);
    if (employee.isActive) {
      final confirmed = await EmployeeDialogs.confirmDeactivation(
        context,
        employee,
      );
      if (confirmed) {
        await notifier.deactivateEmployee(employee.id, employee.nama);
      } else {
        notifier.cancelDeactivation(employee.id);
      }
    } else {
      final confirmed = await EmployeeDialogs.confirmActivation(
        context,
        employee,
      );
      if (confirmed) {
        await notifier.activateEmployee(employee.id, employee.nama);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeeViewModelProvider);

    ref.listen<EmployeeListState>(employeeViewModelProvider, (prev, next) {
      final error = next.actionError ?? next.errorMessage;
      final previousError = prev?.actionError ?? prev?.errorMessage;
      if (error != null && error != previousError) {
        _showSnackBar(error, AppColors.dangerRed);
      } else if (next.actionSuccessMessage != null &&
          next.actionSuccessMessage != prev?.actionSuccessMessage) {
        _showSnackBar(next.actionSuccessMessage!, AppColors.primaryDarkTeal);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.canvasWarm,
      appBar: const Header(
        titleText: 'Kelola Pegawai',
        showBackButton: true,
        showUserIcon: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        backgroundColor: AppColors.primaryDarkTeal,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.person_add_rounded, size: 20),
        label: Text(
          'Tambah Pegawai',
          style: AppTypography.headline.copyWith(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    ref
                        .read(employeeViewModelProvider.notifier)
                        .onSearchChanged(val);
                  },
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau username pegawai...',
                    hintStyle: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textTertiary,
                      size: 20,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(employeeViewModelProvider.notifier)
                                  .onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.secondarySurface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Filter segmented bar
                Row(
                  children: [
                    _filterChip(
                      label: 'Semua',
                      isSelected: state.filterStatus == null,
                      onTap: () => ref
                          .read(employeeViewModelProvider.notifier)
                          .setFilter(null),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _filterChip(
                      label: 'Aktif',
                      count: state.totalActive,
                      isSelected: state.filterStatus == 1,
                      onTap: () => ref
                          .read(employeeViewModelProvider.notifier)
                          .setFilter(1),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _filterChip(
                      label: 'Nonaktif',
                      count: state.totalInactive,
                      isSelected: state.filterStatus == 0,
                      onTap: () => ref
                          .read(employeeViewModelProvider.notifier)
                          .setFilter(0),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primaryDarkTeal,
              onRefresh: () =>
                  ref.read(employeeViewModelProvider.notifier).loadEmployees(),
              child: state.isLoading && !state.hasAnyEmployees
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryDarkTeal,
                      ),
                    )
                  : state.errorMessage != null && !state.hasAnyEmployees
                  ? _buildErrorState(state.errorMessage!)
                  : !state.hasAnyEmployees
                  ? _buildEmptyState()
                  : state.employees.isEmpty
                  ? _buildNoResultsState()
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.only(
                        left: AppSpacing.md,
                        right: AppSpacing.md,
                        top: AppSpacing.md,
                        bottom: 80, // FAB clearance
                      ),
                      itemCount: state.employees.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final emp = state.employees[index];
                        return EmployeeTile(
                          employee: emp,
                          onEdit: () => _openEditSheet(emp),
                          onToggleStatus: () => _handleToggleStatus(emp),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    int? count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final displayText = count != null ? '$label ($count)' : label;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkNavy : AppColors.secondarySurface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          displayText,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return _buildStateMessage(
      icon: Icons.people_outline_rounded,
      title: 'Belum Ada Pegawai',
      message:
          'Tambahkan akun pegawai untuk membantu operasional perkebunan hidroponik Anda.',
      action: OutlinedButton.icon(
        onPressed: _openAddSheet,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Tambah Pegawai Pertama'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDarkTeal,
          side: const BorderSide(color: AppColors.primaryDarkTeal, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return _buildStateMessage(
      icon: Icons.search_off_rounded,
      title: 'Pegawai tidak ditemukan',
      message:
          'Tidak ada pegawai yang cocok dengan pencarian atau filter yang dipilih.',
      action: OutlinedButton.icon(
        onPressed: _resetFilters,
        icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
        label: const Text('Tampilkan Semua Pegawai'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDarkTeal,
          side: const BorderSide(color: AppColors.primaryDarkTeal, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return _buildStateMessage(
      icon: Icons.cloud_off_rounded,
      iconColor: AppColors.dangerRed,
      iconBackground: AppColors.dangerBg,
      title: 'Data pegawai belum dapat dimuat',
      message: message,
      action: OutlinedButton.icon(
        onPressed: () =>
            ref.read(employeeViewModelProvider.notifier).loadEmployees(),
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Coba Lagi'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDarkTeal,
          side: const BorderSide(color: AppColors.primaryDarkTeal, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }

  void _resetFilters() {
    _searchController.clear();
    ref.read(employeeViewModelProvider.notifier).resetFilters();
  }

  Widget _buildStateMessage({
    required IconData icon,
    required String title,
    required String message,
    required Widget action,
    Color? iconColor,
    Color? iconBackground,
  }) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: iconBackground ?? AppColors.accentMintSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppColors.primaryDarkTeal,
                size: 38,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.title2.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.footnote.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            action,
          ],
        ),
      ),
    );
  }
}
