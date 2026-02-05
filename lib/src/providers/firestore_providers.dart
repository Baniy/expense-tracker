import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());

final transactionsStreamProvider = StreamProvider.family<List<TransactionModel>, String>((ref, uid) {
  final svc = ref.watch(firestoreServiceProvider);
  return svc.streamTransactions(uid);
});

final categoriesStreamProvider = StreamProvider.family<List<CategoryModel>, String>((ref, uid) {
  final svc = ref.watch(firestoreServiceProvider);
  return svc.streamCategories(uid);
});
