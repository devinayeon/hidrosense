import 'dart:async';

import 'package:flutter/material.dart';

import '../components/v2_akun_action_bar.dart';
import '../components/v2_akun_assets.dart';
import '../components/v2_akun_employee.dart';
import '../components/v2_akun_employee_row.dart';
import '../components/v2_akun_menu_group.dart';
import '../theme/v2_tokens.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_error_state.dart';
import '../widgets/v2_select_field.dart';
import 'v2_employee_detail_page.dart';
import 'v2_employee_form_page.dart';

/// Daftar akun pegawai: frame 3.5, 3.4 (kosong), 3.6 (cari tanpa hasil),
/// 3.10 (notifikasi "Pegawai ditambahkan"), dan 3.16 ("Sari dinonaktifkan").
///
/// Hanya Petani yang sampai ke halaman ini (lewat menu "Akun pegawai" di 3.1).
class V2EmployeeListPage extends StatefulWidget {
  const V2EmployeeListPage({
    super.key,
    this.initialEmployees = designEmployees,
    this.toast,
    this.onChanged,
  });

  /// Frame `3.4 Akun pegawai kosong` dihasilkan dari daftar kosong.
  const V2EmployeeListPage.empty({super.key, this.toast, this.onChanged})
    : initialEmployees = const <V2Employee>[];

  final List<V2Employee> initialEmployees;

  /// Toast yang sudah tampil saat halaman dibuka (untuk frame 3.10/3.16).
  final String? toast;
  final ValueChanged<List<V2Employee>>? onChanged;

  static Route<void> route({
    List<V2Employee> initialEmployees = designEmployees,
    String? toast,
    ValueChanged<List<V2Employee>>? onChanged,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => V2EmployeeListPage(
        initialEmployees: initialEmployees,
        toast: toast,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<V2EmployeeListPage> createState() => _V2EmployeeListPageState();
}

class _V2EmployeeListPageState extends State<V2EmployeeListPage> {
  late List<V2Employee> _employees = widget.initialEmployees;
  final TextEditingController _search = TextEditingController();
  Timer? _toastTimer;
  String? _toast;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _toast = widget.toast;
    if (_toast != null) _scheduleToastDismiss();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _scheduleToastDismiss() {
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  List<V2Employee> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _employees;
    return _employees
        .where(
          (e) =>
              e.name.toLowerCase().contains(query) ||
              e.username.toLowerCase().contains(query),
        )
        .toList();
  }

  void _update(List<V2Employee> employees) {
    setState(() => _employees = employees);
    widget.onChanged?.call(employees);
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<V2Employee>(
      V2EmployeeFormPage.route(takenUsernames: _usernames),
    );
    if (created == null || !mounted) return;
    // Pegawai baru tampil paling atas, sama seperti frame 3.10.
    _update([created, ..._employees]);
    setState(() {
      _toast = 'Pegawai ditambahkan';
      _scheduleToastDismiss();
    });
  }

  Future<void> _openDetail(V2Employee employee) async {
    final result = await Navigator.of(context)
        .push<V2EmployeeDeactivated>(V2EmployeeDetailPage.route(employee));
    if (result == null || !mounted) return;
    _update([
      for (final item in _employees)
        if (item.id == result.employee.id) result.employee else item,
    ]);
    setState(() {
      _toast = '${result.employee.firstName} dinonaktifkan';
      _scheduleToastDismiss();
    });
  }

  Set<String> get _usernames =>
      _employees.map((e) => e.username.toLowerCase()).toSet();

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: V2Theme.light,
      child: Scaffold(
        backgroundColor: V2Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              V2AppBar(
                title: 'Akun pegawai',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: _employees.isEmpty
                    ? _buildEmptyState()
                    : _buildList(),
              ),
              V2AkunActionBar(
                safeBottom: true,
                toast: _toast,
                actions: [
                  V2Button(label: 'Tambah pegawai', onPressed: _openCreate),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: V2Space.xl),
        child: V2ErrorState(
          title: 'Belum ada pegawai',
          body: 'Tambah akun agar tim bisa masuk.',
          illustration: Image.asset(
            V2AkunAssets.mascotAvatarFlat,
            width: 160,
            height: 160,
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final filtered = _filtered;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        V2Space.xl,
        V2Space.sm,
        V2Space.xl,
        V2Space.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          V2SearchField(
            hint: 'Cari pegawai',
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            onClear: () => setState(() {
              _search.clear();
              _query = '';
            }),
          ),
          const SizedBox(height: V2Space.lg),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(64, 64, 64, 0),
              child: V2ErrorState(
                title: 'Tidak ketemu',
                body: 'Coba kata lain.',
                illustration: Image.asset(
                  V2AkunAssets.mascotAvatarFlat,
                  width: 120,
                  height: 120,
                ),
              ),
            )
          else
            V2AkunMenuGroup(
              children: [
                for (final employee in filtered)
                  V2AkunEmployeeRow(
                    name: employee.name,
                    statusLine: employee.statusLine,
                    active: employee.active,
                    onTap: () => _openDetail(employee),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
