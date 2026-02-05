class CategoryModel {
  final String id;
  final String name;
  final String type; // 'income'|'expense'|'both'
  final int color; // ARGB int
  final String? icon;

  CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
    this.icon,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) => CategoryModel(
        id: map['id'] as String,
        name: map['name'] as String,
        type: map['type'] as String? ?? 'expense',
        color: map['color'] as int? ?? 0xFF2196F3,
        icon: map['icon'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'color': color,
        'icon': icon,
      };
}
