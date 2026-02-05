import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/src/models/transaction_model.dart';

void main() {
  test('TransactionModel basic fields', () {
    final now = DateTime.now();
    final tx = TransactionModel(
      id: 'tx1',
      type: 'expense',
      categoryId: 'food',
      amount: 123.45,
      currency: 'BDT',
      note: 'Lunch',
      date: now,
      createdAt: now,
      updatedAt: now,
    );

    expect(tx.id, 'tx1');
    expect(tx.type, 'expense');
    expect(tx.amount, 123.45);
    expect(tx.date.year, now.year);
  });
}
