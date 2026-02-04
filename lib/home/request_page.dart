import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'service/notification_service.dart';
import 'service/borrow_history_service.dart';

class RequestPage extends StatefulWidget {
  const RequestPage({super.key});

  @override
  State<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allRequests = [];
  List<Map<String, dynamic>> _currentRequests = [];
  List<Map<String, dynamic>> _returnedRequests = [];
  List<Map<String, dynamic>> _rejectedRequests = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAdviserRequestsOnly();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAdviserRequestsOnly() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final snapshot =
          await FirebaseDatabase.instance
              .ref()
              .child('borrow_requests')
              .orderByChild('adviserId')
              .equalTo(user.uid)
              .get();

      List<Map<String, dynamic>> adviserRequests = [];

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        // Get unique user IDs to fetch student names
        final Set<String> userIds = {};
        data.forEach((key, value) {
          final request = value as Map<dynamic, dynamic>;
          final userId = request['userId'];
          if (userId != null) {
            userIds.add(userId.toString());
          }
        });

        // Fetch student names
        final Map<String, String> studentNames = {};
        if (userIds.isNotEmpty) {
          final usersSnapshot =
              await FirebaseDatabase.instance.ref().child('users').get();

          if (usersSnapshot.exists) {
            final usersData = usersSnapshot.value as Map<dynamic, dynamic>;
            for (final userId in userIds) {
              if (usersData.containsKey(userId)) {
                final userData = usersData[userId] as Map<dynamic, dynamic>;
                studentNames[userId] = userData['name'] ?? 'Unknown Student';
              }
            }
          }
        }

        // Build requests list with student names
        data.forEach((key, value) {
          final request = Map<String, dynamic>.from(value);
          request['id'] = key;
          final userId = request['userId'] as String?;
          if (userId != null) {
            request['userName'] = studentNames[userId] ?? 'Unknown Student';
          }
          // Exclude instructor's own requests since they get auto-approved
          if (userId != user.uid) {
            adviserRequests.add(request);
          }
        });

