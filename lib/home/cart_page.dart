import 'package:flutter/material.dart';
import 'package:app/home/service/cart_service.dart';
import 'package:app/home/service/association_mining_service.dart';
import 'package:app/home/service/equipment_service.dart';
import 'package:app/home/models/equipment_models.dart';
import 'package:app/home/batch_borrow_form_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final CartService _cartService = CartService();
  List<String> _recommendations = [];

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
    // Listen to cart changes to refresh recommendations
    _cartService.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    _cartService.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    _loadRecommendations();
  }

  Future<void> _handleRecommendationTap(String itemName) async {
    try {
      // Search for the item by name
      final allItems = await EquipmentService.getAllItems();
      final matchingItems = allItems.where((item) => 
        item.name.toLowerCase() == itemName.toLowerCase()
      ).toList();

      if (matchingItems.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Item "$itemName" not found'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final item = matchingItems.first;
      
      // Check if item is already in cart
      if (_cartService.containsItem(item.id)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This item is already in your cart'),
              backgroundColor: Colors.blue,
            ),
          );
        }
        return;
      }

      // Get category name from categoryId
      String categoryName = 'Unknown Category';
      try {
        final categories = await EquipmentService.getCategories();
        final category = categories.firstWhere(
          (cat) => cat.id == item.categoryId,
          orElse: () => categories.isNotEmpty 
            ? categories.first 
            : EquipmentCategory(
                id: '',
                title: 'Unknown Category',
                availableCount: 0,
                icon: Icons.science,
                color: Colors.grey,
              ),
        );
        categoryName = category.title;
      } catch (e) {
        debugPrint('Error getting category name: $e');
      }

      // Add to cart with quantity 1
      _cartService.addItem(
        CartItem(
          itemId: item.id,
          categoryId: item.categoryId,
          itemName: item.name,
          categoryName: categoryName,
          quantity: 1,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$itemName added to cart'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF2AA39F),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadRecommendations() async {
    if (_cartService.isEmpty) {
      if (mounted) {
        setState(() {
          _recommendations = [];
        });
      }
      return;
    }

    try {
      final itemNames =
          _cartService.items.map((item) => item.itemName).toList();
      final recommendations = await AssociationMiningService.getRecommendations(
        itemNames,
      );

      if (mounted) {
        setState(() {
          _recommendations = recommendations;
        });
      }
    } catch (e) {
      // Silently fail - recommendations are optional
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('My Cart'),
        backgroundColor: const Color(0xFF2AA39F),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          ListenableBuilder(
            listenable: _cartService,
            builder: (context, child) {
              if (_cartService.isEmpty) return const SizedBox.shrink();
              return TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('Clear Cart'),
                          content: const Text(
                            'Are you sure you want to remove all items from cart?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                _cartService.clear();
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text('Clear All'),
                            ),
                          ],
                        ),
                  );
                },
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                label: const Text('Clear', style: TextStyle(color: Colors.white)),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _cartService,
        builder: (context, child) {
          if (_cartService.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 100,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add items from the equipment page',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Cart items list with recommendations
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cart items
                      const Text(
                        'Your Items',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _cartService.items.length,
                        itemBuilder: (context, index) {
                          final item = _cartService.items[index];
                          return _buildCartItem(item);
                        },
                      ),

                      // Recommendations section
                      if (_recommendations.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildRecommendationsSection(),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom section with total and checkout
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Items',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_cartService.itemCount} item${_cartService.itemCount != 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2AA39F),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BatchBorrowFormPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2AA39F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Submit Borrow Request',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCartItem(CartItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2AA39F).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.science,
                color: Color(0xFF2AA39F),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itemName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.categoryName,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    if (item.quantity > 1) {
                      _cartService.updateQuantity(
                        item.itemId,
                        item.quantity - 1,
                      );
                    } else {
                      _cartService.removeItem(item.itemId);
                    }
                  },
                  icon: Icon(
                    item.quantity > 1 ? Icons.remove : Icons.delete_outline,
                    color:
                        item.quantity > 1
                            ? const Color(0xFF2AA39F)
                            : Colors.red,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    _cartService.updateQuantity(item.itemId, item.quantity + 1);
                  },
                  icon: const Icon(Icons.add, color: Color(0xFF2AA39F)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2AA39F).withValues(alpha: 0.05),
            const Color(0xFF52B788).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2AA39F).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2AA39F).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: Color(0xFF2AA39F),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You might also need',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    Text(
                      'Based on borrowing patterns',
                      style: TextStyle(fontSize: 12, color: Color(0xFF7F8C8D)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _recommendations.map((itemName) {
                  return InkWell(
                    onTap: () => _handleRecommendationTap(itemName),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF2AA39F).withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: Color(0xFF2AA39F),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              itemName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.add_circle_outline,
                            size: 16,
                            color: Color(0xFF2AA39F),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}
