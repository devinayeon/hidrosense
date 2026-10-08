import 'package:flutter/foundation.dart';

@immutable
class EmployeeModel {
  const EmployeeModel({
    required this.id,
    required this.nama,
    required this.username,
    this.email,
    this.noTelepon,
    this.alamat,
    this.statusAktif = 1,
    this.role = 'pegawai',
  });

  final String id;
  final String nama;
  final String username;
  final String? email;
  final String? noTelepon;
  final String? alamat;
  final int statusAktif;
  final String role;

  bool get isActive => statusAktif == 1;

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: (json['id_user'] ?? json['id'] ?? '').toString(),
      nama: (json['nama'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      email: json['email'] as String?,
      noTelepon: (json['no_telepon'] ?? json['noTelepon']) as String?,
      alamat: json['alamat'] as String?,
      statusAktif: json['status_aktif'] is int
          ? json['status_aktif'] as int
          : int.tryParse(json['status_aktif']?.toString() ?? '1') ?? 1,
      role: (json['role'] ?? json['nama_role'] ?? 'pegawai').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_user': id,
      'nama': nama,
      'username': username,
      if (email != null) 'email': email,
      if (noTelepon != null) 'no_telepon': noTelepon,
      if (alamat != null) 'alamat': alamat,
      'status_aktif': statusAktif,
      'role': role,
    };
  }

  EmployeeModel copyWith({
    String? id,
    String? nama,
    String? username,
    String? email,
    String? noTelepon,
    String? alamat,
    int? statusAktif,
    String? role,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      username: username ?? this.username,
      email: email ?? this.email,
      noTelepon: noTelepon ?? this.noTelepon,
      alamat: alamat ?? this.alamat,
      statusAktif: statusAktif ?? this.statusAktif,
      role: role ?? this.role,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmployeeModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nama == other.nama &&
          username == other.username &&
          email == other.email &&
          noTelepon == other.noTelepon &&
          alamat == other.alamat &&
          statusAktif == other.statusAktif &&
          role == other.role;

  @override
  int get hashCode =>
      id.hashCode ^
      nama.hashCode ^
      username.hashCode ^
      email.hashCode ^
      noTelepon.hashCode ^
      alamat.hashCode ^
      statusAktif.hashCode ^
      role.hashCode;

  @override
  String toString() =>
      'EmployeeModel(id: $id, nama: $nama, username: $username, status: $statusAktif)';
}
