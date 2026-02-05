class BudgetModel {
  final String categoryId;
  final double amount;

  BudgetModel({required this.categoryId, required this.amount});

  factory BudgetModel.fromMap(Map<String, dynamic> map) => BudgetModel(
        categoryId: map['categoryId'] as String,
        amount: (map['amount'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'categoryId': categoryId,
        'amount': amount,
      };
}
