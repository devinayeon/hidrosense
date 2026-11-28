import 'package:flutter/material.dart';

import '../components/v2_akun_action_bar.dart';
import '../components/v2_akun_employee.dart';
import '../components/v2_akun_info_card.dart';
import '../components/v2_akun_menu_group.dart';
import '../components/v2_akun_profil_card.dart';
import '../theme/v2_tokens.dart';
import '../v2_roles.dart';
import '../widgets/v2_app_bar.dart';
import '../widgets/v2_badge.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_icon.dart';
import '../widgets/v2_list_item.dart';
import '../widgets/v2_refresh_button.dart';

/// Isi tab "Lainnya" (Petani, frame 3.1) dan "Profil" (Pegawai, frame 3.2).
///
/// Bukan rute sendiri: widget ini dipasang oleh `V2BerandaPage` sebagai isi tab
/// terakhir, jadi TabBar tetap milik beranda dan footer "Keluar" duduk di
/// antaranya.
///
/// Perbedaan peran mengikuti catatan alur:
/// - Petani (3.1): menu Akun pegawai, Penjualan, Sinkron — boleh mengelola akun.
/// - Pegawai (3.2): kartu data akun yang hanya dibaca, plus baris Sinkron.
class V2AkunTabView extends StatelessWidget {
  const V2AkunTabView({
    super.key,
    required this.role,
    this.userName = 'Budi Santoso',
    this.username = 'sari.dewi',
    this.phone = '0812 3456 7890',
    this.address = 'Jl. Melati 12, Malang',
    this.syncLabel = 'Terakhir 09.40',
    this.syncBadge,
    this.onOpenEmployees,
    this.onOpenProfile,
    this.onOpenSales,
    this.onOpenSync,
    this.onLogOut,
    this.onRefresh,
  });

  final V2BerandaRole role;
  final String userName;
  final String username;
  final String phone;
  final String address;
  final String syncLabel;

  /// Lencana jumlah data yang menunggu; null berarti tanpa lencana.
  final String? syncBadge;
  final VoidCallback? onOpenEmployees;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenSales;
  final VoidCallback? onOpenSync;
  final VoidCallback? onLogOut;

  /// Tarik-turun dan tombol "Muat ulang"; null berarti galeri tanpa refresh.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final petani = role == V2BerandaRole.petani;
    return Column(
      children: [
        Expanded(
          child: _refreshable(
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                V2Space.xl,
                V2Space.lg,
                V2Space.xl,
                V2Space.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  V2ScreenHeader(
                    title: petani ? 'Lainnya' : 'Profil',
                    trailing: onRefresh == null
                        ? null
                        : V2RefreshButton(onRefresh: onRefresh),
                  ),
                  const SizedBox(height: V2Space.lg),
                  V2AkunProfilCard(
                    initials: v2InitialsOf(userName),
                    name: userName,
                    role: petani ? 'Petani' : 'Pegawai',
                  ),
                  const SizedBox(height: V2Space.lg),
                  if (petani)
                    V2AkunMenuGroup(
                      children: [
                        V2ListItem(
                          icon: V2IconName.user,
                          title: 'Akun saya',
                          subtitle: 'Lihat & ubah profil',
                          onTap: onOpenProfile,
                        ),
                        V2ListItem(
                          icon: V2IconName.user,
                          title: 'Akun pegawai',
                          subtitle: 'Tambah, ubah, nonaktifkan',
                          onTap: onOpenEmployees,
                        ),
                        V2ListItem(
                          icon: V2IconName.chart,
                          title: 'Penjualan',
                          subtitle: 'Catatan penjualan',
                          onTap: onOpenSales,
                        ),
                        V2ListItem(
                          icon: V2IconName.sync,
                          title: 'Sinkron',
                          subtitle: syncLabel,
                          trailing: syncBadge == null
                              ? null
                              : V2Badge(
                                  label: syncBadge!,
                                  status: V2BadgeStatus.pending,
                                ),
                          onTap: onOpenSync,
                        ),
                      ],
                    )
                  else ...[
                    V2AkunInfoCard(
                      rows: [
                        V2AkunInfoRow(label: 'Username', value: username),
                        V2AkunInfoRow(label: 'Telepon', value: phone),
                        V2AkunInfoRow(label: 'Alamat', value: address),
                      ],
                    ),
                    const SizedBox(height: V2Space.lg),
                    V2AkunMenuGroup(
                      elevated: false,
                      children: [
                        V2ListItem(
                          icon: V2IconName.user,
                          title: 'Akun saya',
                          subtitle: 'Lihat & ubah profil',
                          onTap: onOpenProfile,
                        ),
                        V2ListItem(
                          icon: V2IconName.sync,
                          title: 'Sinkron',
                          subtitle: syncLabel,
                          trailing: syncBadge == null
                              ? null
                              : V2Badge(
                                  label: syncBadge!,
                                  status: V2BadgeStatus.pending,
                                ),
                          onTap: onOpenSync,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        V2AkunActionBar(
          actions: [
            V2Button(
              label: 'Keluar',
              type: V2ButtonType.tertiary,
              onPressed: onLogOut,
            ),
          ],
        ),
      ],
    );
  }

  /// Tarik-turun hanya aktif bila ada sumber data nyata.
  Widget _refreshable(Widget child) {
    final refresh = onRefresh;
    if (refresh == null) return child;
    return RefreshIndicator(onRefresh: refresh, child: child);
  }
}
