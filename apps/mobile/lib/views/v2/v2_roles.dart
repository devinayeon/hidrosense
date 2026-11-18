import 'widgets/v2_icon.dart';
import 'widgets/v2_tab_bar.dart';

/// Peran pengguna pada alur v2.
///
/// Dipisah dari `v2_beranda_page.dart` supaya komponen halaman lain (mis. tab
/// "Lainnya"/"Profil" di halaman 03) bisa memakainya tanpa impor melingkar.
enum V2BerandaRole { petani, pegawai }

/// Tab bawah peran Petani (5 tab) mengikuti frame `TabBar` di FigCraft.
const List<V2TabItem> v2PetaniTabs = <V2TabItem>[
  V2TabItem(label: 'Beranda', icon: V2IconName.home),
  V2TabItem(label: 'Tanam', icon: V2IconName.sprout),
  V2TabItem(label: 'Stok', icon: V2IconName.box),
  V2TabItem(label: 'Rawat', icon: V2IconName.care),
  V2TabItem(label: 'Lainnya', icon: V2IconName.more),
];

/// Tab bawah peran Pegawai (4 tab); "Profil" menggantikan "Rawat"/"Lainnya".
const List<V2TabItem> v2PegawaiTabs = <V2TabItem>[
  V2TabItem(label: 'Beranda', icon: V2IconName.home),
  V2TabItem(label: 'Tanam', icon: V2IconName.sprout),
  V2TabItem(label: 'Stok', icon: V2IconName.box),
  V2TabItem(label: 'Profil', icon: V2IconName.user),
];

/// Tab bawah untuk [role].
List<V2TabItem> v2TabsFor(V2BerandaRole role) =>
    role == V2BerandaRole.petani ? v2PetaniTabs : v2PegawaiTabs;

/// Index tab "Tanam" di kedua peran; halaman 05 Semaian duduk di sini.
const int v2TanamTabIndex = 1;

/// Index tab "Stok" di kedua peran; halaman 04 Inventaris duduk di sini.
const int v2StokTabIndex = 2;
