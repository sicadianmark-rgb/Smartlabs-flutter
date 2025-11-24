// Helper script to find items with associations
// Run this in your app to find which items will trigger suggestions

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'association_mining_service.dart';

class FindAssociationsHelper {
  static final _database = FirebaseDatabase.instance;

  /// Find items that have association rules (will trigger suggestions)
  /// Returns a list of item pairs that are associated
  static Future<List<Map<String, String>>> findItemsWithAssociations() async {
    try {
      debugPrint('🔍 Finding items with associations...\n');

      // Get all association rules
      final rules = await AssociationMiningService.findAssociationRules(
        minSupport: 0.01, // Lower threshold to find more associations
        minConfidence: 0.25,
        minLift: 1.0,
      );

      if (rules.isEmpty) {
        debugPrint('❌ No association rules found.');
        debugPrint('💡 You need approved/returned batch borrow requests to create associations.');
        debugPrint('💡 Make sure you have batch requests (with batchId) that are approved or returned.\n');
        return [];
      }

      debugPrint('✅ Found ${rules.length} association rules:\n');

      // Group by itemA to show what each item suggests
      final Map<String, List<String>> itemSuggestions = {};
      
      for (var rule in rules) {
        itemSuggestions.putIfAbsent(rule.itemA, () => []);
        itemSuggestions[rule.itemA]!.add(rule.itemB);
      }

      // Print results
      debugPrint('📋 Items that will trigger suggestions:\n');
      itemSuggestions.forEach((itemA, suggestions) {
        debugPrint('  🛒 Add "$itemA" to cart → Will suggest:');
        for (var itemB in suggestions) {
          final rule = rules.firstWhere(
            (r) => r.itemA == itemA && r.itemB == itemB,
          );
          debugPrint('     • $itemB (Confidence: ${(rule.confidence * 100).toStringAsFixed(1)}%, Lift: ${rule.lift.toStringAsFixed(2)})');
        }
        debugPrint('');
      });

      // Return as list for programmatic use
      return rules.map((rule) => {
        'itemA': rule.itemA,
        'itemB': rule.itemB,
        'confidence': (rule.confidence * 100).toStringAsFixed(1),
        'lift': rule.lift.toStringAsFixed(2),
      }).toList();

    } catch (e) {
      debugPrint('❌ Error finding associations: $e');
      return [];
    }
  }

  /// Get a simple test case - returns first item that has associations
  static Future<Map<String, String>?> getTestItem() async {
    final associations = await findItemsWithAssociations();
    
    if (associations.isEmpty) {
      return null;
    }

    final firstAssociation = associations.first;
    return {
      'addToCart': firstAssociation['itemA']!,
      'willSuggest': firstAssociation['itemB']!,
      'confidence': firstAssociation['confidence']!,
      'lift': firstAssociation['lift']!,
    };
  }

  /// Check if database has batch requests with associations
  static Future<void> checkDatabaseStatus() async {
    try {
      debugPrint('🔍 Checking database for batch borrow requests...\n');

      final snapshot = await _database.ref().child('borrow_requests').get();

      if (!snapshot.exists) {
        debugPrint('❌ No borrow requests found in database.');
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      int totalRequests = data.length;
      int batchRequests = 0;
      int approvedBatchRequests = 0;
      int returnedBatchRequests = 0;

      final batchIds = <String, Set<String>>{};

      for (var request in data.values) {
        final requestData = request as Map<dynamic, dynamic>;
        final batchId = requestData['batchId'] as String?;
        final status = requestData['status'] as String?;
        final itemName = requestData['itemName'] as String?;

        if (batchId != null && itemName != null) {
          batchRequests++;
          batchIds.putIfAbsent(batchId, () => <String>{});
          batchIds[batchId]!.add(itemName);

          if (status == 'approved') {
            approvedBatchRequests++;
          } else if (status == 'returned') {
            returnedBatchRequests++;
          }
        }
      }

      // Count batches with at least 2 items
      int validBatches = 0;
      for (var items in batchIds.values) {
        if (items.length >= 2) {
          validBatches++;
        }
      }

      debugPrint('📊 Database Status:');
      debugPrint('   Total borrow requests: $totalRequests');
      debugPrint('   Batch requests (with batchId): $batchRequests');
      debugPrint('   Approved batch requests: $approvedBatchRequests');
      debugPrint('   Returned batch requests: $returnedBatchRequests');
      debugPrint('   Valid batches (≥2 items): $validBatches\n');

      if (validBatches == 0) {
        debugPrint('⚠️  No valid batches found for association rules.');
        debugPrint('💡 You need batch requests (with batchId) that have at least 2 items.');
        debugPrint('💡 These requests must be approved or returned.\n');
      } else {
        debugPrint('✅ Found $validBatches valid batches for association mining.\n');
      }

    } catch (e) {
      debugPrint('❌ Error checking database: $e');
    }
  }
}

