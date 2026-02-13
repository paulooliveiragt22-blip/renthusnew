// lib/screens/booking_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:renthus/core/providers/supabase_provider.dart';

class BookingDetailsScreen extends ConsumerStatefulWidget {
  const BookingDetailsScreen({super.key});

  @override
  ConsumerState<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends ConsumerState<BookingDetailsScreen> {
  Map<String, dynamic>? booking;
  bool loading = true;
  String? bookingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFromArgs());
  }

  void _initFromArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && args.containsKey('bookingId')) {
      bookingId = args['bookingId']?.toString();
    } else if (args is String) {
      bookingId = args;
    } else {
      bookingId = null;
    }
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    if (bookingId == null) {
      setState(() {
        booking = null;
        loading = false;
      });
      return;
    }
    setState(() => loading = true);
    try {
      final client = ref.read(supabaseProvider);
      final response = await client
          .from('bookings')
          .select('*, services_catalog(name), disputes(status)')
          .eq('id', bookingId)
          .maybeSingle();

      // response may be Map or null depending on lib version
      if (response == null) {
        setState(() {
          booking = null;
          loading = false;
        });
        return;
      }

      if (response is Map<String, dynamic>) {
        setState(() {
          booking = Map<String, dynamic>.from(response);
          loading = false;
        });
        return;
      }

      // fallback: try to convert if returned inner data
      try {
        final data = (response as dynamic).data;
        if (data != null && data is Map<String, dynamic>) {
          setState(() {
            booking = Map<String, dynamic>.from(data);
            loading = false;
          });
          return;
        }
      } catch (_) {}

      setState(() {
        booking = null;
        loading = false;
      });
    } catch (e, st) {
      debugPrint('Exception loading booking: $e\n$st');
      setState(() {
        booking = null;
        loading = false;
      });
    }
  }

  bool get canOpenDispute {
    if (booking == null) return false;
    if (booking!['status'] != 'paid' && booking!['status'] != 'completed') return false;
    final deadlineRaw = booking!['dispute_deadline'];
    if (deadlineRaw == null) return false;
    final deadline = DateTime.tryParse(deadlineRaw.toString());
    if (deadline == null) return false;
    return DateTime.now().isBefore(deadline);
  }

  int get hoursRemaining {
    if (booking == null) return 0;
    final deadlineRaw = booking!['dispute_deadline'];
    if (deadlineRaw == null) return 0;
    final deadline = DateTime.tryParse(deadlineRaw.toString());
    if (deadline == null) return 0;
    return deadline.difference(DateTime.now()).inHours;
  }

  Future<void> _openDispute() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abrir Reclamação'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Descreva o problema'),
          onSubmitted: (value) => Navigator.pop(ctx, value),
        ),
      ),
    );

    if (reason != null && reason.trim().isNotEmpty) {
      try {
        final client = ref.read(supabaseProvider);
        await client.from('disputes').insert({
          'booking_id': bookingId,
          'opened_by': client.auth.currentUser?.id,
          'reason': reason,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reclamação enviada.')));
        }
        _loadBooking();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao abrir reclamação: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (booking == null) return const Scaffold(body: Center(child: Text('Serviço não encontrado.')));

    final serviceName = (booking!['services_catalog'] is Map) ? booking!['services_catalog']['name'] : booking!['services_catalog']?.toString() ?? 'Serviço';
    final deadlineRaw = booking!['dispute_deadline']?.toString();
    final formattedDeadline = deadlineRaw != null && DateTime.tryParse(deadlineRaw) != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(deadlineRaw))
        : '—';

    return Scaffold(
      appBar: AppBar(title: Text(serviceName)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prazo para reclamação até: $formattedDeadline', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(
              canOpenDispute
                  ? 'Você ainda tem ${hoursRemaining}h para abrir uma reclamação.'
                  : 'Prazo encerrado. Pagamento será liberado ao prestador.',
              style: TextStyle(
                color: canOpenDispute ? Colors.orange : Colors.grey,
              ),
            ),
            const Spacer(),
            if (canOpenDispute)
              ElevatedButton.icon(
                onPressed: _openDispute,
                icon: const Icon(Icons.report_problem),
                label: const Text('Abrir Reclamação'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
