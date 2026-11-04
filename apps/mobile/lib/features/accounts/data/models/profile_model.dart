import 'package:flutter/foundation.dart';

@immutable
class ProfileModel {
  const ProfileModel({
    required this.id,
    required this.nama,
    required this.username,
    required this.role,
    required this.statusAktif,
    this.email,
    this.noTelepon,
    this.alamat,
  });

  final String id;
  final String nama;
  final String username;
  final String role;
  final int statusAktif;
  final String? email;
  final String? noTelepon;
  final String? alamat;

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final status = json['status_aktif'];
    if (json['id_user'] is! String ||
        json['nama'] is! String ||
        json['username'] is! String ||
        json['role'] is! String ||
        (status is! int && status is! num) ||
        (json['email'] != null && json['email'] is! String) ||
        (json['no_telepon'] != null && json['no_telepon'] is! String) ||
        (json['alamat'] != null && json['alamat'] is! String)) {
      throw const FormatException('Data profil tidak valid.');
    }
    return ProfileModel(
      id: json['id_user'] as String,
      nama: json['nama'] as String,
      username: json['username'] as String,
      role: json['role'] as String,
      statusAktif: (status as num).toInt(),
      email: json['email'] as String?,
      noTelepon: json['no_telepon'] as String?,
      alamat: json['alamat'] as String?,
    );
  }
}
