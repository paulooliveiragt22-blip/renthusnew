import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/utils/error_handler.dart';
import 'package:renthus/core/router/app_router.dart';
import 'package:renthus/features/jobs/data/providers/job_providers.dart';
import 'package:renthus/utils/image_utils.dart';

class ClientDisputePage extends ConsumerStatefulWidget {
  const ClientDisputePage({super.key, required this.jobId});
  final String jobId;

  @override
  ConsumerState<ClientDisputePage> createState() => _ClientDisputePageState();
}

class _ClientDisputePageState extends ConsumerState<ClientDisputePage> {
  static const int _maxClientPhotos = 5;

  bool isLoading = true;
  String? errorMessage;

  Map<String, dynamic>? job;
  Map<String, dynamic>? dispute;
  List<Map<String, dynamic>> photos = [];

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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  List<Map<String, dynamic>> _parsePhotos(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  bool _isClientPhoto(String url) => !url.contains('/provider/');
  bool _isProviderPhoto(String url) => url.contains('/provider/');

  int _clientPhotosCount() =>
      photos.where((ph) => _isClientPhoto((ph['url'] as String?) ?? '')).length;

  Future<void> _openFullImage(String url) async {
    await context.pushFullImage(url);
  }

  String _statusLabel(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'open':
        return 'Em análise';
      case 'resolved':
        return 'Resolvida';
      case 'refunded':
        return 'Estornada';
      case 'closed':
        return 'Encerrada';
      default:
        return s ?? '—';
    }
  }

