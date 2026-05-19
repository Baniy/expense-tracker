class SharedBudgetModel {
  final String id;
  final String name;
  final String ownerUid;
  final List<String> memberUids;
  final String inviteCode;
  final Map<String, double> categoryBudgets;
  final String currency;

  const SharedBudgetModel({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.memberUids,
    required this.inviteCode,
    required this.categoryBudgets,
    required this.currency,
  });

  factory SharedBudgetModel.fromMap(Map<String, dynamic> m) =>
      SharedBudgetModel(
        id: m['id'] as String,
        name: m['name'] as String,
        ownerUid: m['ownerUid'] as String,
        memberUids: List<String>.from(m['memberUids'] as List),
        inviteCode: m['inviteCode'] as String,
        categoryBudgets: Map<String, double>.from(
          (m['categoryBudgets'] as Map<String, dynamic>? ?? {}).map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ),
        ),
        currency: m['currency'] as String? ?? 'BDT',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'ownerUid': ownerUid,
        'memberUids': memberUids,
        'inviteCode': inviteCode,
        'categoryBudgets': categoryBudgets.map((k, v) => MapEntry(k, v)),
        'currency': currency,
      };
}
