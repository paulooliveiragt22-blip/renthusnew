// lib/screens/client_bookings_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientBookingsScreen extends StatefulWidget {
  const ClientBookingsScreen({super.key});

  @override
  State<ClientBookingsScreen> createState() => _ClientBookingsScreenState();
}

class _ClientBookingsScreenState extends State<ClientBookingsScreen> {
  final _client = Supabase.instance.client;
  List<dynamic> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _loading = true);
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final res = await _client
          .from('bookings')
          .select('id, status, created_at, services_catalog(name), provider:provider_id(name, email)')
          .eq('client_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _bookings = res;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao carregar pedidos: $e')));
      }
      setState(() => _loading = false);
    }
  }

  Widget _bookingTile(Map<String, dynamic> b) {
    final service = b['services_catalog']?['name'] ?? 'Serviço';
    final provider = b['provider']?['name'] ?? 'Prestador não definido';
    final status = b['status'] ?? '—';
    final createdAt = DateTime.tryParse(b['created_at'] ?? '');
    final formattedDate = createdAt != null
        ? '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}'
        : '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Text(service, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prestador: $provider'),
            Text('Status: $status'),
            if (formattedDate.isNotEmpty) Text('Data: $formattedDate'),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: () {
          Navigator.pushNamed(
            context,
            '/booking_details',
            arguments: {'bookingId': b['id']},
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Pedidos'),
        actions: [
          IconButton(
            onPressed: _loadBookings,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bookings.isEmpty
              ? const Center(child: Text('Nenhum pedido encontrado.'))
              : RefreshIndicator(
                  onRefresh: _loadBookings,
                  child: ListView.builder(
                    itemCount: _bookings.length,
                    itemBuilder: (ctx, i) => _bookingTile(_bookings[i]),
                  ),
                ),
    );
  }
}
