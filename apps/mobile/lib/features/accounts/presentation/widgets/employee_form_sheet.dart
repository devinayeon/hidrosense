import 'package:flutter/material.dart';
import '../../../../views/theme/app_theme.dart';
import '../../data/models/employee_model.dart';

class EmployeeFormSheet extends StatefulWidget {
  const EmployeeFormSheet({
    super.key,
    this.employee,
    required this.onSubmit,
  });

  final EmployeeModel? employee;
  final Future<bool> Function({
    required String nama,
    required String username,
    String? password,
    String? email,
    String? noTelepon,
    String? alamat,
    required Duration duration,
    int retryCount,
  }) onSubmit;

  static Future<bool?> show(
    BuildContext context, {
    EmployeeModel? employee,
    required Future<bool> Function({
      required String nama,
      required String username,
      String? password,
      String? email,
      String? noTelepon,
      String? alamat,
      required Duration duration,
      int retryCount,
    }) onSubmit,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EmployeeFormSheet(
        employee: employee,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<EmployeeFormSheet> createState() => _EmployeeFormSheetState();
}

class _EmployeeFormSheetState extends State<EmployeeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _emailController;
  late final TextEditingController _noTeleponController;
  late final TextEditingController _alamatController;

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  late final DateTime _openedAt;
  int _retryCount = 0;

  bool get isEditing => widget.employee != null;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    final e = widget.employee;
    _namaController = TextEditingController(text: e?.nama ?? '');
    _usernameController = TextEditingController(text: e?.username ?? '');
    _passwordController = TextEditingController();
    _emailController = TextEditingController(text: e?.email ?? '');
    _noTeleponController = TextEditingController(text: e?.noTelepon ?? '');
    _alamatController = TextEditingController(text: e?.alamat ?? '');
  }

  @override
  void dispose() {
    _namaController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _noTeleponController.dispose();
    _alamatController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      _retryCount++;
      return;
    }

    setState(() => _isSubmitting = true);
    final duration = DateTime.now().difference(_openedAt);

    final success = await widget.onSubmit(
      nama: _namaController.text,
      username: _usernameController.text,
      password: _passwordController.text.isEmpty ? null : _passwordController.text,
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      noTelepon: _noTeleponController.text.trim().isEmpty ? null : _noTeleponController.text.trim(),
      alamat: _alamatController.text.trim().isEmpty ? null : _alamatController.text.trim(),
      duration: duration,
      retryCount: _retryCount,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Text(
                      isEditing ? 'Ubah Data Pegawai' : 'Tambah Pegawai Baru',
                      style: AppTypography.title2.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildField(
                  label: 'Nama Lengkap *',
                  controller: _namaController,
                  hint: 'Contoh: Ahmad Fadli',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Nama lengkap wajib diisi.';
                    }
                    if (v.trim().length > 100) {
                      return 'Maksimal 100 karakter.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _buildField(
                  label: 'Username *',
                  controller: _usernameController,
                  hint: 'Contoh: fadli_hidro',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Username wajib diisi.';
                    }
                    if (v.contains(' ')) {
                      return 'Username tidak boleh mengandung spasi.';
                    }
                    if (v.trim().length > 50) {
                      return 'Maksimal 50 karakter.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _buildPasswordField(),
                const SizedBox(height: AppSpacing.md),
                _buildField(
                  label: 'Nomor WhatsApp / Telepon',
                  controller: _noTeleponController,
                  hint: '+62 812-3456-7890',
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty) {
                      final phoneRegex = RegExp(r'^\+?[0-9 ()-]+$');
                      if (!phoneRegex.hasMatch(v.trim())) {
                        return 'Format nomor telepon tidak valid.';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _buildField(
                  label: 'Email',
                  controller: _emailController,
                  hint: 'pegawai@contoh.id',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty) {
                      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                      if (!emailRegex.hasMatch(v.trim())) {
                        return 'Format email tidak valid.';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _buildField(
                  label: 'Alamat',
                  controller: _alamatController,
                  hint: 'Alamat domisili atau catatan penempatan',
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDarkTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isEditing ? 'Simpan Perubahan' : 'Tambah Pegawai',
                            style: AppTypography.headline.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption1.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            filled: true,
            fillColor: AppColors.secondarySurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide.none,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: const BorderSide(color: AppColors.dangerRed, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: const BorderSide(color: AppColors.primaryDarkTeal, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              isEditing ? 'Password Baru (Opsional)' : 'Password Masuk *',
              style: AppTypography.caption1.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '(Min. 12 karakter)',
              style: AppTypography.caption2.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(fontSize: 14),
          validator: (v) {
            if (!isEditing && (v == null || v.isEmpty)) {
              return 'Password wajib diisi minimal 12 karakter.';
            }
            if (v != null && v.isNotEmpty && v.length < 12) {
              return 'Password minimal 12 karakter.';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: isEditing
                ? 'Kosongkan jika tidak ingin mengubah password'
                : 'Minimal 12 karakter kombinasi',
            hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            filled: true,
            fillColor: AppColors.secondarySurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: const BorderSide(color: AppColors.primaryDarkTeal, width: 1.5),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.textTertiary,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
      ],
    );
  }
}
