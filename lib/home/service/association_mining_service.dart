// lib/home/service/association_mining_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class AssociationRule {
  final String itemA;
  final String itemB;
  final double support; // How often both items appear together
  final double confidence; // Probability of B given A
  final double lift; // Strength of association
  final int coOccurrenceCount;

  AssociationRule({
    required this.itemA,
    required this.itemB,
    required this.support,
    required this.confidence,
    required this.lift,
    required this.coOccurrenceCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemA': itemA,
      'itemB': itemB,
      'support': support,
      'confidence': confidence,
      'lift': lift,
      'coOccurrenceCount': coOccurrenceCount,
    };
  }
}

class AssociationMiningService {
  static final _database = FirebaseDatabase.instance;

  /// Analyzes borrowing patterns and finds items frequently borrowed together
  /// Uses a simplified Apriori-like algorithm
  /// Based on history data where items are borrowed together in batches
  static Future<List<AssociationRule>> findAssociationRules({
    double minSupport = 0.02, // Minimum 2% support
    double minConfidence = 0.3, // Minimum 30% confidence
    double minLift = 1.0, // Lift > 1 indicates positive correlation
  }) async {
    try {
      // Step 1: Get all batch borrowings from history data
      final batchBorrowings = await _getBatchBorrowingPatternsFromHistory();

      if (batchBorrowings.isEmpty) {
        debugPrint('⚠️ No batch borrowing patterns found in history');
        return [];
      }

      debugPrint('📊 Found ${batchBorrowings.length} batch patterns in history');

      // Step 2: Find frequent item pairs (co-occurrences)
      final itemPairs = _findFrequentPairs(batchBorrowings);

      // Step 3: Calculate association metrics
      final rules = _calculateAssociationRules(
        itemPairs,
        batchBorrowings,
        minSupport,
        minConfidence,
        minLift,
      );

      // Step 4: Sort by lift (strongest associations first)
      rules.sort((a, b) => b.lift.compareTo(a.lift));

      debugPrint('✅ Generated ${rules.length} association rules');
      return rules;
    } catch (e) {
      debugPrint('❌ Error finding association rules: $e');
      return [];
    }
  }

