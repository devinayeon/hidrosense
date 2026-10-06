import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/inventory_record.dart';

final class InventorySnapshot {
  InventorySnapshot({
    required List<InventoryRecord> records,
    required this.fetchedAt,
  }) : records = List.unmodifiable(records);
  final List<InventoryRecord> records;
  final DateTime fetchedAt;
}

/// Read cache only; it stores neither sessions nor queued mutations.
final class InventoryCache {
  InventoryCache(this._db);
  final Database _db;

  static Future<InventoryCache> open() async => InventoryCache(
    await openDatabase(
      path.join(await getDatabasesPath(), 'inventory_cache.db'),
      version: 1,
      onCreate: createSchema,
    ),
  );

  static Future<void> createSchema(Database db, int version) async {
    await db.execute('''CREATE TABLE inventory_snapshots (
      server_origin TEXT NOT NULL, user_id TEXT NOT NULL, fetched_at TEXT NOT NULL,
      PRIMARY KEY(server_origin, user_id))''');
    await db.execute('''CREATE TABLE inventory_records (
      server_origin TEXT NOT NULL, user_id TEXT NOT NULL, id TEXT NOT NULL,
      position INTEGER NOT NULL, payload TEXT NOT NULL,
      PRIMARY KEY(server_origin, user_id, id))''');
  }

  Future<InventorySnapshot?> read({
    required String serverOrigin,
    required String userId,
  }) => _db.transaction((tx) async {
    final args = [serverOrigin, userId];
    final headers = await tx.query(
      'inventory_snapshots',
      where: 'server_origin=? AND user_id=?',
      whereArgs: args,
    );
    if (headers.isEmpty) return null;
    final rows = await tx.query(
      'inventory_records',
      where: 'server_origin=? AND user_id=?',
      whereArgs: args,
      orderBy: 'position',
    );
    return InventorySnapshot(
      records: rows
          .map(
            (row) => InventoryRecord.fromJson(
              jsonDecode(row['payload'] as String) as Map<String, dynamic>,
            ),
          )
          .toList(),
      fetchedAt: DateTime.parse(headers.single['fetched_at'] as String),
    );
  });

  Future<void> replace({
    required String serverOrigin,
    required String userId,
    required List<InventoryRecord> records,
    required DateTime fetchedAt,
  }) => _db.transaction((tx) async {
    await tx.delete(
      'inventory_records',
      where: 'server_origin=? AND user_id=?',
      whereArgs: [serverOrigin, userId],
    );
    for (var i = 0; i < records.length; i++) {
      await tx.insert('inventory_records', {
        'server_origin': serverOrigin,
        'user_id': userId,
        'id': records[i].id,
        'position': i,
        'payload': jsonEncode(records[i].toJson()),
      });
    }
    await tx.insert('inventory_snapshots', {
      'server_origin': serverOrigin,
      'user_id': userId,
      'fetched_at': fetchedAt.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });

  Future<void> close() => _db.close();
}
