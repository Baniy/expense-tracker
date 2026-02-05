import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';

class ExportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> exportTransactionsToCsv(String uid) async {
    final snap = await _db.collection('users').doc(uid).collection('transactions').orderBy('date').get();
    final rows = <List<String>>[];
    rows.add(['id', 'type', 'categoryId', 'amount', 'currency', 'note', 'date']);
    for (final d in snap.docs) {
      final data = d.data();
      final date = data['date'] is Timestamp ? (data['date'] as Timestamp).toDate().toIso8601String() : data['date'].toString();
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

    final csv = rows.map((r) => r.map((c) => '"${c.replaceAll('"', '""')}"').join(',')).join('\n');
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/transactions_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csv);
    return file.path;
  }
}
