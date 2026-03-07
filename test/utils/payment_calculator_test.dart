import 'package:flutter_test/flutter_test.dart';
import 'package:renthus/utils/payment_calculator.dart';

void main() {
  // ── clientTotal ───────────────────────────────────────────────────────────

  group('clientTotal', () {
    test('PIX: (100 * 1.15) / (1 - 0.0109)', () {
      expect(
        PaymentCalculator.clientTotal(100.0, PaymentCalculator.pixRate),
        closeTo(116.27, 0.02),
      );
    });

    test('Crédito 1x: (100 * 1.15) / (1 - 0.07)', () {
      expect(
        PaymentCalculator.clientTotal(100.0, PaymentCalculator.creditCashRate),
        closeTo(123.66, 0.02),
      );
    });

    test('Crédito parcelado: (100 * 1.15) / (1 - 0.079)', () {
      expect(
        PaymentCalculator.clientTotal(100.0, PaymentCalculator.creditInstRate),
        closeTo(124.86, 0.02),
      );
    });

    test('Proporcional: clientTotal(300) == 3 × clientTotal(100)', () {
      final r100 = PaymentCalculator.clientTotal(100.0, PaymentCalculator.creditInstRate);
      final r300 = PaymentCalculator.clientTotal(300.0, PaymentCalculator.creditInstRate);
      expect(r300, closeTo(r100 * 3, 0.01));
    });
  });

  // ── getSummary — providerAmount = 100 ─────────────────────────────────────

  group('getSummary(100.0)', () {
    late PaymentSummary s;
    setUpAll(() => s = PaymentCalculator.getSummary(100.0));

    test('providerAmount = 100.00', () => expect(s.providerAmount, 100.0));

    test('platformFeeAmount = 15.00', () {
      expect(s.platformFeeAmount, closeTo(15.00, 0.01));
    });

    test('pixTotal ≈ 116.27', () {
      expect(s.pixTotal, closeTo(116.27, 0.02));
    });

    test('creditCashTotal ≈ 123.66', () {
      expect(s.creditCashTotal, closeTo(123.66, 0.02));
    });

    test('creditInstTotal ≈ 124.86', () {
      expect(s.creditInstTotal, closeTo(124.86, 0.02));
    });

    test('installments tem 6 opções', () {
      expect(s.installments.length, 6);
    });

    test('1x: usa creditCashTotal, available=true', () {
      final opt = s.installments[0];
      expect(opt.number, 1);
      expect(opt.total, closeTo(123.66, 0.02));
      expect(opt.installmentValue, closeTo(123.66, 0.02));
      expect(opt.available, isTrue);
    });

    test(r'2x: installmentValue ≈ 62.43, available=true (>= R$50)', () {
      final opt = s.installments[1];
      expect(opt.number, 2);
      expect(opt.total, closeTo(124.86, 0.02));
      expect(opt.installmentValue, closeTo(62.43, 0.02));
      expect(opt.available, isTrue);
    });

    test(r'3x: installmentValue ≈ 41.62, available=false (< R$50)', () {
      final opt = s.installments[2];
      expect(opt.number, 3);
      expect(opt.installmentValue, closeTo(41.62, 0.02));
      expect(opt.available, isFalse);
    });

    test('4x: available=false', () => expect(s.installments[3].available, isFalse));
    test('5x: available=false', () => expect(s.installments[4].available, isFalse));
    test('6x: available=false', () => expect(s.installments[5].available, isFalse));
  });

  // ── maxAvailableInstallments ──────────────────────────────────────────────

  group('maxAvailableInstallments', () {
    test(r'100.0 → 2 (só 1x e 2x >= R$50)', () {
      expect(PaymentCalculator.maxAvailableInstallments(100.0), 2);
    });

    test(r'300.0 → 6 (todas as parcelas >= R$50)', () {
      expect(PaymentCalculator.maxAvailableInstallments(300.0), 6);
    });

    test(r'50.0 → 1 (instTotal/2 < R$50)', () {
      expect(PaymentCalculator.maxAvailableInstallments(50.0), 1);
    });
  });

  // ── getSummary — providerAmount = 300 ─────────────────────────────────────

  group('getSummary(300.0)', () {
    late PaymentSummary s;
    setUpAll(() => s = PaymentCalculator.getSummary(300.0));

    test('creditInstTotal ≈ 374.59', () {
      expect(s.creditInstTotal, closeTo(374.59, 0.02));
    });

    test('2x: installmentValue ≈ 187.30, available=true', () {
      final opt = s.installments[1];
      expect(opt.installmentValue, closeTo(187.30, 0.02));
      expect(opt.available, isTrue);
    });

    test('3x: installmentValue ≈ 124.86, available=true', () {
      final opt = s.installments[2];
      expect(opt.installmentValue, closeTo(124.86, 0.02));
      expect(opt.available, isTrue);
    });

    test('4x: installmentValue ≈ 93.65, available=true', () {
      final opt = s.installments[3];
      expect(opt.installmentValue, closeTo(93.65, 0.02));
      expect(opt.available, isTrue);
    });

    test('5x: installmentValue ≈ 74.92, available=true', () {
      final opt = s.installments[4];
      expect(opt.installmentValue, closeTo(74.92, 0.02));
      expect(opt.available, isTrue);
    });

    test('6x: installmentValue ≈ 62.43, available=true', () {
      final opt = s.installments[5];
      expect(opt.installmentValue, closeTo(62.43, 0.02));
      expect(opt.available, isTrue);
    });
  });
}