        adviserRequests.sort(
          (a, b) => b['requestedAt'].toString().compareTo(
            a['requestedAt'].toString(),
          ),
        );
      }

      setState(() {
        // CURRENT: Only PENDING requests (approved requests are removed from instructor view)
        _currentRequests =
            adviserRequests
                .where(
                  (r) =>
                    r['status'] == 'pending' &&
                    (r['returnedAt'] == null || r['returnedAt'] == ''),
                )
                .toList();

        // ALL = CURRENT (only pending requests for instructor approval)
        _allRequests = [];
        _allRequests.addAll(_currentRequests);

        // Sort all requests by date (newest first)
        _allRequests.sort(
          (a, b) {
            final aDate = a['requestedAt']?.toString() ?? '';
            final bDate = b['requestedAt']?.toString() ?? '';
            return bDate.compareTo(aDate);
          },
        );

        _isLoading = false;
      });
    } catch (e) {
      _showSnackBar('Error loading requests: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateRequestStatus(
    String requestId,
    String status,
    Map<String, dynamic> request,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Prevent self-approval: Check if the user is trying to approve their own request
      final requestUserId = request['userId'] as String?;

      // Prevent approval if user is the requester (cannot approve own request)
      if (requestUserId == user.uid) {
        if (status == 'approved') {
          _showSnackBar(
            'You cannot approve your own borrow request. Please contact another instructor to approve it.',
            isError: true,
          );
          return;
        }
        // Allow rejection of own request (in case of cancellation)
      }

      final updateData = {
        'status': status,
        'processedAt': DateTime.now().toIso8601String(),
        'processedBy': user.uid,
      };

      final List<Future> updates = [
        FirebaseDatabase.instance
            .ref()
            .child('borrow_requests')
            .child(requestId)
            .update(updateData),
        _updateStudentRequest(requestId, updateData),
      ];

      // FIXED: Do NOT update quantity_borrowed when approving
      // Quantity should only decrease when Lab In Charge clicks "Release" in the web interface
      if (status == 'approved') {
        // Archive to history storage for association rule mining
        // Get full request data including updated status
        final fullRequestData = Map<String, dynamic>.from(request);
        fullRequestData.addAll(updateData);
        updates.add(
          BorrowHistoryService.archiveApprovedRequest(
            requestId,
            fullRequestData,
          ),
        );
      } else if (status == 'returned') {
        // When admin marks as returned, archive to history and update quantity
        final fullRequestData = Map<String, dynamic>.from(request);
        fullRequestData.addAll(updateData);
        fullRequestData['returnedAt'] = DateTime.now().toIso8601String();
        
        updates.add(
          BorrowHistoryService.archiveReturnedRequest(
            requestId,
            fullRequestData,
          ),
        );
        
        // Decrement quantity_borrowed if the request was approved/released
        final requestSnapshot =
            await FirebaseDatabase.instance
                .ref()
                .child('borrow_requests')
                .child(requestId)
                .get();

        if (requestSnapshot.exists) {
          final requestData = requestSnapshot.value as Map<dynamic, dynamic>;
          final previousStatus = requestData['status'] as String?;
          
          if (previousStatus == 'approved' || previousStatus == 'released') {
            updates.add(
              _updateEquipmentQuantityBorrowed(
                request['itemId'],
                request['categoryId'],
                request['quantity'],
                increment: false,
              ),
            );
          }
        }
      } else if (status == 'rejected') {
        // If request was previously approved or released and now rejected, 
        // we need to check if quantity was already decreased
        final requestSnapshot =
            await FirebaseDatabase.instance
                .ref()
                .child('borrow_requests')
                .child(requestId)
                .get();

        if (requestSnapshot.exists) {
          final requestData = requestSnapshot.value as Map<dynamic, dynamic>;
          final previousStatus = requestData['status'] as String?;
          
          // Only decrement if the request was previously released
          // (released is when quantity is actually decreased by Lab In Charge)
          if (previousStatus == 'released') {
            updates.add(
              _updateEquipmentQuantityBorrowed(
                request['itemId'],
                request['categoryId'],
                request['quantity'],
                increment: false,
              ),
            );
          }
        }
      }

      await Future.wait(updates);

      // Send notification to student about status change
      await NotificationService.notifyRequestStatusChange(
        userId: request['userId'],
        itemName: request['itemName'],
        status: status,
        reason:
            status == 'rejected'
                ? 'Please contact your instructor for more details'
                : null,
      );

      _showSnackBar(
        'Request ${status.toUpperCase()} successfully!',
        isError: false,
      );
      _loadAdviserRequestsOnly();
    } catch (e) {
      _showSnackBar('Error updating request: $e', isError: true);
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
      final itemSnapshot =
          await FirebaseDatabase.instance
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

        final newBorrowed =
            increment
                ? currentBorrowed + quantityValue
                : (currentBorrowed - quantityValue)
                    .clamp(0, double.infinity)
                    .toInt();

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
      final snapshot =
          await FirebaseDatabase.instance
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

  Future<void> _updateStudentRequest(
    String requestId,
    Map<String, dynamic> updateData,
  ) async {
    try {
      final requestSnapshot =
          await FirebaseDatabase.instance
              .ref()
              .child('borrow_requests')
              .child(requestId)
              .get();

      if (requestSnapshot.exists) {
        final requestData = requestSnapshot.value as Map<dynamic, dynamic>;
        final studentId = requestData['userId'];

        if (studentId != null) {
          await FirebaseDatabase.instance
              .ref()
              .child('users')
              .child(studentId)
              .child('borrow_requests')
              .child(requestId)
              .update(updateData);
        }
      }
    } catch (e) {
      debugPrint('Error updating student request: $e');
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
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF6C63FF),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF6C63FF),
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
                  'Current (${_currentRequests.length})',
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
              const Icon(
                Icons.assignment_outlined,
                color: Color(0xFF6C63FF),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Borrow Requests',
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
                  icon: const Icon(Icons.refresh, color: Color(0xFF6C63FF)),
                  onPressed: _loadAdviserRequestsOnly,
                  tooltip: 'Refresh requests',
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
                    CircularProgressIndicator(color: Color(0xFF6C63FF)),
                    SizedBox(height: 16),
                    Text(
                      'Loading requests...',
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
                  _buildRequestsList(_allRequests, showActions: false),
                  _buildRequestsList(_currentRequests, showActions: true),
                ],
              ),
            ),
      ],
    );
  }

  Widget _buildRequestsList(
    List<Map<String, dynamic>> requests, {
    bool showActions = false,
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
                showActions
                    ? Icons.pending_actions
                    : Icons.assignment_turned_in,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              showActions ? 'No pending requests' : 'No requests found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              showActions
                  ? 'New borrow requests will appear here'
                  : 'Processed requests will appear here',
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
        return _buildRequestCard(request, showActions: showActions);
      },
    );
  }

  Widget _buildRequestCard(
    Map<String, dynamic> request, {
    bool showActions = false,
  }) {
    final requestDate =
        request['requestedAt'] != null
            ? DateFormat(
              'MMM dd, yyyy - hh:mm a',
            ).format(DateTime.parse(request['requestedAt']))
            : 'Unknown Date';

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

    final status = request['status'] ?? 'pending';
    final studentName =
        request['userName'] ?? request['userEmail'] ?? 'Unknown Student';
    final itemName = request['itemName'] ?? 'Unknown Item';
    final categoryName = request['categoryName'] ?? 'Unknown Category';
    final laboratory = request['laboratory'] ?? 'Not specified';
    final quantity = request['quantity']?.toString() ?? '1';
    final itemNo = request['itemNo'] ?? 'Not specified';

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'approved':
        statusColor = const Color(0xFF27AE60);
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = const Color(0xFFE74C3C);
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = const Color(0xFFF39C12);
        statusIcon = Icons.pending;
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
                        status.toUpperCase(),
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

            // Info
            _infoText('Student', studentName),
            _infoText('Item', itemName),
            _infoText('Item No.', itemNo),
            _infoText('Category', categoryName),
            _infoText('Laboratory', laboratory),
            _infoText('Quantity', quantity),
            _infoText('Usage Period', '$dateToBeUsed → $dateToReturn'),
            _infoText('Requested At', requestDate),

            if (showActions) ...[
              // Check if this is the user's own request (as requester only)
              Builder(
                builder: (context) {
                  final user = FirebaseAuth.instance.currentUser;
                  final requestUserId = request['userId'] as String?;

                  // Treat as own request only when the logged-in user is the requester
                  final isOwnRequest =
                      user != null && requestUserId == user.uid;

                  if (isOwnRequest) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This is your own request. Please contact another instructor to approve it.',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      const SizedBox(height: 20),
                      // Show "Mark as Returned" button for approved/released requests
                      if (request['status'] == 'approved' || request['status'] == 'released') ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                () => _updateRequestStatus(
                                  request['id'],
                                  'returned',
                                  request,
                                ),
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
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  () => _updateRequestStatus(
                                    request['id'],
                                    'rejected',
                                    request,
                                  ),
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFE74C3C),
                                side: const BorderSide(
                                  color: Color(0xFFE74C3C),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  () => _updateRequestStatus(
                                    request['id'],
                                    'approved',
                                    request,
                                  ),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF27AE60),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
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