import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/recurring_transaction_model.dart';
import '../models/transaction_model.dart';
import 'firestore_service.dart';

final recurringServiceProvider =
    Provider<RecurringService>((ref) => RecurringService());

class RecurringService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference _col(String uid) =>
      _db.collection('users').doc(uid).collection('recurring_transactions');

  Future<void> add(String uid, RecurringTransactionModel r) async {
    await _col(uid).doc(r.id).set(r.toMap());
  }

  Future<void> update(String uid, RecurringTransactionModel r) async {
    await _col(uid).doc(r.id).set(r.toMap());
  }

  Future<void> delete(String uid, String id) async {
    await _col(uid).doc(id).delete();
  }

  Stream<List<RecurringTransactionModel>> stream(String uid) {
    return _col(uid)
        .orderBy('nextDue')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => RecurringTransactionModel.fromMap(
                d.data() as Map<String, dynamic>))
            .toList());
  }

  /// Creates transactions for any active recurring entries that are due,
  /// then advances their nextDue date.
  Future<void> processDue(String uid, FirestoreService fsvc) async {
    final now = DateTime.now();
    final snap = await _col(uid)
        .where('isActive', isEqualTo: true)
        .where('nextDue', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .get();

    for (final doc in snap.docs) {
      var r = RecurringTransactionModel.fromMap(
          doc.data() as Map<String, dynamic>);

      // Advance through every missed due date (catches up if offline)
      while (!r.nextDue.isAfter(now)) {
        final tx = TransactionModel(
          id: const Uuid().v4(),
          type: r.type,
          categoryId: r.categoryId,
          amount: r.amount,
          currency: r.currency,
          note: r.note,
          date: r.nextDue,
        );
        try {
          await fsvc.addTransaction(uid, tx);
        } catch (_) {
          // If offline, skip — will re-process on next launch
          break;
        }
        r = r.copyWith(nextDue: r.advanceNextDue());
      }

      await _col(uid)
          .doc(r.id)
          .update({'nextDue': Timestamp.fromDate(r.nextDue)});
    }
  }
}
