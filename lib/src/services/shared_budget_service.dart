import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shared_budget_model.dart';

final sharedBudgetServiceProvider =
    Provider<SharedBudgetService>((ref) => SharedBudgetService());

class SharedBudgetService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _col => _db.collection('shared_budgets');

  Future<SharedBudgetModel> create(String name, String currency) async {
    final uid = _auth.currentUser!.uid;
    final doc = _col.doc();
    final code = _generateCode();
    final model = SharedBudgetModel(
      id: doc.id,
      name: name,
      ownerUid: uid,
      memberUids: [uid],
      inviteCode: code,
      categoryBudgets: {},
      currency: currency,
    );
    await doc.set(model.toMap());
    return model;
  }

  Stream<List<SharedBudgetModel>> streamMine() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _col
        .where('memberUids', arrayContains: uid)
        .snapshots()
        .map((s) => s.docs
            .map((d) =>
                SharedBudgetModel.fromMap(d.data() as Map<String, dynamic>))
            .toList());
  }

  Future<SharedBudgetModel?> joinByCode(String code) async {
    final uid = _auth.currentUser!.uid;
    final snap = await _col
        .where('inviteCode', isEqualTo: code.trim().toUpperCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    await doc.reference.update({
      'memberUids': FieldValue.arrayUnion([uid]),
    });
    final updated = await doc.reference.get();
    return SharedBudgetModel.fromMap(updated.data() as Map<String, dynamic>);
  }

  Future<void> setCategoryBudget(
      String budgetId, String categoryId, double amount) async {
    await _col
        .doc(budgetId)
        .update({'categoryBudgets.$categoryId': amount});
  }

  Future<void> delete(String budgetId) async {
    await _col.doc(budgetId).delete();
  }

  Future<void> leave(String budgetId) async {
    final uid = _auth.currentUser!.uid;
    await _col.doc(budgetId).update({
      'memberUids': FieldValue.arrayRemove([uid]),
    });
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
