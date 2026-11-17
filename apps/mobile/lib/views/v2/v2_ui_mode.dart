import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Menandai apakah sesi berjalan memakai alur tampilan v2.
///
/// Sengaja dipisah dari sesi supaya tombol "Coba tampilan v2" di halaman login
/// bisa membuka alur prototipe tanpa mengubah rute sesi sungguhan. Hanya login
/// sungguhan lewat form v2 yang menyalakannya, dan form lama mematikannya.
final v2UiModeProvider = StateProvider<bool>((ref) => false);
