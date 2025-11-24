import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AnnouncementCard extends StatefulWidget {
  const AnnouncementCard({super.key});

  @override
  State<AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<AnnouncementCard> {
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoadingAnnouncements = true;
  final int _maxDisplayAnnouncements = 2; // Reduced to 2 to save vertical space

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    try {
      final databaseRef = FirebaseDatabase.instance.ref();
      final snapshot = await databaseRef.child('announcements').get();

      if (snapshot.exists && mounted) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> announcements = [];

        data.forEach((key, value) {
          if (value is Map) {
            announcements.add({
              'id': key,
              'title': value['title'] ?? '',
              'content': value['content'] ?? '',
              'author': value['author'] ?? '',
              'category': value['category'] ?? '',
              'createdAt': value['createdAt'] ?? '',
              'updatedAt': value['updatedAt'] ?? '',
            });
          }
        });

        // Sort by createdAt (newest first)
        announcements.sort((a, b) {
          try {
            final dateA = DateTime.parse(a['createdAt'] as String);
            final dateB = DateTime.parse(b['createdAt'] as String);
            return dateB.compareTo(dateA);
          } catch (e) {
            return 0;
          }
        });

        setState(() {
          // Show only the most recent announcements
          _announcements =
              announcements.take(_maxDisplayAnnouncements).toList();
          _isLoadingAnnouncements = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoadingAnnouncements = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading announcements: $e');
      if (mounted) {
        setState(() {
          _isLoadingAnnouncements = false;
        });
      }
    }
  }

  String _formatTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

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

  // Get color based on category
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'urgent':
        return Colors.red;
      case 'important':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      case 'update':
        return Colors.purple;
      default:
        return const Color(0xFF2AA39F); // Default app color
    }
  }

  void _showAnnouncementDetail(Map<String, dynamic> announcement) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            announcement['title'] as String,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (announcement['category'].toString().isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(
                        announcement['category'] as String,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      announcement['category'] as String,
                      style: TextStyle(
                        color: _getCategoryColor(
                          announcement['category'] as String,
                        ),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  announcement['content'] as String,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Text(
                  'By ${announcement['author']} • ${_formatTime(announcement['createdAt'] as String)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showAllAnnouncements() async {
    // Load all announcements for the full view
    try {
      final databaseRef = FirebaseDatabase.instance.ref();
      final snapshot = await databaseRef.child('announcements').get();

      List<Map<String, dynamic>> allAnnouncements = [];

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        data.forEach((key, value) {
          if (value is Map) {
            allAnnouncements.add({
              'id': key,
              'title': value['title'] ?? '',
              'content': value['content'] ?? '',
              'author': value['author'] ?? '',
              'category': value['category'] ?? '',
              'createdAt': value['createdAt'] ?? '',
              'updatedAt': value['updatedAt'] ?? '',
            });
          }
        });

        // Sort by createdAt (newest first)
        allAnnouncements.sort((a, b) {
          try {
            final dateA = DateTime.parse(a['createdAt'] as String);
            final dateB = DateTime.parse(b['createdAt'] as String);
            return dateB.compareTo(dateA);
          } catch (e) {
            return 0;
          }
        });
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.8,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'All Announcements',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child:
                          allAnnouncements.isEmpty
                              ? const Center(
                                child: Text('No announcements available'),
                              )
                              : ListView.separated(
                                itemCount: allAnnouncements.length,
                                separatorBuilder:
                                    (context, index) => const Divider(),
                                itemBuilder: (context, index) {
                                  final announcement = allAnnouncements[index];
                                  final String category =
                                      announcement['category'] as String;

                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _getCategoryColor(
                                        category,
                                      ).withValues(alpha: 0.1),
                                      child: Icon(
                                        Icons.announcement,
                                        color: _getCategoryColor(category),
                                      ),
                                    ),
                                    title: Text(
                                      announcement['title'] as String,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          announcement['content'] as String,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${announcement['author']} • ${_formatTime(announcement['createdAt'] as String)}',
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      _showAnnouncementDetail(announcement);
                                    },
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      debugPrint('Error loading all announcements: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with "View All" button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.campaign, size: 18, color: Color(0xFF2AA39F)),
                SizedBox(width: 6),
                Text(
                  'Announcements',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (_announcements.isNotEmpty)
              TextButton.icon(
                onPressed: _showAllAnnouncements,
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('View All'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2AA39F),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8), // Reduced spacing
        // Announcements content - now much more compact
        _isLoadingAnnouncements
            ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
            : _announcements.isEmpty
            ? Container(
              height: 80, // Reduced empty state height
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.campaign_outlined, color: Colors.grey),
                    SizedBox(height: 4),
                    Text(
                      'No announcements yet',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
            : Column(
              children:
                  _announcements.map((announcement) {
                    final String category = announcement['category'] as String;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade100,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: InkWell(
                        onTap: () => _showAnnouncementDetail(announcement),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left indicator with category color
                              Container(
                                width: 4,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(category),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Content section
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title and time row
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            announcement['title'] as String,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          _formatTime(
                                            announcement['createdAt'] as String,
                                          ),
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Preview of content
                                    Text(
                                      announcement['content'] as String,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                      maxLines:
                                          1, // Only show one line to save space
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
      ],
    );
  }
}
