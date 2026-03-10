// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:cloud_firestore/cloud_firestore.dart';

class GamePackage {
  final String id;
  final String game;
  final String label;
  final int quantity;
  final int price;
  final bool enabled;
  final int sort;

  GamePackage({
    required this.id,
    required this.game,
    required this.label,
    required this.quantity,
    required this.price,
    required this.enabled,
    required this.sort,
  });

  factory GamePackage.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return GamePackage(
      id: doc.id,
      game: (data['game'] ?? '').toString(),
      label: (data['label'] ?? '').toString(),
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      price: (data['price'] as num?)?.round() ?? 0,
      enabled: data['enabled'] == null ? true : data['enabled'] == true,
      sort: (data['sort'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'game': game,
      'label': label,
      'quantity': quantity,
      'price': price,
      'enabled': enabled,
      'sort': sort,
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  static String gameLabel(String key) {
    switch (key) {
      case 'pubg':
        return 'PUBG Mobile';
      case 'freefire':
        return 'Free Fire';
      case 'cod':
        return 'Call of duty';
      default:
        return 'شحن أخرى';
    }
  }

  static List<String> gameOrder() => ['pubg', 'freefire', 'cod'];
}
