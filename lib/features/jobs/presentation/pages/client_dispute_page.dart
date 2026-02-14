import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/router/app_router.dart';
import 'package:renthus/features/jobs/data/providers/job_providers.dart';
import 'package:renthus/features/chat/presentation/pages/chat_page.dart';
import 'package:renthus/utils/image_utils.dart';

class ClientDisputePage extends ConsumerStatefulWidget {

  const ClientDisputePage({
    super.key,
    required this.jobId,
  });
  final String jobId;

  @override
  ConsumerState<ClientDisputePage> createState() => _ClientDisputePageState();
}

class _ClientDisputePageState extends ConsumerState<ClientDisputePage> {
  bool isLoading = true;
  String? errorMessage;

  Map<String, dynamic>? job; // vem da view v_client_jobs
  Map<String, dynamic>? dispute; // vem da view v_jobs_with_dispute_status
  List<Map<String, dynamic>> photos = []; // vem do JSON "photos" da view

  bool isUploadingPhotos = false;
  bool isResolving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  bool _isJobClosedForChat(String status) {
    const closed = [
      'completed',
      'cancelled_by_client',
      'cancelled_by_provider',
      'refunded',
    ];
    return closed.contains(status);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  List<Map<String, dynamic>> _parsePhotos(dynamic value) {
    if (value == null) return [];
    try {
      if (value is List) {
        return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  bool _isClientPhotoUrl(String url) {
    if (url.contains('/client/')) return true;
    if (url.contains('/provider/')) return false;
    return true;
  }

  bool _isProviderPhotoUrl(String url) => url.contains('/provider/');

  Future<void> _openFullImage(String url) async {
    await context.pushFullImage(url);
  }

  // ---------------------------------------------------------------------------
  // CARREGAR DADOS (somente VIEWS)
  // ---------------------------------------------------------------------------

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final supabase = ref.read(supabaseProvider);
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          isLoading = false;
          errorMessage =
              'Sua sessão expirou. Faça login novamente para ver a reclamação.';
        });
        return;
      }

      final jobRes = await supabase.from('v_client_jobs').select('''
            id,
            job_code,
            title,
            description,
            client_id,
            provider_id,
            status,
            created_at
          ''').eq('id', widget.jobId).maybeSingle();

      if (jobRes == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'Pedido não encontrado.';
        });
        return;
      }

      final disputeRes =
          await supabase.from('v_jobs_with_dispute_status').select('''
      dispute_id,
      job_id,
      provider_id,
      dispute_opened_by_user_id,
      dispute_role,
      dispute_status,
      dispute_description,
      dispute_created_at,
      dispute_resolved_at,
      auto_refunded_at,
      refund_amount,
      resolution,
      photos
    ''').eq('job_id', widget.jobId).maybeSingle();

      if (disputeRes == null) {
        setState(() {
          isLoading = false;
          job = Map<String, dynamic>.from(jobRes as Map);
          dispute = null;
          photos = [];
          errorMessage = 'Nenhuma reclamação encontrada para este pedido.';
        });
        return;
      }

      final parsedPhotos = _parsePhotos(disputeRes['photos']);

      setState(() {
        job = Map<String, dynamic>.from(jobRes as Map);
        dispute = Map<String, dynamic>.from(disputeRes as Map);
        photos = parsedPhotos;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar reclamação (cliente): $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'Erro ao carregar os dados da reclamação.';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // UPLOAD FOTOS (cliente)
  // ---------------------------------------------------------------------------

  Future<void> _pickAndUploadPhotos() async {
    if (dispute == null) return;

    setState(() => isUploadingPhotos = true);

    try {
      final supabase = ref.read(supabaseProvider);
      final picker = ImagePicker();
      final result = await picker.pickMultiImage(imageQuality: 100);

      if (result.isEmpty) {
        setState(() => isUploadingPhotos = false);
        return;
      }

      final String disputeId = dispute!['dispute_id'].toString();
      final storage = supabase.storage.from('disputes-images');

      for (final file in result) {
        try {
          final rawBytes = await file.readAsBytes();
          final compressed = await ImageUtils.compressWithThumb(rawBytes);

          String ext = p.extension(file.name);
          if (ext.isEmpty) ext = '.jpg';

          final baseName = DateTime.now().millisecondsSinceEpoch.toString();
          final mainPath = 'client/$disputeId/${baseName}_full$ext';
          final thumbPath = 'client/$disputeId/${baseName}_thumb$ext';

          await storage.uploadBinary(mainPath, compressed.mainBytes);
          final publicUrl = storage.getPublicUrl(mainPath);

          await storage.uploadBinary(thumbPath, compressed.thumbBytes);
          final thumbUrl = storage.getPublicUrl(thumbPath);

          await supabase.from('dispute_photos').insert({
            'dispute_id': disputeId,
            'url': publicUrl,
            'thumb_url': thumbUrl,
          });

          photos.add({
            'url': publicUrl,
            'thumb_url': thumbUrl,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });
        } catch (e) {
          debugPrint('Erro ao enviar foto da disputa (cliente): $e');
        }
      }

      if (!mounted) return;
      setState(() {});
      _snack('Fotos enviadas com sucesso.');
    } catch (e) {
      debugPrint('Erro ao selecionar/enviar fotos de disputa (cliente): $e');
      if (!mounted) return;
      _snack('Erro ao enviar fotos.');
    } finally {
      if (mounted) setState(() => isUploadingPhotos = false);
    }
  }

  // ---------------------------------------------------------------------------
  // CHAT
  // ---------------------------------------------------------------------------

  Future<void> _openChat() async {
    if (job == null || dispute == null) return;

    final supabase = ref.read(supabaseProvider);
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      _snack('Faça login novamente para usar o chat.');
      return;
    }

    final jobId = job!['id'].toString();
    final clientId = job!['client_id']?.toString();
    final providerId =
        (job!['provider_id'] ?? dispute!['provider_id'])?.toString();

    if (clientId == null || providerId == null || providerId.isEmpty) {
      _snack('Não foi possível identificar o prestador.');
      return;
    }

    try {
      final chatRepo = ref.read(legacyChatRepositoryProvider);
      final conv = await chatRepo.upsertConversationForJob(
        jobId: jobId,
        clientId: clientId,
        providerId: providerId,
      );

      if (conv == null || conv['id'] == null) {
        _snack('Não foi possível abrir o chat. Tente novamente.');
        return;
      }

      final conversationId = conv['id'].toString();
      final jobTitle =
          (job!['title'] as String?) ?? (job!['description'] as String?) ?? '';
      const otherUserName = 'Profissional';

      final jobStatus = (job!['status'] as String?) ?? '';
      final disputeStatus = (dispute!['dispute_status'] as String?) ?? 'open';

      final isJobClosed = _isJobClosedForChat(jobStatus);
      final isChatLocked = isJobClosed && disputeStatus != 'open';

      if (!mounted) return;

      await context.pushChat({
        'conversationId': conversationId,
        'jobTitle': jobTitle.isEmpty ? 'Chat do pedido' : jobTitle,
        'otherUserName': otherUserName,
        'currentUserId': currentUser.id,
        'currentUserRole': 'client',
        'isChatLocked': isChatLocked,
      });
    } catch (e) {
      debugPrint('Erro ao abrir chat na disputa (cliente): $e');
      if (!mounted) return;
      _snack('Erro ao abrir o chat.');
    }
  }

  // ---------------------------------------------------------------------------
  // AÇÃO: PROBLEMA RESOLVIDO (cliente)
  // ---------------------------------------------------------------------------

  Future<void> _onProblemResolved() async {
    if (job == null) return;

    setState(() => isResolving = true);

    try {
      final jobId = job!['id'].toString();
      final jobRepo = ref.read(appJobRepositoryProvider);
      await jobRepo.resolveDisputeForJob(jobId);

      await _loadData();

      if (!mounted) return;
      _snack('Obrigado! Reclamação marcada como resolvida.');
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Erro ao marcar problema como resolvido (cliente): $e');
      if (!mounted) return;
      _snack('Erro ao marcar como resolvido: $e');
    } finally {
      if (mounted) setState(() => isResolving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B246B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Reclamação do pedido',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(errorMessage!, textAlign: TextAlign.center),
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (job == null || dispute == null) {
      return const Center(
        child: Text('Não foi possível carregar os dados da reclamação.'),
      );
    }

    final j = job!;
    final d = dispute!;

    final jobCode = j['job_code'] as String?;
    final jobTitle = (j['title'] as String?) ?? 'Serviço';
    final jobDescription = (j['description'] as String?) ?? 'Sem descrição';

    final disputeStatus = (d['dispute_status'] as String?) ?? 'open';
    final createdAtStr = d['dispute_created_at']?.toString();
    final resolvedAtStr = d['dispute_resolved_at']?.toString();

    String createdAtLabel = '';
    if (createdAtStr != null) {
      try {
        final dt = DateTime.parse(createdAtStr).toLocal();
        createdAtLabel =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
            'às ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    String resolvedAtLabel = '';
    if (resolvedAtStr != null) {
      try {
        final dt = DateTime.parse(resolvedAtStr).toLocal();
        resolvedAtLabel =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
            'às ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    final bool isReadOnly = disputeStatus != 'open';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildJobHeaderCard(jobCode, jobTitle, jobDescription),
          const SizedBox(height: 12),
          _buildDisputeInfoCard(
            createdAtLabel: createdAtLabel,
            resolvedAtLabel: resolvedAtLabel,
            disputeStatus: disputeStatus,
            description: (d['dispute_description'] as String?) ?? '',
          ),
          const SizedBox(height: 12),
          _buildPhotosSection(),
          const SizedBox(height: 16),
          _buildActionSection(
              isReadOnly: isReadOnly, disputeStatus: disputeStatus,),
          const SizedBox(height: 16),
          _buildChatAndUploadActions(isReadOnly: isReadOnly),
        ],
      ),
    );
  }

  Widget _buildJobHeaderCard(
    String? jobCode,
    String jobTitle,
    String jobDescription,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (jobCode != null && jobCode.isNotEmpty) ...[
            Text(
              'Pedido $jobCode',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3B246B),
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            jobTitle,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            jobDescription,
            style: const TextStyle(
              fontSize: 12.5,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisputeInfoCard({
    required String createdAtLabel,
    required String resolvedAtLabel,
    required String disputeStatus,
    required String description,
  }) {
    String statusText;
    Color statusColor;

    switch (disputeStatus) {
      case 'resolved':
        statusText = 'Reclamação resolvida.';
        statusColor = const Color(0xFF0DAA00);
        break;
      case 'refunded':
        statusText = 'Reclamação encerrada com estorno.';
        statusColor = const Color(0xFFFF6600);
        break;
      case 'open':
      default:
        statusText = 'Reclamação em análise.';
        statusColor = const Color(0xFF3B246B);
        break;
    }

    String chipLabel;
    if (disputeStatus == 'open') {
      chipLabel = 'Em análise';
    } else if (disputeStatus == 'resolved') {
      chipLabel = 'Resolvida';
    } else {
      chipLabel = 'Estornada';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.report_gmailerrorred_outlined,
                color: Color(0xFF3B246B),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Detalhes da reclamação',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3B246B),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  chipLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (createdAtLabel.isNotEmpty)
            Text(
              'Aberta em: $createdAtLabel',
              style: const TextStyle(fontSize: 11.5, color: Colors.black54),
            ),
          if (resolvedAtLabel.isNotEmpty && disputeStatus != 'open') ...[
            const SizedBox(height: 2),
            Text(
              'Encerrada em: $resolvedAtLabel',
              style: const TextStyle(fontSize: 11.5, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            statusText,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          const Text(
            'Sua mensagem:',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            description.isEmpty ? 'Sem descrição detalhada.' : description,
            style: const TextStyle(
              fontSize: 12.5,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosSection() {
    final clientPhotos = photos
        .where((ph) => _isClientPhotoUrl((ph['url'] as String?) ?? ''))
        .toList();
    final providerPhotos = photos
        .where((ph) => _isProviderPhotoUrl((ph['url'] as String?) ?? ''))
        .toList();

    Widget photoRow(List<Map<String, dynamic>> list) {
      if (list.isEmpty) {
        return const Text(
          'Nenhuma foto.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        );
      }

      return SizedBox(
        height: 90,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final ph = list[i];
            final fullUrl = (ph['url'] as String?) ?? '';
            if (fullUrl.isEmpty) return const SizedBox.shrink();
            final thumbUrl = (ph['thumb_url'] as String?) ?? fullUrl;

            return GestureDetector(
              onTap: () => _openFullImage(fullUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.network(
                    thumbUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Fotos do problema (cliente)',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3B246B),
                ),
              ),
              const SizedBox(height: 6),
              photoRow(clientPhotos),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Fotos da solução (prestador)',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3B246B),
                ),
              ),
              const SizedBox(height: 6),
              photoRow(providerPhotos),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionSection({
    required bool isReadOnly,
    required String disputeStatus,
  }) {
    if (isReadOnly) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'Esta reclamação já foi encerrada. As informações acima ficam disponíveis apenas para consulta.',
          style: TextStyle(fontSize: 12, color: Colors.black87),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Se o problema foi resolvido, você pode encerrar a reclamação:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF3B246B),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: isResolving ? null : _onProblemResolved,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0DAA00),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.check_circle_outline),
          label: Text(
            isResolving ? 'Atualizando...' : 'Problema resolvido',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildChatAndUploadActions({required bool isReadOnly}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _openChat,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B246B),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text(
            'Falar com o profissional pelo chat',
            style: TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed:
              isReadOnly || isUploadingPhotos ? null : _pickAndUploadPhotos,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF3B246B),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: isUploadingPhotos
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.photo_library_outlined),
          label: Text(
            isUploadingPhotos
                ? 'Enviando fotos...'
                : 'Anexar fotos da reclamação',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _FullScreenImagePage extends StatelessWidget {

  const _FullScreenImagePage({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
