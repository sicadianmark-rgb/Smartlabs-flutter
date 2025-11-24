import 'package:flutter/foundation.dart';

class CartItem {
  final String itemId;
  final String categoryId;
  final String itemName;
  final String categoryName;
  final int quantity;

  CartItem({
    required this.itemId,
    required this.categoryId,
    required this.itemName,
    required this.categoryName,
    this.quantity = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'categoryId': categoryId,
      'itemName': itemName,
      'categoryName': categoryName,
      'quantity': quantity,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      itemId: map['itemId'],
      categoryId: map['categoryId'],
      itemName: map['itemName'],
      categoryName: map['categoryName'],
      quantity: map['quantity'] ?? 1,
    );
  }

  CartItem copyWith({int? quantity}) {
    return CartItem(
      itemId: itemId,
      categoryId: categoryId,
      itemName: itemName,
      categoryName: categoryName,
      quantity: quantity ?? this.quantity,
    );
  }
}

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.length;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  void addItem(CartItem item) {
    // Check if item already exists in cart
    final existingIndex = _items.indexWhere((i) => i.itemId == item.itemId);

    if (existingIndex >= 0) {
      // Update quantity if item already exists
      _items[existingIndex] = _items[existingIndex].copyWith(
        quantity: _items[existingIndex].quantity + item.quantity,
      );
    } else {
      // Add new item to cart
      _items.add(item);
    }

    notifyListeners();
  }

  void removeItem(String itemId) {
    _items.removeWhere((item) => item.itemId == itemId);
    notifyListeners();
  }

  void updateQuantity(String itemId, int quantity) {
    final index = _items.indexWhere((item) => item.itemId == itemId);
    if (index >= 0) {
      if (quantity <= 0) {
        removeItem(itemId);
      } else {
        _items[index] = _items[index].copyWith(quantity: quantity);
        notifyListeners();
      }
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  bool containsItem(String itemId) {
    return _items.any((item) => item.itemId == itemId);
  }

  CartItem? getItem(String itemId) {
    try {
      return _items.firstWhere((item) => item.itemId == itemId);
    } catch (e) {
      return null;
    }
  }
}
