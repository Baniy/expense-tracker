import 'package:cloud_firestore/cloud_firestore.dart';

class RecurringTransactionModel {
  final String id;
  final String type; // income | expense
  final String categoryId;
  final double amount;
  final String currency;
  final String? note;
  final String frequency; // daily | weekly | monthly | yearly
  final DateTime nextDue;
  final bool isActive;

  const RecurringTransactionModel({
    required this.id,
    required this.type,
    required this.categoryId,
    required this.amount,
    required this.currency,
    this.note,
    required this.frequency,
    required this.nextDue,
    this.isActive = true,
  });

  factory RecurringTransactionModel.fromMap(Map<String, dynamic> m) =>
      RecurringTransactionModel(
        id: m['id'] as String,
        type: m['type'] as String,
        categoryId: m['categoryId'] as String,
        amount: (m['amount'] as num).toDouble(),
        currency: m['currency'] as String? ?? 'BDT',
        note: m['note'] as String?,
        frequency: m['frequency'] as String,
        nextDue: (m['nextDue'] as Timestamp).toDate(),
        isActive: m['isActive'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'categoryId': categoryId,
        'amount': amount,
        'currency': currency,
        'note': note,
        'frequency': frequency,
        'nextDue': Timestamp.fromDate(nextDue),
        'isActive': isActive,
      };

  RecurringTransactionModel copyWith({DateTime? nextDue, bool? isActive}) =>
      RecurringTransactionModel(
        id: id,
        type: type,
        categoryId: categoryId,
        amount: amount,
        currency: currency,
        note: note,
        frequency: frequency,
        nextDue: nextDue ?? this.nextDue,
        isActive: isActive ?? this.isActive,
      );

  DateTime advanceNextDue() {
    switch (frequency) {
      case 'daily':
        return nextDue.add(const Duration(days: 1));
      case 'weekly':
        return nextDue.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(nextDue.year, nextDue.month + 1, nextDue.day);
      case 'yearly':
        return DateTime(nextDue.year + 1, nextDue.month, nextDue.day);
      default:
        return nextDue.add(const Duration(days: 30));
    }
  }
}
