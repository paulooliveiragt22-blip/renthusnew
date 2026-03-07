/// Calculadora de valores de pagamento — Renthus
///
/// Taxas reais (Pagar.me + antecipação automática ativa + Renthus):
///   platformFee      = 15%     (comissão Renthus)
///   pixRate          = 1,09%   (Pagar.me PIX)
///   creditCashRate   = 7,00%   (3,89% MDR + 3,11% antecipação, crédito 1x)
///   creditInstRate   = 7,90%   (4,79% MDR + 3,11% antecipação, crédito 2x-6x)
///
/// Fórmula:
///   clientTotal = (providerAmount * (1 + platformFee)) / (1 - gatewayRate)
///
/// O gateway desconta a taxa sobre o valor TOTAL recebido, por isso a taxa
/// fica no denominador, e não multiplicada no numerador.

class PaymentCalculator {
  PaymentCalculator._();

  // ── Constantes ────────────────────────────────────────────────────────────

  static const double platformFee = 0.15;
  static const double pixRate = 0.0109;
  static const double creditCashRate = 0.0700;
  static const double creditInstRate = 0.0790;
  static const double minInstallmentValue = 50.0;
  static const int maxInstallments = 6;

  // ── API pública ───────────────────────────────────────────────────────────

  /// Valor total que o cliente paga dado [providerAmount] e [gatewayRate].
  static double clientTotal(double providerAmount, double gatewayRate) {
    return (providerAmount * (1.0 + platformFee)) / (1.0 - gatewayRate);
  }

  /// Número máximo de parcelas disponíveis para [providerAmount].
  ///
  /// Retorna de 1 a [maxInstallments]. Uma parcela é disponível se
  /// (creditInstTotal / n) >= [minInstallmentValue].
  static int maxAvailableInstallments(double providerAmount) {
    final instTotal = clientTotal(providerAmount, creditInstRate);
    for (int n = maxInstallments; n >= 2; n--) {
      if (instTotal / n >= minInstallmentValue) return n;
    }
    return 1;
  }

  /// Retorna o resumo completo de pagamento para [providerAmount].
  static PaymentSummary getSummary(double providerAmount) {
    final platformFeeAmount = providerAmount * platformFee;
    final pixTotal = clientTotal(providerAmount, pixRate);
    final creditCashTotal = clientTotal(providerAmount, creditCashRate);
    final creditInstTotal = clientTotal(providerAmount, creditInstRate);

    final installments = List.generate(maxInstallments, (i) {
      final n = i + 1;

      // 1x: usa creditCashTotal (antecipação menor = taxa menor)
      if (n == 1) {
        return InstallmentOption(
          number: 1,
          installmentValue: creditCashTotal,
          total: creditCashTotal,
          available: true,
        );
      }

      // 2x-6x: usa creditInstTotal (taxa de parcelamento maior)
      final installmentValue = creditInstTotal / n;
      return InstallmentOption(
        number: n,
        installmentValue: installmentValue,
        total: creditInstTotal,
        available: installmentValue >= minInstallmentValue,
      );
    });

    return PaymentSummary(
      providerAmount: providerAmount,
      platformFeeAmount: platformFeeAmount,
      pixTotal: pixTotal,
      creditCashTotal: creditCashTotal,
      creditInstTotal: creditInstTotal,
      installments: installments,
    );
  }
}

// ── Modelos ───────────────────────────────────────────────────────────────

class PaymentSummary {
  const PaymentSummary({
    required this.providerAmount,
    required this.platformFeeAmount,
    required this.pixTotal,
    required this.creditCashTotal,
    required this.creditInstTotal,
    required this.installments,
  });

  final double providerAmount;
  final double platformFeeAmount;
  final double pixTotal;
  final double creditCashTotal;

  /// Total no crédito parcelado (mesmo valor base para todas as parcelas 2x-6x).
  final double creditInstTotal;

  /// Lista de 6 opções: [0] = 1x, [1] = 2x, ... [5] = 6x.
  final List<InstallmentOption> installments;
}

class InstallmentOption {
  const InstallmentOption({
    required this.number,
    required this.installmentValue,
    required this.total,
    required this.available,
  });

  /// Número da parcela (1 a 6).
  final int number;

  /// Valor de cada parcela.
  final double installmentValue;

  /// Total pago pelo cliente.
  final double total;

  /// false se (total / number) < R$ 50,00.
  final bool available;
}
