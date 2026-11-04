import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../viewmodels/session_viewmodel.dart';
import '../../../../views/components/header.dart';
import '../../../../views/theme/app_theme.dart';
import '../../../../views/widgets/custom_input_field.dart';
import '../../../../views/widgets/custom_text_area.dart';
import '../../../../views/widgets/row_button.dart';
import '../../data/models/profile_model.dart';
import '../viewmodels/profile_viewmodel.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _teleponController = TextEditingController();
  final _alamatController = TextEditingController();
  String? _namaErrorText;
  String? _emailErrorText;
  String? _teleponErrorText;
  String? _alamatErrorText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _namaController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _teleponController.dispose();
    _alamatController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final loaded = await ref.read(profileViewModelProvider.notifier).load();
    if (!mounted || !loaded) return;
    final profile = ref.read(profileViewModelProvider).profile;
    if (profile != null) _fill(profile);
  }

  void _fill(ProfileModel profile) {
    _namaController.text = profile.nama;
    _usernameController.text = profile.username;
    _emailController.text = profile.email ?? '';
    _teleponController.text = profile.noTelepon ?? '';
    _alamatController.text = profile.alamat ?? '';
    _namaErrorText = null;
    _emailErrorText = null;
    _teleponErrorText = null;
    _alamatErrorText = null;
  }

  bool _validateFields() {
    final nama = _namaController.text.trim();
    final email = _emailController.text.trim();
    final telepon = _teleponController.text.trim();
    final alamat = _alamatController.text.trim();
    setState(() {
      _namaErrorText = nama.isEmpty
          ? 'Nama lengkap wajib diisi.'
          : (nama.length > 100 ? 'Nama maksimal 100 karakter.' : null);
      _emailErrorText = email.isEmpty
          ? null
          : (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                ? 'Format email tidak valid.'
                : null);
      _teleponErrorText = telepon.isEmpty
          ? null
          : (!RegExp(r'^\+?[0-9 ()-]+$').hasMatch(telepon)
                ? 'Format nomor telepon tidak valid.'
                : null);
      _alamatErrorText = alamat.length > 1000
          ? 'Alamat maksimal 1000 karakter.'
          : null;
    });
    return _namaErrorText == null &&
        _emailErrorText == null &&
        _teleponErrorText == null &&
        _alamatErrorText == null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_validateFields()) return;

    final saved = await ref
        .read(profileViewModelProvider.notifier)
        .save(
          nama: _namaController.text,
          email: _emailController.text,
          noTelepon: _teleponController.text,
          alamat: _alamatController.text,
        );
    if (!mounted) return;

    if (!saved) return;
    final profile = ref.read(profileViewModelProvider).profile;
    if (profile != null) {
      ref
          .read(sessionProvider.notifier)
          .updateIdentity(name: profile.nama, username: profile.username);
      _fill(profile);
    }
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Profil berhasil diperbarui.'),
        backgroundColor: AppColors.primaryDarkTeal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canRead = ref.watch(
      sessionProvider.select(
        (state) => state.user?.permissions.contains('profil:read') == true,
      ),
    );
    final canWrite = ref.watch(
      sessionProvider.select(
        (state) => state.user?.permissions.contains('profil:write') == true,
      ),
    );
    final state = ref.watch(profileViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.canvasWarm,
      appBar: const Header(
        titleText: 'Edit Profil',
        showBackButton: true,
        showUserIcon: false,
      ),
      body: !canRead || !canWrite
          ? _buildAccessDenied()
          : state.isLoading && state.profile == null
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryDarkTeal,
              ),
            )
          : state.errorMessage != null && state.profile == null
          ? _buildLoadError(state.errorMessage!)
          : _buildForm(state),
    );
  }

  Widget _buildForm(ProfileState state) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informasi Akun',
              style: AppTypography.title3.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Perbarui data kontak yang dipakai untuk operasional kebun.',
              style: AppTypography.footnote.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomInputField(
                    label: 'Nama Lengkap',
                    hintText: 'Masukkan nama lengkap',
                    controller: _namaController,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [LengthLimitingTextInputFormatter(100)],
                    errorText: _namaErrorText,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CustomInputField(
                    label: 'Username',
                    hintText: 'Username akun',
                    controller: _usernameController,
                    readOnly: true,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CustomInputField(
                    label: 'Email',
                    hintText: 'nama@contoh.com',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [LengthLimitingTextInputFormatter(100)],
                    errorText: _emailErrorText,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CustomInputField(
                    label: 'No. Telepon',
                    hintText: '+62 812-3456-7890',
                    controller: _teleponController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(20),
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]')),
                    ],
                    errorText: _teleponErrorText,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CustomTextArea(
                    label: 'Alamat',
                    hintText: 'Alamat domisili atau lokasi kebun',
                    controller: _alamatController,
                    maxLines: 3,
                    errorText: _alamatErrorText,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: Text(
                    'Username dan password tidak diubah dari halaman ini.',
                    style: AppTypography.caption2.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            if (state.saveError != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  border: Border.all(
                    color: AppColors.dangerRed.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.dangerRed,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        state.saveError!,
                        style: AppTypography.footnote.copyWith(
                          color: AppColors.dangerRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            RowButton(
              label: state.isSaving ? 'Menyimpan...' : 'Simpan Perubahan',
              backgroundColor: AppColors.primaryMint,
              textColor: Colors.white,
              borderRadius: AppRadius.pill,
              height: 52,
              onTap: state.isSaving ? null : _save,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessDenied() {
    return Center(
      child: Text(
        'Akses profil tidak diizinkan.',
        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildLoadError(String message) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.dangerBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_off_outlined,
                color: AppColors.dangerRed,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Profil belum dapat dimuat',
              textAlign: TextAlign.center,
              style: AppTypography.title3.copyWith(
                fontWeight: FontWeight.w700,
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
            OutlinedButton.icon(
              key: const ValueKey('profile-retry'),
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDarkTeal,
                side: const BorderSide(
                  color: AppColors.primaryDarkTeal,
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
