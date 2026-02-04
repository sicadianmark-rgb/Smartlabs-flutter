import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'service/due_date_reminder_service.dart';
import 'service/borrow_history_service.dart';
import 'service/notification_service.dart';

class BorrowingHistoryPage extends StatefulWidget {
  const BorrowingHistoryPage({super.key});

  @override
  State<BorrowingHistoryPage> createState() => _BorrowingHistoryPageState();
}

class _BorrowingHistoryPageState extends State<BorrowingHistoryPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allRequests = [];
  List<Map<String, dynamic>> _currentBorrows = [];
  List<Map<String, dynamic>> _returnedItems = [];
  List<Map<String, dynamic>> _rejectedItems = [];
  late TabController _tabController;
  Map<String, String> _requestStatuses = {};
  final Set<String> _sentReminderKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadBorrowingHistory();
    _setupRealtimeListener();
    _checkDueDateReminders();
    
    // Force immediate sync to ensure returned items have correct status
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint('🔄 FORCE SYNC ON PAGE LOAD');
      await _syncReturnedRequestsToHistory();
      // Reload after sync to get updated data
      await _loadBorrowingHistory();
      debugPrint('✅ FORCE SYNC COMPLETED');
    });
  }

  Future<void> _checkDueDateReminders() async {
    // Check for due date reminders when viewing borrowing history
    await DueDateReminderService.checkAndSendReminders();
  }

  void _setupRealtimeListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Listen for changes to borrow_requests where user is requester - exactly like student UI
    FirebaseDatabase.instance
        .ref()
        .child('borrow_requests')
        .orderByChild('userId')
        .equalTo(user.uid)
        .onValue
        .listen((event) {
          if (mounted && event.snapshot.exists) {
            unawaited(_processRealtimeUpdate(event.snapshot));
          }
        });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBorrowingHistory() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Ensure history migration is up to date
      await BorrowHistoryService.ensureHistoryMigration();

      // Load data from both borrow_requests and borrow_history
      // For instructor UI, behave exactly like student UI - only show own requests
      final borrowRequestsSnapshot =
          await FirebaseDatabase.instance
              .ref()
              .child('borrow_requests')
              .orderByChild('userId')
              .equalTo(user.uid)
              .get();

      // For borrow_history, we need to get all data and filter client-side
      // since userId might not be indexed in the history collection
      final borrowHistorySnapshot =
          await FirebaseDatabase.instance
              .ref()
              .child('borrow_history')
              .get();

      await _processSnapshots(borrowRequestsSnapshot, borrowHistorySnapshot, user.uid);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      _showSnackBar('Error loading borrowing history: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processRealtimeUpdate(DataSnapshot snapshot) async {
    // For real-time updates, we only need to reload the full data
    // This ensures consistency between current and historical data
    await _loadBorrowingHistory();
    
    // Also check for returned requests that need to be synced to history
    await _syncReturnedRequestsToHistory();
  }

  Future<void> _syncReturnedRequestsToHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      debugPrint('🔄 STARTING SYNC OF RETURNED REQUESTS TO HISTORY');
      
      // Get all requests where user is the requester - exactly like student UI
      final borrowRequestsSnapshot =
          await FirebaseDatabase.instance
              .ref()
              .child('borrow_requests')
              .orderByChild('userId')
              .equalTo(user.uid)
              .get();

      if (!borrowRequestsSnapshot.exists) {
        debugPrint('📭 No borrow requests found');
        return;
      }

      final data = borrowRequestsSnapshot.value as Map<dynamic, dynamic>;
      int syncedCount = 0;
      int updatedCount = 0;
      
      debugPrint('🔄 PROCESSING ${data.length} REQUESTS FOR SYNC');
      
      for (var entry in data.entries) {
        final requestId = entry.key.toString();
        final requestData = entry.value as Map<dynamic, dynamic>;
        
        // Check if this request is from the current user - exactly like student UI
        final userId = requestData['userId']?.toString();
        
        if (userId != user.uid) continue;
        
        // Check if request is returned but not properly in history
        final status = requestData['status']?.toString();
        final returnedAt = requestData['returnedAt']?.toString();
        
        debugPrint('🔍 CHECKING REQUEST: $requestId - Status: $status - ReturnedAt: $returnedAt');
        
        // AGGRESSIVE: Include if returned OR has returnedAt OR is in history but should be returned
        final needsSync = (status == 'returned') || 
                         (returnedAt != null && returnedAt != '') ||
                         (status == 'approved' && returnedAt != null && returnedAt != '') ||
                         (status == 'released' && returnedAt != null && returnedAt != '');
        
        debugPrint('   Needs sync: $needsSync (status=$status, returnedAt=$returnedAt)');
        
        if (needsSync) {
          // Check if this returned request exists in history
          final historySnapshot = await FirebaseDatabase.instance
              .ref()
              .child('borrow_history')
              .child(requestId)
              .get();
          
          if (!historySnapshot.exists) {
            // Archive this returned request to history
            debugPrint('🔄 CREATING NEW HISTORY ENTRY FOR RETURNED REQUEST: $requestId');
            final historyData = Map<String, dynamic>.from(requestData);
            historyData['archivedAt'] = DateTime.now().toIso8601String();
            historyData['originalRequestId'] = requestId;
            
            await FirebaseDatabase.instance
                .ref()
                .child('borrow_history')
                .child(requestId)
                .set(historyData);
            
            syncedCount++;
            debugPrint('✅ Created history entry for returned request: $requestId');
          } else {
            // ALWAYS update existing history entry with returned status and timestamp
            // NO CONDITIONS - always force update to ensure consistency
            debugPrint('🔄 FORCE UPDATING EXISTING HISTORY ENTRY: $requestId');
            final historyData = historySnapshot.value as Map<dynamic, dynamic>;
            final currentHistoryStatus = historyData['status']?.toString();
            final currentHistoryReturnedAt = historyData['returnedAt']?.toString();
            
            debugPrint('   Current history status: "$currentHistoryStatus"');
            debugPrint('   Current history returnedAt: "$currentHistoryReturnedAt"');
            debugPrint('   New status from borrow_requests: "$status"');
            debugPrint('   New returnedAt from borrow_requests: "$returnedAt"');
            
            final updateData = Map<String, dynamic>.from(requestData);
            updateData['archivedAt'] = DateTime.now().toIso8601String();
            // ALWAYS FORCE the status to be 'returned' and ensure returnedAt is set
            updateData['status'] = 'returned';
            updateData['returnedAt'] = returnedAt;
            
            debugPrint('   FORCING update:');
            debugPrint('     Old status: $currentHistoryStatus');
            debugPrint('     New status: ${updateData['status']}');
            debugPrint('     Old returnedAt: $currentHistoryReturnedAt');
            debugPrint('     New returnedAt: ${updateData['returnedAt']}');
            
            await FirebaseDatabase.instance
                .ref()
                .child('borrow_history')
                .child(requestId)
                .update(updateData);
            
            updatedCount++;
            debugPrint('✅ FORCE UPDATED history entry: $requestId');
            debugPrint('   Forced status to: returned');
            debugPrint('   Set returnedAt to: $returnedAt');
            debugPrint('   Previous status was: $currentHistoryStatus');
          }
        }
      }
      
      debugPrint('📊 SYNC SUMMARY: Created $syncedCount new entries, Updated $updatedCount existing entries');
      
      // Reload history if we made any changes
      if (syncedCount > 0 || updatedCount > 0) {
        debugPrint('🔄 RELOADING HISTORY AFTER SYNC');
        await _loadBorrowingHistory();
      }
    } catch (e) {
      debugPrint('❌ Error syncing returned requests to history: $e');
    }
  }

  Future<void> _processSnapshots(
    DataSnapshot userRequestsSnapshot,
    DataSnapshot borrowHistorySnapshot,
    String userId,
  ) async {
    List<Map<String, dynamic>> allUserRequests = [];
    final List<Map<String, dynamic>> newlyApprovedRequests = [];
    final List<Map<String, dynamic>> newlyReleasedRequests = [];

    // Process user's own requests (where they are the requester) - exactly like student UI
    if (userRequestsSnapshot.exists) {
      final data = userRequestsSnapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        final request = Map<String, dynamic>.from(value);
        request['id'] = key;
        request['dataSource'] = 'borrow_requests';
        request['requestType'] = 'own'; // Mark as own request
        // Ensure status field exists, default to pending if missing
        if (!request.containsKey('status') || request['status'] == null) {
          request['status'] = 'pending';
        }

        final requestId = key.toString();
        final currentStatus = request['status']?.toString();
        final previousStatus = _requestStatuses[requestId];
        if ((previousStatus == null || previousStatus != 'approved') &&
            currentStatus == 'approved') {
          newlyApprovedRequests.add(request);
        }
        if ((previousStatus == null || previousStatus != 'released') &&
            currentStatus == 'released') {
          newlyReleasedRequests.add(request);
        }
        allUserRequests.add(request);
      });
    }

    // Process historical borrow requests - exactly like student UI
    if (borrowHistorySnapshot.exists) {
      final data = borrowHistorySnapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        final request = Map<String, dynamic>.from(value);
        // Filter by userId only (like student UI)
        if (request['userId'] == userId) {
          request['id'] = key;
          request['dataSource'] = 'borrow_history';
          request['requestType'] = 'own'; // Mark as own request
          // Ensure status field exists
          if (!request.containsKey('status') || request['status'] == null) {
            request['status'] = 'returned'; // Default to returned for historical items
          }
          allUserRequests.add(request);
        }
      });
    }

    // Remove duplicates - prefer history entries over current requests for returned items
    final Map<String, Map<String, dynamic>> uniqueRequests = {};
    for (var request in allUserRequests) {
      final requestId = request['id']?.toString() ?? '';
      if (requestId.isEmpty) continue;
      
      // If this request already exists, decide which one to keep
      if (uniqueRequests.containsKey(requestId)) {
        final existing = uniqueRequests[requestId]!;
        final existingStatus = existing['status']?.toString() ?? '';
        final newStatus = request['status']?.toString() ?? '';
        
        // Prefer the entry with more recent status information
        // History entries (borrow_history) are preferred for returned items
        // Current requests (borrow_requests) are preferred for active items
        if (request['dataSource'] == 'borrow_history' && newStatus == 'returned') {
          uniqueRequests[requestId] = request;
        } else if (existing['dataSource'] == 'borrow_history' && existingStatus == 'returned') {
          // Keep existing history entry
        } else if (request['dataSource'] == 'borrow_requests' && 
                   (newStatus == 'pending' || newStatus == 'approved' || newStatus == 'released')) {
          uniqueRequests[requestId] = request;
        }
      } else {
        uniqueRequests[requestId] = request;
      }
    }
    
    // Convert back to list
    allUserRequests = uniqueRequests.values.toList();

    // Debug: Log deduplication results
    debugPrint('🔍 DEDUPLICATION RESULTS:');
    debugPrint('   Total unique requests: ${uniqueRequests.length}');
    for (var entry in uniqueRequests.entries) {
      final request = entry.value;
      debugPrint('   ${entry.key}: ${request['itemName']} - Status: ${request['status']} - Source: ${request['dataSource']}');
    }

    // Sort all requests by date (newest first)
    allUserRequests.sort(
      (a, b) {
        final aDate = a['requestedAt']?.toString() ?? a['archivedAt']?.toString() ?? '';
        final bDate = b['requestedAt']?.toString() ?? b['archivedAt']?.toString() ?? '';
        return bDate.compareTo(aDate);
      },
    );

      // Debug: Print all raw data first
      debugPrint('📊 Total allUserRequests: ${allUserRequests.length}');
      debugPrint('🔍 User ID: $userId');
      debugPrint('🔍 DETAILED RAW DATA ANALYSIS:');
      for (var item in allUserRequests) {
        final status = item['status']?.toString();
        final returnedAt = item['returnedAt']?.toString();
        final dataSource = item['dataSource']?.toString();
        final itemName = item['itemName']?.toString();
        
        debugPrint('📋 ITEM: $itemName');
        debugPrint('   Status: "$status"');
        debugPrint('   ReturnedAt: "$returnedAt"');
        debugPrint('   DataSource: "$dataSource"');
        debugPrint('   Status == returned: ${status == 'returned'}');
        debugPrint('   Has returnedAt: ${returnedAt != null && returnedAt != ''}');
        debugPrint('   Is history with returnedAt: ${dataSource == 'borrow_history' && returnedAt != null && returnedAt != ''}');
        debugPrint('   Is request with returnedAt: ${dataSource == 'borrow_requests' && returnedAt != null && returnedAt != ''}');
        debugPrint('   ---');
      }

      setState(() {
        // Debug: Show what we're working with
        debugPrint('🔍 DEBUGGING: Total items before filtering: ${allUserRequests.length}');
        debugPrint('🔍 DETAILED ITEM ANALYSIS:');
        for (var item in allUserRequests) {
          final status = item['status']?.toString();
          final returnedAt = item['returnedAt']?.toString();
          final dataSource = item['dataSource']?.toString();
          final itemName = item['itemName']?.toString();
          final requestId = item['id']?.toString();
          
          debugPrint('📋 ITEM: $itemName (ID: $requestId)');
          debugPrint('   Status: "$status"');
          debugPrint('   DataSource: "$dataSource"');
          debugPrint('   ReturnedAt: "$returnedAt"');
          debugPrint('   Will show in CURRENT: ${status == 'pending' || status == 'approved' || status == 'released'}');
          debugPrint('   Will show in RETURNED: ${status == 'returned'}');
          debugPrint('   ---');
        }

        // CURRENT: Only items from borrow_requests that are truly active (exactly like admin panel)
        debugPrint('🔄 CURRENT TAB FILTERING (EXACTLY LIKE ADMIN PANEL):');
        _currentBorrows = [];
        for (var r in allUserRequests) {
          final status = r['status']?.toString();
          final itemName = r['itemName']?.toString();
          final dataSource = r['dataSource']?.toString();
          final returnedAt = r['returnedAt']?.toString();
          
          // Only include items from borrow_requests that are active (no returnedAt)
          // This exactly matches what admin panel sees
          final isCurrentActive = (dataSource == 'borrow_requests') &&
                                 (returnedAt == null || returnedAt == '') &&
                                 (status == 'pending' || status == 'approved' || status == 'released');
          
          debugPrint('🔍 CHECKING: $itemName');
          debugPrint('   Status: "$status"');
          debugPrint('   DataSource: "$dataSource"');
          debugPrint('   ReturnedAt: "$returnedAt"');
          debugPrint('   Is current active (like admin): $isCurrentActive');
          
          if (isCurrentActive) {
            _currentBorrows.add(r);
            debugPrint('   ✅ INCLUDED in CURRENT (active request)');
          } else {
            debugPrint('   ❌ EXCLUDED from CURRENT');
            if (dataSource != 'borrow_requests') {
              debugPrint('   Reason: From history, not active requests');
            } else if (returnedAt != null && returnedAt != '') {
              debugPrint('   Reason: Has returnedAt - already returned');
            } else if (status != 'pending' && status != 'approved' && status != 'released') {
              debugPrint('   Reason: Status is $status - not active');
            }
          }
          debugPrint('   ---');
        }

        // RETURNED: Show ALL items that could possibly be returned (aggressive approach)
        debugPrint('🔄 RETURNED TAB FILTERING (AGGRESSIVE - SHOW ALL RETURNED):');
        _returnedItems = [];
        for (var r in allUserRequests) {
          final status = r['status']?.toString();
          final itemName = r['itemName']?.toString();
          final dataSource = r['dataSource']?.toString();
          final returnedAt = r['returnedAt']?.toString();
          
          // AGGRESSIVE: Include if ANY of these conditions are true
          final isReturned = (status == 'returned') ||                           // Status is returned
                            (returnedAt != null && returnedAt != '') ||           // Has returnedAt timestamp
                            (dataSource == 'borrow_history' && status != 'pending' && status != 'rejected'); // History items that aren't pending/rejected
          
          debugPrint('🔍 CHECKING: $itemName');
          debugPrint('   Status: "$status"');
          debugPrint('   DataSource: "$dataSource"');
          debugPrint('   ReturnedAt: "$returnedAt"');
          debugPrint('   Is returned (aggressive): $isReturned');
          
          if (isReturned) {
            _returnedItems.add(r);
            debugPrint('   ✅ INCLUDED in RETURNED');
          } else {
            debugPrint('   ❌ EXCLUDED from RETURNED');
          }
          debugPrint('   ---');
        }

        // REJECTED: Items with status = 'rejected'
        _rejectedItems = allUserRequests
            .where((r) => r['status'] == 'rejected')
            .toList();

        // ALL = CURRENT + RETURNED + REJECTED
        _allRequests = [];
        _allRequests.addAll(_currentBorrows);
        _allRequests.addAll(_returnedItems);
        _allRequests.addAll(_rejectedItems);

        debugPrint('🔊 RESULTS:');
        debugPrint('   Current items: ${_currentBorrows.length}');
        debugPrint('   Returned items: ${_returnedItems.length}');
        debugPrint('   Rejected items: ${_rejectedItems.length}');
        debugPrint('   All items: ${_allRequests.length}');
        
        // Debug: Show actual status of returned items
        debugPrint('🔍 RETURNED ITEMS STATUS CHECK:');
        for (var item in _returnedItems) {
          debugPrint('   ${item['itemName']}: Status = "${item['status']}", ReturnedAt = "${item['returnedAt']}", Source = ${item['dataSource']}');
        }

        // Debug: Find items that left CURRENT but didn't reach RETURNED
        debugPrint('🔍 Checking for items that left CURRENT but might not be in RETURNED:');
        for (var item in allUserRequests) {
          final isInCurrent = _currentBorrows.contains(item);
          final isInReturned = _returnedItems.contains(item);
          final hasReturnedAt = item['returnedAt'] != null && item['returnedAt'] != '';
          final status = item['status']?.toString().toLowerCase();
          
          if (!isInCurrent && !isInReturned) {
            debugPrint('⚠️ ITEM NOT IN EITHER TAB: ${item['itemName']}');
            debugPrint('   Status: ${item['status']} - Source: ${item['dataSource']} - ReturnedAt: ${item['returnedAt']}');
            debugPrint('   Has returnedAt: $hasReturnedAt - Status lowercase: $status');
          }
          
          if (hasReturnedAt && !isInReturned) {
            debugPrint('❌ HAS returnedAt BUT NOT IN RETURNED: ${item['itemName']}');
            debugPrint('   Status: ${item['status']} - Source: ${item['dataSource']} - ReturnedAt: ${item['returnedAt']}');
          }
        }

        // Debug: Check for duplicates in returned items
        debugPrint('🔍 Checking for duplicates in returned items:');
        final Map<String, List<Map<String, dynamic>>> duplicateCheck = {};
        for (var item in _returnedItems) {
          final itemId = item['id']?.toString() ?? '';
          if (itemId.isNotEmpty) {
            duplicateCheck.putIfAbsent(itemId, () => []).add(item);
          }
        }
        
        for (var entry in duplicateCheck.entries) {
          if (entry.value.length > 1) {
            debugPrint('🔄 DUPLICATE FOUND: ${entry.key} - Count: ${entry.value.length}');
            for (var item in entry.value) {
              debugPrint('   - ${item['itemName']} - Source: ${item['dataSource']} - Status: ${item['status']}');
            }
          }
        }

        // Sort all requests by date (newest first)
        _allRequests.sort(
          (a, b) {
            final aDate = a['requestedAt']?.toString() ?? a['archivedAt']?.toString() ?? '';
            final bDate = b['requestedAt']?.toString() ?? b['archivedAt']?.toString() ?? '';
            return bDate.compareTo(aDate);
          },
        );
        
        // Debug: Detailed tracking of CURRENT to RETURNED flow
        debugPrint('🔍 Current items (PENDING/APPROVED/RELEASED): ${_currentBorrows.length}');
        for (var item in _currentBorrows) {
          debugPrint('📋 CURRENT: ${item['itemName']} - Status: ${item['status']} - Source: ${item['dataSource']} - ReturnedAt: ${item['returnedAt']}');
        }
        
        debugPrint('🔄 Returned items (status = returned): ${_returnedItems.length}');
        for (var item in _returnedItems) {
          debugPrint('📋 RETURNED: ${item['itemName']} - Status: ${item['status']} - Source: ${item['dataSource']} - ReturnedAt: ${item['returnedAt']}');
        }
        
        debugPrint('📊 ALL items (CURRENT + RETURNED): ${_allRequests.length}');
      
      // Debug: Check for items that should be returned but aren't showing
      debugPrint('🔍 Checking for items with returned status that might be missed:');
      for (var item in allUserRequests) {
        if (item['status'] == 'returned' && !_returnedItems.contains(item)) {
          debugPrint('❌ MISSED RETURNED: ${item['itemName']} - Status: ${item['status']} - Source: ${item['dataSource']}');
        }
      }
      _requestStatuses = {
        for (final request in allUserRequests)
          if (request['id'] != null)
            request['id'].toString(): request['status']?.toString() ?? 'pending',
      };
      });

    await _notifyApprovedRequests(newlyApprovedRequests);
    await _notifyReleasedRequests(newlyReleasedRequests);
    await _notifyDueStatusReminders(_currentBorrows);
  }

  Future<void> _notifyDueStatusReminders(
    List<Map<String, dynamic>> currentBorrows,
  ) async {
    if (currentBorrows.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final nowPhilippines = DateTime.now().toUtc().add(const Duration(hours: 8));
    final reminderDateKey = DateFormat('yyyy-MM-dd').format(nowPhilippines);

    for (final request in currentBorrows) {
      if (request['status'] != 'released') continue;

      final dateToReturnRaw = request['dateToReturn']?.toString();
      if (dateToReturnRaw == null || dateToReturnRaw.isEmpty) continue;

      final dueStatus = DueDateReminderService.getDueDateStatus(dateToReturnRaw);
      if (dueStatus != 'due_today' && dueStatus != 'overdue') continue;

      final requestId = request['id']?.toString();
      if (requestId == null) continue;

      DateTime? dueDatePhilippines;
      try {
        final parsedDate = DateTime.parse(dateToReturnRaw);
        dueDatePhilippines = parsedDate.toUtc().add(const Duration(hours: 8));
      } catch (_) {
        continue;
      }

      final reminderKey = 'reminder_${requestId}_${dueStatus}_$reminderDateKey';
      if (_sentReminderKeys.contains(reminderKey)) continue;
      _sentReminderKeys.add(reminderKey);

      final reminderRef = FirebaseDatabase.instance
          .ref()
          .child('reminders_sent')
          .child(user.uid)
          .child(reminderKey);

      try {
        final alreadySent = await reminderRef.get();
        if (alreadySent.exists) continue;

        final formattedDueDate =
            DateFormat('MMM dd, yyyy').format(dueDatePhilippines);

        await NotificationService.sendReminderNotification(
          userId: user.uid,
          itemName: request['itemName']?.toString() ?? 'Equipment',
          dueDate: formattedDueDate,
          reminderType: dueStatus!,
        );

        await reminderRef.set({
          'requestId': requestId,
          'itemName': request['itemName']?.toString() ?? 'Equipment',
          'reminderType': dueStatus,
          'source': 'borrowing_history_page',
          'sentAt': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Error sending due status reminder: $e');
      }
    }
  }

  Future<void> _notifyApprovedRequests(
    List<Map<String, dynamic>> newlyApproved,
  ) async {
    if (newlyApproved.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    for (final request in newlyApproved) {
      final requestId = request['id']?.toString();
      if (requestId == null) continue;

      final flagKey = 'status_${requestId}_approved';
      final flagRef = FirebaseDatabase.instance
          .ref()
          .child('notification_flags')
          .child(user.uid)
          .child(flagKey);

      try {
        final alreadyFlagged = await flagRef.get();
        if (alreadyFlagged.exists) continue;

        await NotificationService.sendNotificationToUser(
          userId: user.uid,
          title: 'Request Approved',
          message:
              'Your request for ${request['itemName'] ?? 'equipment'} has been approved.',
          type: 'success',
          additionalData: {
            'requestId': requestId,
            'status': 'approved',
            'itemName': request['itemName'] ?? 'equipment',
          },
        );

        await flagRef.set({
          'requestId': requestId,
          'status': 'approved',
          'sentAt': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Error notifying approval: $e');
      }
    }
  }

  Future<void> _notifyReleasedRequests(
    List<Map<String, dynamic>> newlyReleased,
  ) async {
    if (newlyReleased.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    for (final request in newlyReleased) {
      final requestId = request['id']?.toString();
      if (requestId == null) continue;

      final flagKey = 'status_${requestId}_released';
      final flagRef = FirebaseDatabase.instance
          .ref()
          .child('notification_flags')
          .child(user.uid)
          .child(flagKey);

      try {
        final alreadyFlagged = await flagRef.get();
        if (alreadyFlagged.exists) continue;

        await NotificationService.sendNotificationToUser(
          userId: user.uid,
          title: 'Item Released',
          message:
              'Your request for ${request['itemName'] ?? 'equipment'} has been released and is ready for pickup.',
          type: 'success',
          additionalData: {
            'requestId': requestId,
            'status': 'released',
            'itemName': request['itemName'] ?? 'equipment',
          },
        );

        await flagRef.set({
          'requestId': requestId,
          'status': 'released',
          'sentAt': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Error notifying release: $e');
      }
    }
  }

  Future<void> _deleteRequest(String requestId, String itemName) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Request'),
          content: Text('Are you sure you want to delete the request for "$itemName"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE74C3C),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Delete from borrow_requests
      await FirebaseDatabase.instance
          .ref()
          .child('borrow_requests')
          .child(requestId)
          .remove();

      // Delete from borrow_history if it exists
      await FirebaseDatabase.instance
          .ref()
          .child('borrow_history')
          .child(requestId)
          .remove();

      // Delete from user's borrow_requests subcollection
      await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child('borrow_requests')
          .child(requestId)
          .remove();

      _showSnackBar('Request deleted successfully!', isError: false);
      _loadBorrowingHistory();
    } catch (e) {
      _showSnackBar('Error deleting request: $e', isError: true);
    }
  }

  Future<void> _markAsReturned(String requestId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get request data to update equipment quantity
      final requestSnapshot = await FirebaseDatabase.instance
          .ref()
          .child('borrow_requests')
          .child(requestId)
          .get();

      if (!requestSnapshot.exists) {
        _showSnackBar('Request not found', isError: true);
        return;
      }

      final requestData = requestSnapshot.value as Map<dynamic, dynamic>;
      final status = requestData['status'] as String?;

      // Update request status
      final updatedRequestData = Map<String, dynamic>.from(requestData);
      updatedRequestData['returnedAt'] = DateTime.now().toIso8601String();
      updatedRequestData['status'] = 'returned';

      await FirebaseDatabase.instance
          .ref()
          .child('borrow_requests')
          .child(requestId)
          .update({
            'returnedAt': updatedRequestData['returnedAt'],
            'status': updatedRequestData['status'],
          });

      // Decrement quantity_borrowed if the request was approved/released
      if (status == 'approved' || status == 'released') {
        await _updateEquipmentQuantityBorrowed(
          requestData['itemId'],
          requestData['categoryId'],
          requestData['quantity'],
          increment: false,
        );
      }

      // Archive to history storage for association rule mining
      await BorrowHistoryService.archiveReturnedRequest(
        requestId,
        updatedRequestData,
      );

      _showSnackBar('Item marked as returned successfully!', isError: false);
      _loadBorrowingHistory();
    } catch (e) {
      _showSnackBar('Error marking item as returned: $e', isError: true);
    }
  }

  Future<void> _updateEquipmentQuantityBorrowed(
    String itemId,
    String categoryId,
    Object? quantity, {
    required bool increment,
  }) async {
    try {
      final quantityValue = int.tryParse(quantity.toString()) ?? 1;
      
      // Get current equipment item
      final itemSnapshot = await FirebaseDatabase.instance
          .ref()
          .child('equipment_categories')
          .child(categoryId)
          .child('equipments')
          .child(itemId)
          .get();

      if (itemSnapshot.exists) {
        final itemData = itemSnapshot.value as Map<dynamic, dynamic>;
        final currentBorrowed =
            int.tryParse(itemData['quantity_borrowed']?.toString() ?? '0') ?? 0;
        
        final newBorrowed = increment
            ? currentBorrowed + quantityValue
            : (currentBorrowed - quantityValue).clamp(0, double.infinity).toInt();

        // Update quantity_borrowed
        await FirebaseDatabase.instance
            .ref()
            .child('equipment_categories')
            .child(categoryId)
            .child('equipments')
            .child(itemId)
            .update({
              'quantity_borrowed': newBorrowed,
              'updatedAt': DateTime.now().toIso8601String(),
            });

        // Update category counts
        await _updateCategoryCounts(categoryId);
      }
    } catch (e) {
      debugPrint('Error updating equipment quantity_borrowed: $e');
    }
  }

  Future<void> _updateCategoryCounts(String categoryId) async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('equipment_categories')
          .child(categoryId)
          .child('equipments')
          .get();

      int totalCount = 0;
      int availableCount = 0;

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        for (var itemData in data.values) {
          final item = itemData as Map<dynamic, dynamic>;
          final quantity =
              int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
          final quantityBorrowed =
              int.tryParse(item['quantity_borrowed']?.toString() ?? '0') ?? 0;

          totalCount += quantity;

          if (item['status']?.toString().toLowerCase() == 'available') {
            final available = (quantity - quantityBorrowed).clamp(0, quantity);
            availableCount += available;
          }
        }
      }

      await FirebaseDatabase.instance
          .ref()
          .child('equipment_categories')
          .child(categoryId)
          .update({
            'totalCount': totalCount,
            'availableCount': availableCount,
            'updatedAt': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      debugPrint('Error updating category counts: $e');
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor:
            isError ? const Color(0xFFE74C3C) : const Color(0xFF27AE60),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF2AA39F),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF2AA39F),
              tabs: [
                Tab(
                  child: Text(
                    'All (${_allRequests.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Tab(
                  child: Text(
                    'Current (${_currentBorrows.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Tab(
                  child: Text(
                    'Returned (${_returnedItems.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Tab(
                  child: Text(
                    'Rejected (${_rejectedItems.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.history, color: Color(0xFF2AA39F), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Borrowing History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF2AA39F)),
                    onPressed: () async {
                      debugPrint('🔄 MANUAL REFRESH AND SYNC TRIGGERED');
                      await _loadBorrowingHistory();
                      await _syncReturnedRequestsToHistory();
                      // Force reload again after sync
                      await _loadBorrowingHistory();
                      debugPrint('✅ MANUAL SYNC COMPLETED');
                    },
                    tooltip: 'Refresh history and sync returned items',
                  ),
                ),
              ],
            ),
          ),
          _isLoading
              ? const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF2AA39F)),
                      SizedBox(height: 16),
                      Text(
                        'Loading borrowing history...',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
              : Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRequestsList(_allRequests, showReturnButton: false),
                    _buildRequestsList(_currentBorrows, showReturnButton: false),
                    _buildRequestsList(_returnedItems, showReturnButton: false, showDeleteButton: true),
                    _buildRequestsList(_rejectedItems, showReturnButton: false),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildRequestsList(
    List<Map<String, dynamic>> requests, {
    bool showReturnButton = false,
    bool showDeleteButton = false,
  }) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                showReturnButton ? Icons.inventory_2_outlined : Icons.history,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              showReturnButton
                  ? 'No current borrowings'
                  : 'No borrowing history',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              showReturnButton
                  ? 'Your current borrowings will appear here'
                  : 'Your borrowing history will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return _buildRequestCard(request, showReturnButton: showReturnButton, showDeleteButton: showDeleteButton);
      },
    );
  }

  Widget _buildRequestCard(
    Map<String, dynamic> request, {
    bool showReturnButton = false,
    bool showDeleteButton = false,
  }) {
    final requestDate =
        DateFormat('MMM dd, yyyy - hh:mm a').format(
            DateTime.parse(request['requestedAt']),
        );

    final status = request['status']?.toString() ?? 'pending';
    final returnedAt = request['returnedAt']?.toString();
    
    // Check if this item is in the RETURNED tab and force status to "Returned"
    final isInReturnedTab = _returnedItems.contains(request);
    final displayStatus = isInReturnedTab ? 'returned' : status;
    
    debugPrint('🎨 Building card for: ${request['itemName']}');
    debugPrint('   Original status: $status');
    debugPrint('   Is in returned tab: $isInReturnedTab');
    debugPrint('   Display status: $displayStatus');

    final dateToBeUsed =
        request['dateToBeUsed'] != null
            ? DateFormat(
              'MMM dd, yyyy',
            ).format(DateTime.parse(request['dateToBeUsed']))
            : 'Not specified';

    final dateToReturn =
        request['dateToReturn'] != null
            ? DateFormat(
              'MMM dd, yyyy',
            ).format(DateTime.parse(request['dateToReturn']))
            : 'Not specified';

    final returnedDate =
        request['returnedAt'] != null
            ? DateFormat(
              'MMM dd, yyyy - hh:mm a',
            ).format(DateTime.parse(request['returnedAt']))
            : null;

    final itemName = request['itemName'] ?? 'Unknown Item';
    final categoryName = request['categoryName'] ?? 'Unknown Category';
    final laboratory = request['laboratory'] ?? 'Not specified';
    final quantity = request['quantity']?.toString() ?? '1';
    final itemNo = request['itemNo'] ?? 'Not specified';

    Color statusColor;
    IconData statusIcon;
    String statusText;

    // Use displayStatus instead of original status
    switch (displayStatus) {
      case 'approved':
        statusColor = const Color(0xFF27AE60);
        statusIcon = Icons.check_circle;
        statusText = 'Approved';
        break;
      case 'released':
        statusColor = const Color(0xFF2AA39F);
        statusIcon = Icons.check_circle_outline;
        statusText = 'Released';
        break;
      case 'returned':
        statusColor = const Color(0xFF3498DB);
        statusIcon = Icons.assignment_turned_in;
        statusText = 'Returned';
        break;
      case 'rejected':
        statusColor = const Color(0xFFE74C3C);
        statusIcon = Icons.cancel;
        statusText = 'Rejected';
        break;
      default:
        statusColor = const Color(0xFFF39C12);
        statusIcon = Icons.pending;
        statusText = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Request #${request['id'].toString().substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFEAEAEA)),
            const SizedBox(height: 12),

            // Due Date Warning (only for active borrows)
            if (showReturnButton && (status == 'approved' || status == 'released')) ...[
              _buildDueDateWarning(request['dateToReturn']),
              const SizedBox(height: 12),
            ],

            // Info
            _infoText('Item', itemName),
            _infoText('Item No.', itemNo),
            _infoText('Category', categoryName),
            _infoText('Laboratory', laboratory),
            _infoText('Quantity', quantity),
            _infoText('Usage Period', '$dateToBeUsed → $dateToReturn'),
            _infoText('Requested At', requestDate),
            if (returnedDate != null) _infoText('Returned At', returnedDate),

            if (showReturnButton &&
                (status == 'approved' || status == 'released')) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _markAsReturned(request['id']),
                  icon: const Icon(Icons.assignment_turned_in, size: 18),
                  label: const Text('Mark as Returned'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3498DB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],

            if (showDeleteButton) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _deleteRequest(request['id'], request['itemName']),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE74C3C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDueDateWarning(String? dateToReturn) {
    if (dateToReturn == null) return const SizedBox.shrink();

    final dueDateStatus = DueDateReminderService.getDueDateStatus(dateToReturn);
    final daysUntilDue = DueDateReminderService.getDaysUntilDue(dateToReturn);

    if (dueDateStatus == null) return const SizedBox.shrink();

    Color warningColor;
    IconData warningIcon;
    String warningText;

    switch (dueDateStatus) {
      case 'overdue':
        warningColor = const Color(0xFFE74C3C);
        warningIcon = Icons.warning;
        warningText = daysUntilDue != null
            ? 'OVERDUE: ${-daysUntilDue} day${-daysUntilDue == 1 ? '' : 's'} overdue'
            : 'OVERDUE: Please return immediately';
        break;
      case 'due_today':
        warningColor = const Color(0xFFF39C12);
        warningIcon = Icons.schedule;
        warningText = 'Due today - Please return today';
        break;
      case 'due_soon':
        warningColor = const Color(0xFFF39C12);
        warningIcon = Icons.access_time;
        warningText = daysUntilDue != null
            ? 'Due in $daysUntilDue day${daysUntilDue == 1 ? '' : 's'}'
            : 'Due soon';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: warningColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(warningIcon, color: warningColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              warningText,
              style: TextStyle(
                color: warningColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
