import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum BadgeSection { chat, jobs, account }

const _chatTypes = {'chat_message', 'new_message'};

const _jobTypes = {
  'job_status',
  'new_candidate',
  'new_quote',
  'quote_accepted',
  'quote_rejected',
  'job_started',
  'new_job',
  'job_accepted',
  'job_completed',
  'job_cancelled',
  'payment_received',
  'payment_confirmed',
  'payment_failed',
  'review_received',
  'review',
  'dispute_opened',
  'dispute_resolved',
};

const _accountTypes = {
  'verification_approved',
  'verification_rejected',
};

class NotificationBadgeController extends ChangeNotifier {
  NotificationBadgeController._();
  static final NotificationBadgeController instance =
      NotificationBadgeController._();

  int _chatCount = 0;
  int _jobsCount = 0;
  int _accountCount = 0;

  bool get chat => _chatCount > 0;
  bool get jobs => _jobsCount > 0;
  bool get account => _accountCount > 0;

  int get chatCount => _chatCount;
  int get jobsCount => _jobsCount;
  int get accountCount => _accountCount;
  int get totalCount => _chatCount + _jobsCount + _accountCount;

  bool hasBadge(BadgeSection section) {
    switch (section) {
      case BadgeSection.chat:
        return chat;
      case BadgeSection.jobs:
        return jobs;
      case BadgeSection.account:
        return account;
    }
  }

  int countFor(BadgeSection section) {
    switch (section) {
      case BadgeSection.chat:
        return _chatCount;
      case BadgeSection.jobs:
        return _jobsCount;
      case BadgeSection.account:
        return _accountCount;
    }
  }

  Future<void> loadFromDatabase() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final rows = await Supabase.instance.client
          .from('notifications')
          .select('type')
          .eq('user_id', user.id)
          .eq('read', false);

      int newChat = 0;
      int newJobs = 0;
      int newAccount = 0;

      for (final row in rows as List) {
        final t = row['type'] as String?;
        if (t == null) continue;
        if (_chatTypes.contains(t)) {
          newChat++;
        } else if (_jobTypes.contains(t)) {
          newJobs++;
        } else if (_accountTypes.contains(t)) {
          newAccount++;
        }
      }

      bool changed = false;
      if (newChat != _chatCount) {
        _chatCount = newChat;
        changed = true;
      }
      if (newJobs != _jobsCount) {
        _jobsCount = newJobs;
        changed = true;
      }
      if (newAccount != _accountCount) {
        _accountCount = newAccount;
        changed = true;
      }
      if (changed) {
        debugPrint('Badges DB: chat=$_chatCount, jobs=$_jobsCount, '
            'account=$_accountCount');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Erro ao carregar badges do DB: $e');
    }
  }

  void showBadgeForType(String? type) {
    if (type == null) return;
    bool changed = false;
    if (_chatTypes.contains(type)) {
      _chatCount++;
      changed = true;
    } else if (_jobTypes.contains(type)) {
      _jobsCount++;
      changed = true;
    } else if (_accountTypes.contains(type)) {
      _accountCount++;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void clearBadge(BadgeSection section) {
    Set<String> typesToMark = {};

    switch (section) {
      case BadgeSection.chat:
        if (_chatCount == 0) return;
        _chatCount = 0;
        typesToMark = _chatTypes;
        break;
      case BadgeSection.jobs:
        if (_jobsCount == 0) return;
        _jobsCount = 0;
        typesToMark = _jobTypes;
        break;
      case BadgeSection.account:
        if (_accountCount == 0) return;
        _accountCount = 0;
        typesToMark = _accountTypes;
        break;
    }

    notifyListeners();
    if (typesToMark.isNotEmpty) {
      _markReadInDb(typesToMark);
    }
  }

  Future<void> _markReadInDb(Set<String> types) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client
          .from('notifications')
          .update({'read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('user_id', user.id)
          .eq('read', false)
          .inFilter('type', types.toList());
    } catch (e) {
      debugPrint('Erro ao marcar notificações como lidas: $e');
    }
  }

  void clearAll() {
    if (_chatCount == 0 && _jobsCount == 0 && _accountCount == 0) return;
    _chatCount = 0;
    _jobsCount = 0;
    _accountCount = 0;
    notifyListeners();
  }
}

final notificationBadgeControllerProvider =
    ChangeNotifierProvider<NotificationBadgeController>(
  (ref) => NotificationBadgeController.instance,
);