  Color _statusColor(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'open':
        return const Color(0xFF3B246B);
      case 'resolved':
      case 'closed':
        return const Color(0xFF0DAA00);
      case 'refunded':
        return const Color(0xFFFF6600);
      default:
        return Colors.black54;
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
          'às ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  // ---------------------------------------------------------------------------
  // CARREGAR DADOS
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
          errorMessage = 'Sua sessão expirou. Faça login novamente.';
        });
        return;
      }

      final jobRes = await supabase.from('v_client_jobs').select(
        'id, job_code, title, description, client_id, provider_id, status, created_at',
      ).eq('id', widget.jobId).maybeSingle();

      if (jobRes == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'Pedido não encontrado.';
        });
        return;
      }

      final disputeRes = await supabase.from('v_jobs_with_dispute_status').select(
        'dispute_id, job_id, provider_id, dispute_opened_by_user_id, dispute_role, dispute_status, dispute_description, dispute_created_at, dispute_resolved_at, auto_refunded_at, refund_amount, resolution, photos',
      ).eq('job_id', widget.jobId).maybeSingle();

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

      setState(() {
        job = Map<String, dynamic>.from(jobRes as Map);
        dispute = Map<String, dynamic>.from(disputeRes as Map);
        photos = _parsePhotos(disputeRes['photos']);
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
  // UPLOAD FOTOS
  // ---------------------------------------------------------------------------

  Future<void> _pickAndUploadPhotos() async {
    if (dispute == null) return;

    final existing = _clientPhotosCount();
    final remaining = _maxClientPhotos - existing;

    if (remaining <= 0) {
      _snack('Você já enviou o máximo de $_maxClientPhotos fotos.');
      return;
    }

    // Seleciona imagens ANTES de ativar o loading
    final picker = ImagePicker();
    final result = await picker.pickMultiImage(imageQuality: 100);
    if (result.isEmpty) return;

    final selected = result.take(remaining).toList();

    // Confirmação com preview
    final confirmed = await _showPhotoPreviewDialog(selected);
    if (confirmed != true) return;

    setState(() => isUploadingPhotos = true);

    try {
      final supabase = ref.read(supabaseProvider);
      final String disputeId = dispute!['dispute_id'].toString();
      final storage = supabase.storage.from('disputes-images');
      int successCount = 0;
      int failCount = 0;

      for (int i = 0; i < selected.length; i++) {
        final file = selected[i];
        try {
          final rawBytes = await file.readAsBytes();
          final compressed = await ImageUtils.compressWithThumb(rawBytes);

          String ext = p.extension(file.name);
          if (ext.isEmpty) ext = '.jpg';

          final baseName = '${DateTime.now().millisecondsSinceEpoch}_$i';
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
          successCount++;
        } catch (e) {
          debugPrint('Erro ao enviar foto $i (cliente): $e');
          failCount++;
        }
      }

      if (!mounted) return;
      setState(() {});
      if (failCount == 0) {
        _snack(successCount > 1
            ? '$successCount fotos enviadas com sucesso.'
            : 'Foto enviada com sucesso.');
      } else {
        _snack('$successCount enviadas, $failCount falharam. Tente enviar as restantes.');
      }
    } catch (e) {
      debugPrint('Erro geral no upload de fotos (cliente): $e');
      if (!mounted) return;
      _snack('Erro ao enviar fotos.');
    } finally {
      if (mounted) setState(() => isUploadingPhotos = false);
    }
  }

  Future<bool?> _showPhotoPreviewDialog(List<XFile> files) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar fotos'),
        content: SizedBox(
          width: double.maxFinite,
          height: 220,
          child: GridView.builder(
            itemCount: files.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (_, index) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(files[index].path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Color(0xFFE0E0E0),
                  child: Center(child: Icon(Icons.broken_image)),
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
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
      final disputeStatus =
          (dispute!['dispute_status'] as String?) ?? 'open';
      final jobStatus = (job!['status'] as String?) ?? '';
      const closedStatuses = [
        'completed',
        'cancelled_by_client',
        'cancelled_by_provider',
        'refunded',
      ];
      final isJobClosed = closedStatuses.contains(jobStatus);
      final isChatLocked = isJobClosed && disputeStatus != 'open';

      if (!mounted) return;

      await context.pushChat({
        'conversationId': conversationId,
        'jobTitle': jobTitle.isEmpty ? 'Chat do pedido' : jobTitle,
        'otherUserName': 'Profissional',
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
  // RESOLVER DISPUTA
  // ---------------------------------------------------------------------------

  Future<void> _onProblemResolved() async {
    if (job == null) return;
    setState(() => isResolving = true);
    try {
      final jobRepo = ref.read(appJobRepositoryProvider);
      await jobRepo.resolveDisputeForJob(job!['id'].toString());
      if (!mounted) return;
      _snack('Obrigado! Reclamação marcada como resolvida.');
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Erro ao marcar problema como resolvido (cliente): $e');
      if (!mounted) return;
      _snack(ErrorHandler.friendlyErrorMessage(e));
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
        actions: [
          IconButton(
            onPressed: isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _loadData,
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (job == null || dispute == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Não foi possível carregar os dados da reclamação.'),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadData,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    final j = job!;
    final d = dispute!;

    final jobCode = j['job_code'] as String?;
    final jobTitle = (j['title'] as String?) ?? 'Serviço';
    final jobDescription = (j['description'] as String?) ?? 'Sem descrição';

    final disputeStatus = (d['dispute_status'] as String?) ?? 'open';
    final createdAtLabel = _fmtDate(d['dispute_created_at']?.toString());
    final resolvedAtLabel = _fmtDate(d['dispute_resolved_at']?.toString());
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
          _buildActionSection(isReadOnly: isReadOnly),
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
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            jobDescription,
            style: const TextStyle(
                fontSize: 12.5, color: Colors.black87, height: 1.4),
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
    final statusText = disputeStatus == 'open'
        ? 'Reclamação em análise.'
        : disputeStatus == 'resolved'
            ? 'Reclamação resolvida.'
            : 'Reclamação encerrada com estorno.';
    final statusColor = _statusColor(disputeStatus);
    final chipLabel = _statusLabel(disputeStatus);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
              const Expanded(
                child: Text(
                  'Detalhes da reclamação',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3B246B),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
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
            style:
                TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            description.isEmpty ? 'Sem descrição detalhada.' : description,
            style: const TextStyle(
                fontSize: 12.5, color: Colors.black87, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosSection() {
    final clientPhotos = photos
        .where((ph) => _isClientPhoto((ph['url'] as String?) ?? ''))
        .toList();
    final providerPhotos = photos
        .where((ph) => _isProviderPhoto((ph['url'] as String?) ?? ''))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPhotoCard(
          title: 'Fotos do problema (cliente)',
          photoList: clientPhotos,
        ),
        if (providerPhotos.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildPhotoCard(
            title: 'Fotos da solução (prestador)',
            photoList: providerPhotos,
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoCard({
    required String title,
    required List<Map<String, dynamic>> photoList,
  }) {
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3B246B),
            ),
          ),
          const SizedBox(height: 6),
          if (photoList.isEmpty)
            const Text(
              'Nenhuma foto enviada.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            )
          else
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photoList.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final ph = photoList[i];
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
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: const Color(0xFFE8E8E8),
                              child: const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: Color(0xFFE0E0E0),
                            child: Center(
                              child: Icon(Icons.broken_image,
                                  color: Colors.black38),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionSection({required bool isReadOnly}) {
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
                borderRadius: BorderRadius.circular(12)),
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
    final clientCount = _clientPhotosCount();
    final remaining = _maxClientPhotos - clientCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: isReadOnly ? null : _openChat,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B246B),
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade600,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.chat_bubble_outline),
          label: Text(
            isReadOnly
                ? 'Chat encerrado'
                : 'Falar com o profissional pelo chat',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: (isReadOnly || isUploadingPhotos || remaining <= 0)
              ? null
              : _pickAndUploadPhotos,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF3B246B),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
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
                : remaining <= 0
                    ? 'Limite atingido ($_maxClientPhotos/$_maxClientPhotos fotos)'
                    : 'Anexar fotos ($clientCount/$_maxClientPhotos)',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}
