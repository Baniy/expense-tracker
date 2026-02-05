import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference userDoc(String uid) => _db.collection('users').doc(uid).collection('meta');

  CollectionReference transactionsCol(String uid) =>
      _db.collection('users').doc(uid).collection('transactions');

  CollectionReference categoriesCol(String uid) =>
      _db.collection('users').doc(uid).collection('categories');

  Future<void> addTransaction(String uid, TransactionModel t) async {
    final doc = transactionsCol(uid).doc(t.id);
    await doc.set(t.toMap());
  }

  Future<void> updateTransaction(String uid, TransactionModel t) async {
    final doc = transactionsCol(uid).doc(t.id);
    // Use merge to avoid overwriting other fields; updatedAt is set server-side
    await doc.set({
      'type': t.type,
      'categoryId': t.categoryId,
      'amount': t.amount,
      'currency': t.currency,
      'note': t.note,
      'date': Timestamp.fromDate(t.date),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteTransaction(String uid, String tid) async {
    await transactionsCol(uid).doc(tid).delete();
  }

  Stream<List<TransactionModel>> streamTransactions(String uid, {int limit = 100}) {
    return transactionsCol(uid)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => TransactionModel.fromMap(d.data() as Map<String, dynamic>)).toList());
  }

  // Budgets
  CollectionReference budgetsCol(String uid) => _db.collection('users').doc(uid).collection('budgets');

  Future<void> setBudget(String uid, String categoryId, double amount) async {
    final doc = budgetsCol(uid).doc(categoryId);
    await doc.set({'categoryId': categoryId, 'amount': amount, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<double?> getBudget(String uid, String categoryId) async {
    final snap = await budgetsCol(uid).doc(categoryId).get();
    if (!snap.exists) return null;
    final data = snap.data() as Map<String, dynamic>;
    return (data['amount'] as num?)?.toDouble();
  }

  Future<double> getCategoryMonthSum(String uid, String categoryId, DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final snap = await transactionsCol(uid)
        .where('categoryId', isEqualTo: categoryId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
    double sum = 0.0;
    for (final d in snap.docs) {
      final data = d.data() as Map<String, dynamic>;
      sum += (data['amount'] as num).toDouble();
    }
    return sum;
  }

  // Categories
  Future<void> addCategory(String uid, CategoryModel c) async {
    await categoriesCol(uid).doc(c.id).set(c.toMap());
  }

  Stream<List<CategoryModel>> streamCategories(String uid) {
    return categoriesCol(uid)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((d) => CategoryModel.fromMap(d.data() as Map<String, dynamic>)).toList());
  }

  Future<void> seedDefaultCategories(String uid) async {
    final col = categoriesCol(uid);
    final snapshot = await col.limit(1).get();
    if (snapshot.docs.isNotEmpty) return; // already seeded

    final defaults = [
      {'name': 'Food', 'type': 'expense', 'color': 0xFFFF7043, 'icon': 'restaurant'},
      {'name': 'Rent', 'type': 'expense', 'color': 0xFF8E24AA, 'icon': 'home'},
      {'name': 'Transport', 'type': 'expense', 'color': 0xFF42A5F5, 'icon': 'directions_car'},
      {'name': 'Salary', 'type': 'income', 'color': 0xFF66BB6A, 'icon': 'work'},
      {'name': 'Business', 'type': 'income', 'color': 0xFF26A69A, 'icon': 'business'},
      {'name': 'Investment', 'type': 'income', 'color': 0xFFFFD54F, 'icon': 'show_chart'},
      {'name': 'Misc', 'type': 'expense', 'color': 0xFF90A4AE, 'icon': 'more_horiz'},
    ];

    final batch = _db.batch();
    for (final d in defaults) {
      final doc = col.doc();
      final data = {
        'id': doc.id,
        'name': d['name'],
        'type': d['type'],
        'color': d['color'],
        'icon': d['icon'],
      };
      batch.set(doc, data);
    }
    await batch.commit();
  }

  // Generic raw document operations used by SyncService
  Future<void> setDocument(String uid, String collection, String docId, Map<String, dynamic> data) async {
    final docRef = _db.collection('users').doc(uid).collection(collection).doc(docId);
    await docRef.set(data);
  }

  Future<void> updateDocument(String uid, String collection, String docId, Map<String, dynamic> data) async {
    final docRef = _db.collection('users').doc(uid).collection(collection).doc(docId);
    await docRef.update(data);
  }

  Future<void> deleteDocument(String uid, String collection, String docId) async {
    final docRef = _db.collection('users').doc(uid).collection(collection).doc(docId);
    await docRef.delete();
  }
}
