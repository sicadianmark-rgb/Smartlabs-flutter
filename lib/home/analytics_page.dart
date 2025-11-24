import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:app/home/service/association_mining_service.dart';
import 'package:app/home/service/dummy_data_service.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool _isLoading = true;
  bool _isInsertingDummyData = false;
  List<Map<String, dynamic>> _popularEquipment = [];
  List<Map<String, dynamic>> _recentActivity = [];
  List<AssociationRule> _associationRules = [];
  int _totalRequests = 0;
  int _approvedRequests = 0;
  int _pendingRequests = 0;
  int _rejectedRequests = 0;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadRequestStatistics(),
        _loadPopularEquipment(),
        _loadRecentActivity(),
        _loadAssociationRules(),
      ]);

      setState(() => _isLoading = false);
    } catch (e) {
      _showSnackBar('Error loading analytics: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRequestStatistics() async {
    try {
      final snapshot =
          await FirebaseDatabase.instance.ref().child('borrow_requests').get();

      int total = 0;
      int approved = 0;
      int pending = 0;
      int rejected = 0;

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        total = data.length;

        for (var request in data.values) {
          final requestData = request as Map<dynamic, dynamic>;
          final status = requestData['status'] ?? 'pending';

          switch (status) {
            case 'approved':
              approved++;
              break;
            case 'pending':
              pending++;
              break;
            case 'rejected':
              rejected++;
              break;
          }
        }
      }

      setState(() {
        _totalRequests = total;
        _approvedRequests = approved;
        _pendingRequests = pending;
        _rejectedRequests = rejected;
      });
    } catch (e) {
      debugPrint('Error loading request statistics: $e');
    }
  }

  Future<void> _loadPopularEquipment() async {
    try {
      final snapshot =
          await FirebaseDatabase.instance.ref().child('borrow_requests').get();

      Map<String, int> equipmentCount = {};

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        for (var request in data.values) {
          final requestData = request as Map<dynamic, dynamic>;
          final itemName = requestData['itemName'] ?? 'Unknown';
          final status = requestData['status'] ?? 'pending';

          // Only count approved requests for popularity
          if (status == 'approved') {
            equipmentCount[itemName] = (equipmentCount[itemName] ?? 0) + 1;
          }
        }
      }

      // Sort by popularity
      var sortedEquipment =
          equipmentCount.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _popularEquipment =
            sortedEquipment
                .take(10)
                .map((e) => {'name': e.key, 'count': e.value})
                .toList();
      });
    } catch (e) {
      debugPrint('Error loading popular equipment: $e');
    }
  }

  Future<void> _loadRecentActivity() async {
    try {
      final snapshot =
          await FirebaseDatabase.instance
              .ref()
              .child('borrow_requests')
              .orderByChild('requestedAt')
              .limitToLast(10)
              .get();

      List<Map<String, dynamic>> activities = [];

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        for (var request in data.values) {
          final requestData = request as Map<dynamic, dynamic>;
          activities.add({
            'itemName': requestData['itemName'] ?? 'Unknown Item',
            'userEmail': requestData['userEmail'] ?? 'Unknown User',
            'status': requestData['status'] ?? 'pending',
            'requestedAt': requestData['requestedAt'] ?? '',
          });
        }
      }

      // Sort by most recent
      activities.sort((a, b) => b['requestedAt'].compareTo(a['requestedAt']));

      setState(() {
        _recentActivity = activities;
      });
    } catch (e) {
      debugPrint('Error loading recent activity: $e');
    }
  }

  Future<void> _loadAssociationRules() async {
    try {
      final rules = await AssociationMiningService.findAssociationRules(
        minSupport: 0.02,
        minConfidence: 0.3,
        minLift: 1.0,
      );

      setState(() {
        _associationRules = rules.take(10).toList();
      });
    } catch (e) {
      debugPrint('Error loading association rules: $e');
    }
  }

  Future<void> _insertDummyData() async {
    // Confirm before inserting
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insert Test Data'),
        content: const Text(
          'This will create dummy borrow requests to test association rules. '
          'It will create 50 users with 3 requests each (150 total requests).\n\n'
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2AA39F),
            ),
            child: const Text('Insert'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isInsertingDummyData = true;
    });

    try {
      await DummyDataService.insertDummyBorrowRequests(
        numUsers: 50,
        requestsPerUser: 3,
      );

      _showSnackBar(
        'Successfully inserted dummy borrow requests! Refreshing analytics...',
        isError: false,
      );

      // Reload analytics after a short delay
      await Future.delayed(const Duration(seconds: 1));
      await _loadAnalytics();
    } catch (e) {
      _showSnackBar('Error inserting dummy data: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isInsertingDummyData = false;
        });
      }
    }
  }

  Widget _buildDummyDataSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.science, color: Color(0xFF2AA39F), size: 24),
              SizedBox(width: 12),
              Text(
                'Test Data Generator',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Generate dummy borrow request data to test association rule mining. '
            'This creates realistic borrowing patterns with multiple equipment items borrowed together.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      _isInsertingDummyData ? null : _insertDummyData,
                  icon: _isInsertingDummyData
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.auto_fix_high),
                  label: Text(
                    _isInsertingDummyData
                        ? 'Inserting...'
                        : 'Insert Test Data',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2AA39F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
      appBar: AppBar(
        title: const Text(
          'Analytics',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: const Color(0xFF2AA39F),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
          _isLoading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF2AA39F)),
                    SizedBox(height: 16),
                    Text(
                      'Loading analytics...',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildStatisticsCards(),
                    const SizedBox(height: 24),
                    _buildPopularEquipment(),
                    const SizedBox(height: 24),
                    _buildAssociationRules(),
                    const SizedBox(height: 24),
                    _buildRecentActivity(),
                    const SizedBox(height: 24),
                    _buildDummyDataSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: _isInsertingDummyData ? null : _insertDummyData,
              backgroundColor: const Color(0xFF2AA39F),
              icon: _isInsertingDummyData
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.auto_fix_high, color: Colors.white),
              label: Text(
                _isInsertingDummyData
                    ? 'Inserting...'
                    : 'Insert Test Data',
                style: const TextStyle(color: Colors.white),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2AA39F), Color(0xFF52B788)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.analytics, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Analytics Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Equipment usage insights and statistics',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadAnalytics,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh analytics',
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Request Statistics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _buildStatCard(
              'Total Requests',
              _totalRequests.toString(),
              Icons.assignment,
              const Color(0xFF3498DB),
            ),
            _buildStatCard(
              'Approved',
              _approvedRequests.toString(),
              Icons.check_circle,
              const Color(0xFF27AE60),
            ),
            _buildStatCard(
              'Pending',
              _pendingRequests.toString(),
              Icons.pending,
              const Color(0xFFF39C12),
            ),
            _buildStatCard(
              'Rejected',
              _rejectedRequests.toString(),
              Icons.cancel,
              const Color(0xFFE74C3C),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF7F8C8D),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularEquipment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Most Popular Equipment',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child:
              _popularEquipment.isEmpty
                  ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.trending_up, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No data available',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                  : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _popularEquipment.length,
                    itemBuilder: (context, index) {
                      final equipment = _popularEquipment[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(
                            0xFF2AA39F,
                          ).withValues(alpha: 0.1),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Color(0xFF2AA39F),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(
                          equipment['name'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2AA39F,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${equipment['count']}',
                            style: const TextStyle(
                              color: Color(0xFF2AA39F),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child:
              _recentActivity.isEmpty
                  ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.history, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No recent activity',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                  : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recentActivity.length,
                    itemBuilder: (context, index) {
                      final activity = _recentActivity[index];
                      final status = activity['status'] as String;

                      Color statusColor;
                      IconData statusIcon;
                      String statusText;

                      switch (status) {
                        case 'approved':
                          statusColor = const Color(0xFF27AE60);
                          statusIcon = Icons.check_circle;
                          statusText = 'Approved';
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

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withValues(alpha: 0.1),
                          child: Icon(statusIcon, color: statusColor, size: 18),
                        ),
                        title: Text(
                          activity['itemName'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${activity['userEmail']} • $statusText',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          _formatTimeAgo(activity['requestedAt']),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildAssociationRules() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Frequently Borrowed Together',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message:
                  'Items that students frequently borrow together, discovered through association rule mining',
              child: Icon(
                Icons.info_outline,
                size: 18,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child:
              _associationRules.isEmpty
                  ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.auto_graph, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No association patterns found',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Need more borrowing data to detect patterns',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                  : Column(
                    children: [
                      // Header row explaining the metrics
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF2AA39F,
                          ).withValues(alpha: 0.05),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              flex: 3,
                              child: Text(
                                'Association Pattern',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Tooltip(
                                message:
                                    'How often these items appear together',
                                child: Text(
                                  'Support',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Tooltip(
                                message:
                                    'Probability of borrowing item B when borrowing item A',
                                child: Text(
                                  'Conf.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Tooltip(
                                message:
                                    'Strength of association (>1 = strong correlation)',
                                child: Text(
                                  'Lift',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _associationRules.length,
                        separatorBuilder:
                            (context, index) =>
                                Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (context, index) {
                          final rule = _associationRules[index];
                          return _buildAssociationRuleItem(rule);
                        },
                      ),
                    ],
                  ),
        ),
      ],
    );
  }

  Widget _buildAssociationRuleItem(AssociationRule rule) {
    // Determine color intensity based on lift
    Color getLiftColor(double lift) {
      if (lift >= 3.0) return const Color(0xFF27AE60); // Strong
      if (lift >= 2.0) return const Color(0xFF52B788); // Moderate
      return const Color(0xFFF39C12); // Weak
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      flex: 1,
                      child: Text(
                        rule.itemA,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: Color(0xFF2AA39F),
                      ),
                    ),
                    Flexible(
                      flex: 1,
                      child: Text(
                        rule.itemB,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Color(0xFF2AA39F),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${rule.coOccurrenceCount} times',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${(rule.support * 100).toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${(rule.confidence * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: getLiftColor(rule.lift).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                rule.lift.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: getLiftColor(rule.lift),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}
