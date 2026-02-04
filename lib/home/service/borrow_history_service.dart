// lib/home/service/borrow_history_service.dart
// Separate history storage for approved/returned requests
// This serves as the permanent basis for association rule mining

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class BorrowHistoryService {
  static final _database = FirebaseDatabase.instance;

  /// Archive an approved request to history storage
  /// Called when a request status changes to 'approved'
  static Future<void> archiveApprovedRequest(
    String requestId,
    Map<dynamic, dynamic> requestData,
  ) async {
    try {
      // Archive all requests (both individual and batch)
      // Create history entry with timestamp
      final historyData = Map<String, dynamic>.from(requestData);
      historyData['archivedAt'] = DateTime.now().toIso8601String();
      historyData['originalRequestId'] = requestId;

      // Store in history with same requestId for traceability
      await _database
          .ref()
          .child('borrow_history')
          .child(requestId)
          .set(historyData);

      debugPrint('✅ Archived approved request to history: $requestId');
    } catch (e) {
      debugPrint('❌ Error archiving approved request: $e');
      // Don't throw - archiving is non-critical
    }
  }

  /// Archive a returned request to history storage
  /// Called when a request status changes to 'returned'
  static Future<void> archiveReturnedRequest(
    String requestId,
    Map<dynamic, dynamic> requestData,
  ) async {
    try {
      // Archive all requests (both individual and batch)
      // Update existing history entry or create new one
      final historyData = Map<String, dynamic>.from(requestData);
      historyData['archivedAt'] = DateTime.now().toIso8601String();
      historyData['originalRequestId'] = requestId;

      // Debug: Log what data is being archived
      debugPrint('🔄 ARCHIVING RETURNED REQUEST: $requestId');
      debugPrint('   UserId: ${historyData['userId']}');
      debugPrint('   AdviserId: ${historyData['adviserId']}');
      debugPrint('   ItemName: ${historyData['itemName']}');
      debugPrint('   Status: ${historyData['status']}');
      debugPrint('   ReturnedAt: ${historyData['returnedAt']}');

      // Check if already exists in history (from approval)
      final historySnapshot = await _database
          .ref()
          .child('borrow_history')
          .child(requestId)
          .get();

      if (historySnapshot.exists) {
        // Update existing entry
        await _database
            .ref()
            .child('borrow_history')
            .child(requestId)
            .update(historyData);
      } else {
        // Create new entry
        await _database
            .ref()
            .child('borrow_history')
            .child(requestId)
            .set(historyData);
      }

      debugPrint('✅ Archived returned request to history: $requestId');
    } catch (e) {
      debugPrint('❌ Error archiving returned request: $e');
    }
  }

  /// Migrate existing approved/returned requests to history
  /// Useful for one-time migration of existing data
  static Future<void> migrateExistingHistory() async {
    try {
      debugPrint('🔄 Starting migration of existing requests to history...');

      final snapshot = await _database.ref().child('borrow_requests').get();
      if (!snapshot.exists) {
        debugPrint('No requests found to migrate');
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      int migrated = 0;
      int skipped = 0;

      for (var entry in data.entries) {
        final requestId = entry.key;
        final requestData = entry.value as Map<dynamic, dynamic>;
        final status = requestData['status'] as String?;

        // Migrate all returned requests (not approved ones)
        // Approved requests should only be migrated when they become returned
        if (status == 'returned') {
          // Check if already in history
          final historySnapshot = await _database
              .ref()
              .child('borrow_history')
              .child(requestId)
              .get();

          if (!historySnapshot.exists) {
            final historyData = Map<String, dynamic>.from(requestData);
            historyData['archivedAt'] = DateTime.now().toIso8601String();
            historyData['originalRequestId'] = requestId;
            
            // Ensure returnedAt is set for returned items
            if (historyData['returnedAt'] == null || historyData['returnedAt'] == '') {
              historyData['returnedAt'] = requestData['processedAt'] ?? DateTime.now().toIso8601String();
            }

            await _database
                .ref()
                .child('borrow_history')
                .child(requestId)
                .set(historyData);
            migrated++;
          }
        } else {
          skipped++;
        }
      }

      debugPrint('✅ Migration complete: $migrated migrated, $skipped skipped');
    } catch (e) {
      debugPrint('❌ Error migrating history: $e');
      rethrow;
    }
  }

  /// Get all historical batch borrowings for association rule mining
  /// This is the new source for association rules
  static Future<Map<String, Set<String>>> getHistoricalBatchPatterns() async {
    try {
      final snapshot = await _database.ref().child('borrow_history').get();

      Map<String, Set<String>> batchBorrowings = {};

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        for (var request in data.values) {
          final requestData = request as Map<dynamic, dynamic>;
          final batchId = requestData['batchId'] as String?;
          final itemName = requestData['itemName'] as String?;
          final status = requestData['status'] as String?;

          // Only consider approved or returned batch requests
          if (batchId != null &&
              itemName != null &&
              (status == 'approved' || status == 'returned') &&
              itemName != 'Unknown') {
            batchBorrowings.putIfAbsent(batchId, () => <String>{});
            batchBorrowings[batchId]!.add(itemName);
          }
        }
      }

      // Filter batches with at least 2 different items
      batchBorrowings.removeWhere((key, value) => value.length < 2);

      debugPrint(
        '📊 Found ${batchBorrowings.length} historical batches for association mining',
      );

      return batchBorrowings;
    } catch (e) {
      debugPrint('❌ Error getting historical batch patterns: $e');
      return {};
    }
  }

  /// Check if migration is needed and run it automatically
  /// This can be called during app initialization
  static Future<void> ensureHistoryMigration() async {
    try {
      // Check if there are any borrow_requests that haven't been migrated
      final borrowRequestsSnapshot = await _database.ref().child('borrow_requests').get();
      
      if (!borrowRequestsSnapshot.exists) {
        debugPrint('No borrow requests found, no migration needed');
        return;
      }
      
      final borrowRequestsData = borrowRequestsSnapshot.value as Map<dynamic, dynamic>;
      int needsMigration = 0;
      
      // Check if any returned requests need migration
      for (var entry in borrowRequestsData.entries) {
        final requestId = entry.key;
        final requestData = entry.value as Map<dynamic, dynamic>;
        final status = requestData['status'] as String?;
        
        if (status == 'returned') {
          // Check if already in history
          final historySnapshot = await _database
              .ref()
              .child('borrow_history')
              .child(requestId)
              .get();
          
          if (!historySnapshot.exists) {
            needsMigration++;
          }
        }
      }
      
      // Run migration only if there are items that need it
      if (needsMigration > 0) {
        debugPrint('🔄 Found $needsMigration requests needing migration, running migration...');
        await migrateExistingHistory();
      } else {
        debugPrint('✅ All requests already migrated, skipping migration');
      }
    } catch (e) {
      debugPrint('❌ Error checking migration status: $e');
    }
  }

  /// Force migration of all returned requests
  /// This can be used to manually trigger migration if needed
  static Future<void> forceMigration() async {
    debugPrint('🔄 Forcing migration of all returned requests...');
    await migrateExistingHistory();
  }

  /// Clean up old history entries (optional, for maintenance)
  /// Keeps only entries older than specified days
  static Future<void> cleanupOldHistory({int keepDays = 365}) async {
    try {
      final snapshot = await _database.ref().child('borrow_history').get();
      if (!snapshot.exists) return;

      final data = snapshot.value as Map<dynamic, dynamic>;
      final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
      int deleted = 0;

      for (var entry in data.entries) {
        final requestData = entry.value as Map<dynamic, dynamic>;
        final archivedAt = requestData['archivedAt'] as String?;

        if (archivedAt != null) {
          try {
            final archiveDate = DateTime.parse(archivedAt);
            if (archiveDate.isBefore(cutoffDate)) {
              await _database
                  .ref()
                  .child('borrow_history')
                  .child(entry.key)
                  .remove();
              deleted++;
            }
          } catch (e) {
            // Skip entries with invalid dates
            continue;
          }
        }
      }

      debugPrint('🧹 Cleaned up $deleted old history entries');
    } catch (e) {
      debugPrint('❌ Error cleaning up history: $e');
    }
  }
}

