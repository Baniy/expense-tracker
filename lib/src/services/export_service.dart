import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';

class ExportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Returns the exported [File]. The caller is responsible for sharing or
  /// deleting the file; the path should not be displayed or copied to clipboard.
  Future<File> exportTransactionsToCsv(String uid) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null || currentUid != uid) {
      throw Exception('Not authorized to export this data');
    }

    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('date')
        .get();

    final rows = <List<String>>[];
    rows.add(['id', 'type', 'categoryId', 'amount', 'currency', 'note', 'date']);
    for (final d in snap.docs) {
      final data = d.data();
      final date = data['date'] is Timestamp
          ? (data['date'] as Timestamp).toDate().toIso8601String()
          : data['date'].toString();
      rows.add([
        data['id'].toString(),
        data['type'].toString(),
        data['categoryId'].toString(),
        data['amount'].toString(),
        data['currency'].toString(),
        (data['note'] ?? '').toString().replaceAll('\n', ' '),
        date,
      ]);
    }

    final csv = rows
        .map((r) => r.map((c) => '"${c.replaceAll('"', '""')}"').join(','))
        .join('\n');

    // Write to the app-private cache directory (not accessible to other apps
    // on Android without root, cleared on app uninstall).
    final dir = await getApplicationCacheDirectory();
    final file = File('${dir.path}/transactions_export.csv');
    await file.writeAsString(csv, flush: true);
    return file;
  }
}
