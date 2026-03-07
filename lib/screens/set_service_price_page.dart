import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SetServicePricePage extends StatefulWidget {
  const SetServicePricePage({super.key});

  @override
  State<SetServicePricePage> createState() => _SetServicePricePageState();
}

class _SetServicePricePageState extends State<SetServicePricePage> {
  final TextEditingController priceController = TextEditingController();
  final TextEditingController receiveController = TextEditingController();

  double paymentPercentFee = 0.008; // 0.80%
  double paymentFixedFee = 1.00; // tarifa fixa Pagar.me
  double platformFeePercent = 0.00; // hoje: 0%

  double valorBruto = 0.0;
  double valorLiquido = 0.0;
  double taxaPercentual = 0.0;
  double taxaFixa = 1.0;

  final formatCurrency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ');

  void calcularValorLiquido() {
    setState(() {
      valorBruto = double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0.0;

      taxaPercentual = valorBruto * paymentPercentFee;
      taxaFixa = paymentFixedFee;

      valorLiquido = valorBruto - taxaPercentual - taxaFixa;
      if (valorLiquido < 0) valorLiquido = 0;
    });
  }

  void calcularValorBrutoPorLiquido() {
    setState(() {
      final double desejado = double.tryParse(receiveController.text.replaceAll(',', '.')) ?? 0.0;

      // valorBruto = desejado + taxaPercentual + taxaFixa
      valorBruto = (desejado + paymentFixedFee) / (1 - paymentPercentFee);
      valorLiquido = desejado;

      priceController.text = valorBruto.toStringAsFixed(2);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Definir valor do servi\u00E7o'),
        backgroundColor: const Color(0xFF3B246B),
      ),
      backgroundColor: const Color(0xFFEDEDED),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quanto deseja cobrar?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor bruto (cliente paga)',
                hintText: 'Ex: 200.00',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => calcularValorLiquido(),
            ),

            const SizedBox(height: 20),

            _buildResumoCalculo(),

            const SizedBox(height: 30),

            const Text(
              'Quero receber l\u00EDquido:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: receiveController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor l\u00EDquido desejado',
                hintText: 'Ex: 200.00',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => calcularValorBrutoPorLiquido(),
            ),

            const Spacer(),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'valor_bruto': valorBruto,
                  'valor_liquido': valorLiquido,
                  'taxa_percentual': taxaPercentual,
                  'taxa_fixa': taxaFixa,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B246B),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Confirmar valor',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumoCalculo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _linhaResumo('Valor do servi\u00E7o', valorBruto),
          _linhaResumo('Taxa PIX (0,80%)', taxaPercentual),
          _linhaResumo('Tarifa fixa Pagar.me', taxaFixa),
          const Divider(),
          _linhaResumo('Voc\u00EA receber\u00E1 l\u00EDquido', valorLiquido, bold: true),
        ],
      ),
    );
  }

  Widget _linhaResumo(String titulo, double valor, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(titulo)),
          Text(
            'R\$ ${valor.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: bold ? const Color(0xFF3B246B) : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
