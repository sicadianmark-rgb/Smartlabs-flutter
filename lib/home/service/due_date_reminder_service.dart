// lib/home/service/due_date_reminder_service.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';

class DueDateReminderService {
  static final _database = FirebaseDatabase.instance;
  
  // Philippine timezone is UTC+8
  static const int _philippineTimeOffset = 8;

  /// Get current time in Philippine timezone
  static DateTime _getPhilippineTime() {
    final now = DateTime.now().toUtc();
    return now.add(Duration(hours: _philippineTimeOffset));
  }

  /// Check all active borrows for due date reminders
  /// This should be called when app starts or periodically
  static Future<void> checkAndSendReminders() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get all borrow requests for current user
      final snapshot = await _database
          .ref()
          .child('borrow_requests')
          .orderByChild('userId')
          .equalTo(user.uid)
          .get();

      if (!snapshot.exists) return;

      final data = snapshot.value as Map<dynamic, dynamic>;
      final nowPH = _getPhilippineTime(); // Philippine time

      for (var entry in data.entries) {
        final request = entry.value as Map<dynamic, dynamic>;
        final status = request['status'] as String?;
        final dateToReturn = request['dateToReturn'] as String?;
        final itemName = request['itemName'] as String?;
        final requestId = entry.key as String;

        // Only check active borrows (approved or released, not returned)
        if (status != 'approved' && status != 'released') continue;
        if (request['returnedAt'] != null && request['returnedAt'] != '') continue;
        if (dateToReturn == null || itemName == null) continue;

        try {
          // Parse return date and convert to Philippine time
          final returnDateUTC = DateTime.parse(dateToReturn);
          final returnDatePH = returnDateUTC.add(Duration(hours: _philippineTimeOffset));
          
          // Get start of day for comparison
          final nowStartOfDay = DateTime(nowPH.year, nowPH.month, nowPH.day);
          final returnDateStartOfDay = DateTime(returnDatePH.year, returnDatePH.month, returnDatePH.day);
          final daysUntilDue = returnDateStartOfDay.difference(nowStartOfDay).inDays;

          // Check if overdue (past due date)
          if (daysUntilDue < 0) {
            // Overdue - send reminder once per day
            // Check if it's been at least 1 day since the due date
            await _sendReminder(
              userId: user.uid,
              requestId: requestId,
              itemName: itemName,
              returnDate: returnDatePH,
              reminderType: 'overdue',
              daysUntilDue: daysUntilDue,
            );
          } else if (daysUntilDue == 0) {
            // Due today - send reminder 1 hour before 5 PM (4:00 PM - 4:59 PM Philippine time)
            final reminderTimeStart = DateTime(returnDatePH.year, returnDatePH.month, returnDatePH.day, 16, 0); // 4:00 PM
            final reminderTimeEnd = DateTime(returnDatePH.year, returnDatePH.month, returnDatePH.day, 16, 59); // 4:59 PM
            final labClosingTime = DateTime(returnDatePH.year, returnDatePH.month, returnDatePH.day, 17, 0); // 5:00 PM
            
            // Check if current time is between 4:00 PM and 4:59 PM on the due date
            if (nowPH.isAfter(reminderTimeStart.subtract(const Duration(minutes: 1))) &&
                nowPH.isBefore(reminderTimeEnd.add(const Duration(minutes: 1)))) {
              await _sendReminder(
                userId: user.uid,
                requestId: requestId,
                itemName: itemName,
                returnDate: returnDatePH,
                reminderType: 'due_today',
                daysUntilDue: daysUntilDue,
              );
            }
            // Also send overdue reminder if past 5 PM on due date
            else if (nowPH.isAfter(labClosingTime)) {
              await _sendReminder(
                userId: user.uid,
                requestId: requestId,
                itemName: itemName,
                returnDate: returnDatePH,
                reminderType: 'overdue',
                daysUntilDue: -1, // Technically overdue after closing time
              );
            }
          }
        } catch (e) {
          debugPrint('Error parsing date for reminder: $e');
        }
      }
    } catch (e) {
      debugPrint('Error checking due date reminders: $e');
    }
  }

  /// Send a reminder notification (only if not already sent for this reminder type)
  static Future<void> _sendReminder({
    required String userId,
    required String requestId,
    required String itemName,
    required DateTime returnDate,
    required String reminderType,
    required int daysUntilDue,
  }) async {
    try {
      final nowPH = _getPhilippineTime();
      String reminderKey;
      
      // Create reminder key based on type
      // For due_today: use date only (send once on the due date during 4 PM window)
      // For overdue: use date only (send once per day)
      reminderKey = 'reminder_${requestId}_${reminderType}_${DateFormat('yyyy-MM-dd').format(nowPH)}';
      
      final reminderCheck = await _database
          .ref()
          .child('reminders_sent')
          .child(userId)
          .child(reminderKey)
          .get();

      if (reminderCheck.exists) {
        // Already sent for this reminder type, skip
        return;
      }

      // Format due date
      final dueDateFormatted = DateFormat('MMM dd, yyyy').format(returnDate);

      // Send notification (NotificationService will format the message)
      await NotificationService.sendReminderNotification(
        userId: userId,
        itemName: itemName,
        dueDate: dueDateFormatted,
        reminderType: reminderType,
      );

      // Mark reminder as sent
      await _database
          .ref()
          .child('reminders_sent')
          .child(userId)
          .child(reminderKey)
          .set({
            'requestId': requestId,
            'itemName': itemName,
            'reminderType': reminderType,
            'sentAt': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      debugPrint('Error sending reminder: $e');
    }
  }

  /// Get due date status for a request
  /// Returns: 'overdue', 'due_today', 'due_soon', or null
  static String? getDueDateStatus(String? dateToReturn) {
    if (dateToReturn == null) return null;

    try {
      final returnDate = DateTime.parse(dateToReturn);
      final now = DateTime.now();
      final daysUntilDue = returnDate.difference(now).inDays;

      if (daysUntilDue < 0) {
        return 'overdue';
      } else if (daysUntilDue == 0) {
        return 'due_today';
      } else if (daysUntilDue <= 3) {
        return 'due_soon';
      }
      return null;
    } catch (e) {
      debugPrint('Error parsing due date: $e');
      return null;
    }
  }

  /// Get days until due date
  static int? getDaysUntilDue(String? dateToReturn) {
    if (dateToReturn == null) return null;

    try {
      final returnDate = DateTime.parse(dateToReturn);
      final now = DateTime.now();
      return returnDate.difference(now).inDays;
    } catch (e) {
      debugPrint('Error calculating days until due: $e');
      return null;
    }
  }
}

