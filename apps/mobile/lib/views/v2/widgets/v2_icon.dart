import 'package:flutter/material.dart';

import '../theme/v2_tokens.dart';

/// Nama ikon pada library "Icons" FigCraft v2.
enum V2IconName {
  home,
  sprout,
  box,
  care,
  more,
  user,
  back,
  search,
  close,
  bell,
  plus,
  camera,
  check,
  cloud,
  minus,
  warning,
  info,
  error,
  sun,
  edit,
  trash,
  sync,
  chevronRight,
  chevronDown,
  droplet,
  layers,
  calendar,
  chart,
}

/// Pemetaan ikon garis 24px v2 ke Material Icons.
///
/// FigCraft memakai ikon vektor kustom; di Flutter dipakai padanan outlined
/// supaya tetap satu keluarga visual dan tidak menambah paket.
abstract final class V2Icons {
  static const double size = 24;
  static const double small = 16;

  static IconData of(V2IconName name) => switch (name) {
    V2IconName.home => Icons.home_outlined,
    V2IconName.sprout => Icons.eco_outlined,
    V2IconName.box => Icons.inventory_2_outlined,
    V2IconName.care => Icons.health_and_safety_outlined,
    V2IconName.more => Icons.more_horiz,
    V2IconName.user => Icons.person_outline,
    V2IconName.back => Icons.chevron_left,
    V2IconName.search => Icons.search,
    V2IconName.close => Icons.close,
    V2IconName.bell => Icons.notifications_none,
    V2IconName.plus => Icons.add,
    V2IconName.camera => Icons.photo_camera_outlined,
    V2IconName.check => Icons.check,
    V2IconName.cloud => Icons.cloud_outlined,
    V2IconName.minus => Icons.remove,
    V2IconName.warning => Icons.warning_amber_rounded,
    V2IconName.info => Icons.info_outline,
    V2IconName.error => Icons.error_outline,
    V2IconName.sun => Icons.wb_sunny_outlined,
    V2IconName.edit => Icons.edit_outlined,
    V2IconName.trash => Icons.delete_outline,
    V2IconName.sync => Icons.sync,
    V2IconName.chevronRight => Icons.chevron_right,
    V2IconName.chevronDown => Icons.keyboard_arrow_down,
    V2IconName.droplet => Icons.water_drop_outlined,
    V2IconName.layers => Icons.layers_outlined,
    V2IconName.calendar => Icons.calendar_today,
    V2IconName.chart => Icons.bar_chart,
  };
}

/// Ikon v2 dengan ukuran dan warna token.
class V2Icon extends StatelessWidget {
  const V2Icon(
    this.name, {
    super.key,
    this.size = V2Icons.size,
    this.color = V2Colors.ink,
  });

  final V2IconName name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(V2Icons.of(name), size: size, color: color);
  }
}
