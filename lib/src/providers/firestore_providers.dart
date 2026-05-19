import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import '../services/fx_service.dart';
import '../services/recurring_service.dart';
import '../services/shared_budget_service.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';

export '../services/fx_service.dart' show fxServiceProvider;
export '../services/recurring_service.dart' show recurringServiceProvider;
export '../services/shared_budget_service.dart' show sharedBudgetServiceProvider;

final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

final transactionsStreamProvider =
    StreamProvider.family<List<TransactionModel>, String>((ref, uid) {
  final svc = ref.watch(firestoreServiceProvider);
  return svc.streamTransactions(uid);
});

final categoriesStreamProvider =
    StreamProvider.family<List<CategoryModel>, String>((ref, uid) {
  final svc = ref.watch(firestoreServiceProvider);
  return svc.streamCategories(uid);
});
