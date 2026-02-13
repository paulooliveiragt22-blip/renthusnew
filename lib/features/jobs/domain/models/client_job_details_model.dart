/// Resultado consolidado dos detalhes do job para o cliente
class ClientJobDetailsResult {
  final Map<String, dynamic> job;
  final List<Map<String, dynamic>> candidates;
  final bool hasOpenDispute;
  final bool hasAnyDispute;
  final bool hasPaid;
  final Map<String, dynamic>? payment;

  const ClientJobDetailsResult({
    required this.job,
    required this.candidates,
    required this.hasOpenDispute,
    required this.hasAnyDispute,
    required this.hasPaid,
    this.payment,
  });
}