  /// Get borrowing patterns grouped by batchId from history data
  /// Only considers entries with batchId (batch requests) and Released/Returned status
  static Future<Map<String, Set<String>>> _getBatchBorrowingPatternsFromHistory() async {
    try {
      final snapshot = await _database.ref().child('history').get();

      Map<String, Set<String>> batchBorrowings = {};

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        for (var entry in data.values) {
          final historyData = entry as Map<dynamic, dynamic>;
          final batchId = historyData['batchId'] as String?;
          final equipmentName = historyData['equipmentName'] as String?;
          final status = (historyData['status'] as String?)?.toLowerCase();
          final action = (historyData['action'] as String?)?.toLowerCase();

          // Only consider batch requests that are released or returned
          // Batch requests have batchId field, individual requests don't
          if (batchId != null &&
              equipmentName != null &&
              equipmentName.isNotEmpty &&
              equipmentName != 'Unknown' &&
              (status == 'released' || status == 'returned') &&
              (action?.contains('released') == true || action?.contains('returned') == true)) {
            
            batchBorrowings.putIfAbsent(batchId, () => <String>{});
            batchBorrowings[batchId]!.add(equipmentName);
          }
        }
      }

      // Filter batches with at least 2 different items (for meaningful associations)
      batchBorrowings.removeWhere((key, value) => value.length < 2);

      debugPrint('📦 Found ${batchBorrowings.length} batches with multiple items');
      
      // Debug: Print sample batches
      if (batchBorrowings.isNotEmpty) {
        final sampleBatch = batchBorrowings.entries.first;
        debugPrint('📝 Sample batch: ${sampleBatch.key} -> ${sampleBatch.value}');
      }

      return batchBorrowings;
    } catch (e) {
      debugPrint('❌ Error getting batch borrowing patterns from history: $e');
      return {};
    }
  }

  /// Find all pairs of items borrowed together in the same batch
  static Map<String, Map<String, int>> _findFrequentPairs(
    Map<String, Set<String>> batchBorrowings,
  ) {
    Map<String, Map<String, int>> pairCounts = {};

    for (var items in batchBorrowings.values) {
      final itemList = items.toList();

      // Generate all pairs from this batch's items
      for (int i = 0; i < itemList.length; i++) {
        for (int j = i + 1; j < itemList.length; j++) {
          final itemA = itemList[i];
          final itemB = itemList[j];

          // Ensure consistent ordering (alphabetical)
          final sortedPair = [itemA, itemB]..sort();
          final key1 = sortedPair[0];
          final key2 = sortedPair[1];

          pairCounts.putIfAbsent(key1, () => {});
          pairCounts[key1]!.update(
            key2,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }
    }

    debugPrint('🔗 Found ${pairCounts.length} unique item pairs');
    return pairCounts;
  }

  /// Calculate association rule metrics
  static List<AssociationRule> _calculateAssociationRules(
    Map<String, Map<String, int>> pairCounts,
    Map<String, Set<String>> batchBorrowings,
    double minSupport,
    double minConfidence,
    double minLift,
  ) {
    List<AssociationRule> rules = [];

    // Calculate total number of transactions (batches)
    final totalTransactions = batchBorrowings.length;

    // Count individual item frequencies
    Map<String, int> itemCounts = {};
    for (var items in batchBorrowings.values) {
      for (var item in items) {
        itemCounts.update(item, (count) => count + 1, ifAbsent: () => 1);
      }
    }

    // Generate rules for each pair
    pairCounts.forEach((itemA, itemBMap) {
      itemBMap.forEach((itemB, coOccurrenceCount) {
        // Calculate support: P(A ∩ B)
        final support = coOccurrenceCount / totalTransactions;

        if (support < minSupport) return;

        final countA = itemCounts[itemA] ?? 0;
        final countB = itemCounts[itemB] ?? 0;

        // Calculate confidence: P(B|A) = P(A ∩ B) / P(A)
        final confidenceAtoB = countA > 0 ? coOccurrenceCount / countA : 0;
        final confidenceBtoA = countB > 0 ? coOccurrenceCount / countB : 0;

        // Calculate lift: P(A ∩ B) / (P(A) * P(B))
        final probA = countA / totalTransactions;
        final probB = countB / totalTransactions;
        final lift = (probA * probB > 0) ? support / (probA * probB) : 0;

        // Create rule A -> B if it meets thresholds
        if (confidenceAtoB >= minConfidence && lift >= minLift) {
          rules.add(
            AssociationRule(
              itemA: itemA,
              itemB: itemB,
              support: support.toDouble(),
              confidence: confidenceAtoB.toDouble(),
              lift: lift.toDouble(),
              coOccurrenceCount: coOccurrenceCount,
            ),
          );
        }

        // Create rule B -> A if it meets thresholds
        if (confidenceBtoA >= minConfidence && lift >= minLift) {
          rules.add(
            AssociationRule(
              itemA: itemB,
              itemB: itemA,
              support: support.toDouble(),
              confidence: confidenceBtoA.toDouble(),
              lift: lift.toDouble(),
              coOccurrenceCount: coOccurrenceCount,
            ),
          );
        }
      });
    });

    return rules;
  }

  /// Get recommended items based on current cart/selection
  static Future<List<String>> getRecommendations(
    List<String> currentItems, {
    int maxRecommendations = 5,
  }) async {
    if (currentItems.isEmpty) return [];

    try {
      final rules = await findAssociationRules(
        minSupport: 0.01,
        minConfidence: 0.25,
        minLift: 1.0,
      );

      // Find items associated with current items
      Map<String, double> recommendationScores = {};

      for (var rule in rules) {
        if (currentItems.contains(rule.itemA) &&
            !currentItems.contains(rule.itemB)) {
          // Score based on confidence and lift
          final score = rule.confidence * rule.lift;
          recommendationScores.update(
            rule.itemB,
            (existing) => existing > score ? existing : score,
            ifAbsent: () => score,
          );
        }
      }

      // Sort by score and return top recommendations
      final recommendations =
          recommendationScores.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      return recommendations
          .take(maxRecommendations)
          .map((e) => e.key)
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting recommendations: $e');
      return [];
    }
  }

  /// Get borrowing pattern statistics from history
  static Future<Map<String, dynamic>> getBorrowingPatternStats() async {
    try {
      final batchBorrowings = await _getBatchBorrowingPatternsFromHistory();
      final rules = await findAssociationRules();

      return {
        'totalBatches': batchBorrowings.length,
        'totalRules': rules.length,
        'averageItemsPerBatch':
            batchBorrowings.isEmpty
                ? 0.0
                : batchBorrowings.values
                        .map((items) => items.length)
                        .reduce((a, b) => a + b) /
                    batchBorrowings.length,
        'strongestRule':
            rules.isNotEmpty
                ? {
                  'itemA': rules.first.itemA,
                  'itemB': rules.first.itemB,
                  'lift': rules.first.lift,
                  'confidence': rules.first.confidence,
                }
                : null,
      };
    } catch (e) {
      debugPrint('❌ Error getting pattern stats: $e');
      return {};
    }
  }

  /// Get all unique items from history (for debugging/testing)
  static Future<Set<String>> getAllItemsFromHistory() async {
    try {
      final snapshot = await _database.ref().child('history').get();
      final items = <String>{};

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        for (var entry in data.values) {
          final historyData = entry as Map<dynamic, dynamic>;
          final equipmentName = historyData['equipmentName'] as String?;
          
          if (equipmentName != null && 
              equipmentName.isNotEmpty && 
              equipmentName != 'Unknown') {
            items.add(equipmentName);
          }
        }
      }

      return items;
    } catch (e) {
      debugPrint('❌ Error getting items from history: $e');
      return {};
    }
  }
}