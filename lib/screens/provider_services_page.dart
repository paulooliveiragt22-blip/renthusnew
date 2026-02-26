import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:renthus/core/router/app_router.dart';
import 'package:renthus/core/utils/error_handler.dart';
import 'package:renthus/features/jobs/data/providers/job_providers.dart';

const kRoxo = Color(0xFF3B246B);

class ProviderServicesPage extends ConsumerWidget {
  const ProviderServicesPage({
    super.key,
    this.providerId,
  });
  final String? providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(providerServiceNamesProvider(providerId));

    Future<void> _openServiceSelection() async {
      await context.pushProviderServiceSelection();
      ref.invalidate(providerServiceNamesProvider(providerId));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        title: const Text('Minhas categorias e serviços'),
        backgroundColor: kRoxo,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(providerServiceNamesProvider(providerId));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.build_circle_outlined,
                          color: kRoxo,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Serviços atendidos',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _openServiceSelection,
                          child: const Text('Editar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    servicesAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(
                          child: SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 6),
                        child: Column(
                          children: [
                            Text(ErrorHandler.friendlyErrorMessage(e),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.red)),
                            TextButton(
                              onPressed: () => ref.invalidate(
                                  providerServiceNamesProvider(providerId)),
                              child: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      ),
                      data: (serviceNames) {
                        if (serviceNames.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 4, bottom: 6),
                            child: Text(
                              'Você ainda não selecionou serviços. '
                              'Toque em "Editar" para configurar.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: serviceNames
                              .map(
                                (name) => Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.check_circle,
                                          size: 14, color: kRoxo),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
