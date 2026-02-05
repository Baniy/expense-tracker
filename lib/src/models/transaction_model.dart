import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String type; // 'income' or 'expense'
  final String categoryId;
  final double amount;
  final String currency;
  final String? note;
  final DateTime date;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TransactionModel({
    required this.id,
    required this.type,
    required this.categoryId,
    required this.amount,
    required this.currency,
    this.note,
    required this.date,
    this.createdAt,
    this.updatedAt,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) => TransactionModel(
        id: map['id'] as String,
        type: map['type'] as String,
        categoryId: map['categoryId'] as String,
        amount: (map['amount'] as num).toDouble(),
        currency: map['currency'] as String? ?? 'BDT',
        note: map['note'] as String?,
        date: (map['date'] as Timestamp).toDate(),
        createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
        updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'categoryId': categoryId,
        'amount': amount,
        'currency': currency,
        'note': note,
        'date': Timestamp.fromDate(date),
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
