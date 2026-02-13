import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:renthus/core/providers/supabase_provider.dart';

class ServiceRequestScreen extends ConsumerStatefulWidget {
  final String serviceType;

  const ServiceRequestScreen({super.key, required this.serviceType});

  @override
  ConsumerState<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends ConsumerState<ServiceRequestScreen> {
  final descricaoController = TextEditingController();
  final enderecoController = TextEditingController();
  DateTime? selectedDate;
  bool loading = false;

  Future<void> criarBooking() async {
    if (selectedDate == null ||
        descricaoController.text.isEmpty ||
        enderecoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha todos os campos.")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final supabase = ref.read(supabaseProvider);
      final userId = supabase.auth.currentUser!.id;

      await supabase.from('bookings').insert({
        'user_id': userId,
        'service_type': widget.serviceType,
        'descricao': descricaoController.text,
        'endereco': enderecoController.text,
        'data': selectedDate!.toIso8601String(),
        'status': 'pendente',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pedido enviado com sucesso!")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro: $e")),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pedido: ${widget.serviceType}"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: descricaoController,
              decoration: const InputDecoration(
                labelText: "Descri??o do servi?o",
              ),
            ),
            TextField(
              controller: enderecoController,
              decoration: const InputDecoration(
                labelText: "Endere?o",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                  initialDate: DateTime.now(),
                );

                if (date != null) {
                  setState(() => selectedDate = date);
                }
              },
              child: Text(selectedDate == null
                  ? "Selecionar Data"
                  : "Data: ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : criarBooking,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text("Enviar pedido"),
            )
          ],
        ),
      ),
    );
  }
}
