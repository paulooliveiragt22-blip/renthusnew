import 'package:flutter/material.dart';

enum ProviderJobGroup {
  active,
  waitingClient,
  history,
}

enum ProviderSummaryFilter {
  all,
  newApproved,
  inProgress,
  completed,
  dispute,
  cancelled,
}

class JobCardData {

  const JobCardData({
    required this.jobId,
    required this.jobCode,
    required this.description,
    required this.priceLabel,
    required this.rawStatus,
    required this.statusLabel,
    required this.statusColor,
    required this.dateLabel,
    required this.sortDate,
    required this.group,
    this.unreadMessages = 0,
    required this.openAsDispute,
  });
  final String jobId;
  final String jobCode;
  final String description;
  final String priceLabel;
  final String rawStatus;
  final String statusLabel;
  final Color statusColor;
  final String dateLabel;
  final DateTime sortDate;
  final int unreadMessages;
  final ProviderJobGroup group;
  final bool openAsDispute;
}

class ProviderMyJobsResult {

  const ProviderMyJobsResult({
    required this.allItems,
    required this.newServicesItems,
    required this.inProgressItems,
    required this.completedItems,
    required this.disputeItems,
    required this.cancelledItems,
    required this.countNewServices,
    required this.countInProgress,
    required this.countCompleted,
    required this.countDisputes,
    required this.countCancelled,
  });
  final List<JobCardData> allItems;
  final List<JobCardData> newServicesItems;
  final List<JobCardData> inProgressItems;
  final List<JobCardData> completedItems;
  final List<JobCardData> disputeItems;
  final List<JobCardData> cancelledItems;
  final int countNewServices;
  final int countInProgress;
  final int countCompleted;
  final int countDisputes;
  final int countCancelled;
}
