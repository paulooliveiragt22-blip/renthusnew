/// Resultado consolidado de jobs do cliente (v_client_my_jobs_dashboard)
class ClientMyJobsResult {
  final List<Map<String, dynamic>> requestedItems;
  final List<Map<String, dynamic>> inProgressItems;
  final List<Map<String, dynamic>> completedItems;
  final List<Map<String, dynamic>> cancelledItems;
  final List<Map<String, dynamic>> disputeItems;
  final int countRequested;
  final int countInProgress;
  final int countCompleted;
  final int countCancelled;
  final int countDisputes;

  const ClientMyJobsResult({
    required this.requestedItems,
    required this.inProgressItems,
    required this.completedItems,
    required this.cancelledItems,
    required this.disputeItems,
    required this.countRequested,
    required this.countInProgress,
    required this.countCompleted,
    required this.countCancelled,
    required this.countDisputes,
  });
}
