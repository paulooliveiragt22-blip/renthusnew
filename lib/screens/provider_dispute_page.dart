import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:renthus/core/providers/supabase_provider.dart';
import '../utils/image_utils.dart';

class ProviderDisputePage extends ConsumerStatefulWidget {
  final String jobId;

  const ProviderDisputePage({
    super.key,
    required this.jobId,
  });

  @override
  ConsumerState<ProviderDisputePage> createState() =>
      _ProviderDisputePageState();
}

class _ProviderDisputePageState extends ConsumerState<ProviderDisputePage> {

  bool isLoading = true;
  String? errorMessage;

  Map<String, dynamic>? dispute; // vindo da view
  List<Map<String, dynamic>> photos = [];

  bool isUploadingPhotos = false;

  static const int _maxProviderPhotos = 5;
  List<PlatformFile> _pendingProviderPhotos = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ---------------------------------------------------------------------------
  // CARREGAR DADOS (SOMENTE VIEW)
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
          errorMessage = 'Sessão expirada. Faça login novamente.';
        });
        return;
      }

      final res = await supabase.from('v_provider_disputes').select('''
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

      if (res == null) {
        setState(() {
          isLoading = false;
          dispute = null;
          photos = [];
          errorMessage = 'Não há reclamação para este pedido no momento.';
        });
        return;
      }

      // (Opcional, recomendado) garante que esta disputa pertence ao provider logado
      final providerIdFromView = (res['provider_id'] ?? '').toString();
      if (providerIdFromView.isNotEmpty && providerIdFromView != user.id) {
        setState(() {
          isLoading = false;
          errorMessage = 'Você não tem permissão para ver esta reclamação.';
        });
        return;
      }

      final dynamic photosJson = res['photos'];
      final List<Map<String, dynamic>> photosList = (() {
        if (photosJson == null) return <Map<String, dynamic>>[];
        if (photosJson is List) {
          return photosJson
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
        return <Map<String, dynamic>>[];
      })();

      setState(() {
        dispute = Map<String, dynamic>.from(res as Map);
        photos = photosList;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar disputa (provider) via view: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'Erro ao carregar os dados da reclamação.';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // UPLOAD DE FOTOS (provider) – usa somente dispute_id da VIEW
  // ---------------------------------------------------------------------------

  Future<void> _pickAndUploadPhotos() async {
    if (dispute == null) return;

    final existing = _providerPhotosCount();
    final remaining = _maxProviderPhotos - existing;

    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Você já enviou o máximo de $_maxProviderPhotos fotos para esta reclamação.',
          ),
        ),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
      );

      if (result == null || result.files.isEmpty) return;

      final selected = result.files.take(remaining).toList();
      setState(() => _pendingProviderPhotos = selected);

      await _showProviderPhotosPreviewDialog();
    } catch (e) {
      debugPrint('Erro ao selecionar fotos (provider): $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao selecionar fotos.')),
      );
    }
  }

  Future<void> _showProviderPhotosPreviewDialog() async {
    if (_pendingProviderPhotos.isEmpty) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirme as fotos'),
          content: SizedBox(
            width: double.maxFinite,
            child: SizedBox(
              height: 260,
              child: GridView.builder(
                itemCount: _pendingProviderPhotos.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (_, index) {
                  final f = _pendingProviderPhotos[index];
                  if (f.path == null) {
                    return const ColoredBox(
                      color: Color(0xFFE0E0E0),
                      child: Icon(Icons.broken_image),
                    );
                  }
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(f.path!),
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _uploadPendingProviderPhotos();
    } else {
      setState(() => _pendingProviderPhotos.clear());
    }
  }

  Future<void> _uploadPendingProviderPhotos() async {
    if (dispute == null || _pendingProviderPhotos.isEmpty) return;

    setState(() => isUploadingPhotos = true);

    try {
      final supabase = ref.read(supabaseProvider);
      final String disputeId = dispute!['dispute_id'].toString();
      final storage = supabase.storage.from('disputes-images');

      for (final file in _pendingProviderPhotos) {
        try {
          Uint8List? rawBytes = file.bytes;
          if (rawBytes == null && file.path != null) {
            rawBytes = await File(file.path!).readAsBytes();
          }
          if (rawBytes == null) continue;

          final compressed = await ImageUtils.compressWithThumb(rawBytes);

          String ext = p.extension(file.name);
          if (ext.isEmpty) ext = '.jpg';

          final baseName = DateTime.now().millisecondsSinceEpoch.toString();
          final mainPath = 'provider/$disputeId/${baseName}_full$ext';
          final thumbPath = 'provider/$disputeId/${baseName}_thumb$ext';

          await storage.uploadBinary(mainPath, compressed.mainBytes);
          final publicUrl = storage.getPublicUrl(mainPath);

          await storage.uploadBinary(thumbPath, compressed.thumbBytes);
          final thumbUrl = storage.getPublicUrl(thumbPath);

          // A tabela dispute_photos continua existindo, mas a tela não vai ler dela.
          // Se sua VIEW agrega as fotos direto dessa tabela, isso entra automaticamente na próxima recarga.
          await supabase.from('dispute_photos').insert({
            'dispute_id': disputeId,
            'url': publicUrl,
            'thumb_url': thumbUrl,
          });
        } catch (e) {
          debugPrint('Erro ao enviar uma foto (provider): $e');
        }
      }

      if (!mounted) return;

      // Recarrega pela VIEW (pra refletir a agregação "photos")
      await _loadData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotos enviadas com sucesso.')),
      );
    } catch (e) {
      debugPrint('Erro ao enviar fotos (provider): $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao enviar fotos.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isUploadingPhotos = false;
          _pendingProviderPhotos.clear();
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  int _providerPhotosCount() {
    return photos.where((p) {
      final url = (p['url'] as String?) ?? '';
      return url.contains('/provider/');
    }).length;
  }

  Future<void> _openFullImage(String url) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImagePage(imageUrl: url),
      ),
    );
  }

  String _fmtDateTime(dynamic iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
          'às ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  String _fmtMoney(dynamic v) {
    if (v == null) return '';
    try {
      final num n = (v is num) ? v : num.parse(v.toString());
      return 'R\$ ${n.toStringAsFixed(2).replaceAll('.', ',')}';
    } catch (_) {
      return v.toString();
    }
  }

  String _statusLabel(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'open':
        return 'Aberta';
      case 'resolved':
        return 'Resolvida';
      case 'closed':
        return 'Encerrada';
      case 'refunded':
        return 'Reembolsada';
      default:
        return (s ?? '—').toString();
    }
  }

  Color _statusColor(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'open':
        return Colors.orange;
      case 'resolved':
      case 'closed':
        return const Color(0xFF0DAA00);
      case 'refunded':
        return const Color(0xFF3B246B);
      default:
        return Colors.black54;
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
          'Reclamação',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (dispute == null) {
      return const Center(
        child: Text('Não foi possível carregar os dados da reclamação.'),
      );
    }

    final d = dispute!;

    final status = d['dispute_status']?.toString();
    final createdAt = _fmtDateTime(d['dispute_created_at']);
    final resolvedAt = _fmtDateTime(d['dispute_resolved_at']);
    final autoRefundedAt = _fmtDateTime(d['auto_refunded_at']);
    final refundAmount = _fmtMoney(d['refund_amount']);
    final role = d['dispute_role']?.toString();
    final desc = (d['dispute_description'] as String?) ?? '';
    final resolution = (d['resolution'] as String?) ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(status: status, createdAt: createdAt, role: role),
          const SizedBox(height: 12),
          _buildMessageCard(desc),
          const SizedBox(height: 12),
          _buildOutcomeCard(
            resolvedAt: resolvedAt,
            autoRefundedAt: autoRefundedAt,
            refundAmount: refundAmount,
            resolution: resolution,
          ),
          const SizedBox(height: 12),
          _buildPhotosCard(),
          const SizedBox(height: 12),
          _buildUploadCard(),
          const SizedBox(height: 18),
          _buildSecurityNote(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard({
    required String? status,
    required String createdAt,
    required String? role,
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
            'Pedido: ${widget.jobId}',
            style: const TextStyle(
              fontSize: 11.5,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Status: ${_statusLabel(status)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _statusColor(status),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if ((role ?? '').isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B246B).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Papel: $role',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3B246B),
                    ),
                  ),
                ),
            ],
          ),
          if (createdAt.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Aberta em: $createdAt',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageCard(String description) {
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
          const Row(
            children: [
              Icon(Icons.report_gmailerrorred_outlined,
                  color: Color(0xFF3B246B), size: 20),
              SizedBox(width: 8),
              Text(
                'Mensagem da reclamação',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3B246B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description.isEmpty ? 'Sem descrição.' : description,
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

  Widget _buildOutcomeCard({
    required String resolvedAt,
    required String autoRefundedAt,
    required String refundAmount,
    required String resolution,
  }) {
    final hasResolved = resolvedAt.isNotEmpty;
    final hasAutoRefund = autoRefundedAt.isNotEmpty;
    final hasRefund = refundAmount.isNotEmpty;
    final hasResolution = resolution.trim().isNotEmpty;

    if (!hasResolved && !hasAutoRefund && !hasRefund && !hasResolution) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Ainda não há resolução registrada para esta reclamação.',
          style: TextStyle(fontSize: 12.5, color: Colors.black54),
        ),
      );
    }

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
          const Text(
            'Andamento / Resultado',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3B246B),
            ),
          ),
          const SizedBox(height: 10),
          if (hasResolved)
            Text(
              'Resolvida em: $resolvedAt',
              style: const TextStyle(fontSize: 12.5, color: Colors.black87),
            ),
          if (hasAutoRefund) ...[
            const SizedBox(height: 6),
            Text(
              'Reembolso automático em: $autoRefundedAt',
              style: const TextStyle(fontSize: 12.5, color: Colors.black87),
            ),
          ],
          if (hasRefund) ...[
            const SizedBox(height: 6),
            Text(
              'Valor reembolsado: $refundAmount',
              style: const TextStyle(fontSize: 12.5, color: Colors.black87),
            ),
          ],
          if (hasResolution) ...[
            const SizedBox(height: 10),
            const Text(
              'Resolução registrada:',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              resolution,
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotosCard() {
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
            'Fotos (${photos.length})',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3B246B),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Toque em uma foto para ver em tela cheia.',
            style: TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          if (photos.isEmpty)
            const Text(
              'Nenhuma foto disponível.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            )
          else
            SizedBox(
              height: 95,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final p = photos[index];
                  final fullUrl = (p['url'] as String?) ?? '';
                  if (fullUrl.isEmpty) return const SizedBox();

                  final thumbUrl = (p['thumb_url'] as String?) ?? fullUrl;

                  return GestureDetector(
                    onTap: () => _openFullImage(fullUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.network(
                          thumbUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image),
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

  Widget _buildUploadCard() {
    final count = _providerPhotosCount();
    final remaining = (_maxProviderPhotos - count).clamp(0, _maxProviderPhotos);

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
          const Text(
            'Enviar fotos da solução (prestador)',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3B246B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Você pode enviar até $_maxProviderPhotos fotos. Restam: $remaining.',
            style: const TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isUploadingPhotos ? null : _pickAndUploadPhotos,
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
                isUploadingPhotos ? 'Enviando...' : 'Selecionar e enviar fotos',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_person_outlined,
            size: 18,
            color: Color(0xFFFF6600),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Importante: registre evidências (fotos) dentro do app. '
              'Isso ajuda a equipe Renthus na análise do caso.',
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Tela de visualização em tela cheia
// ----------------------------------------------------------------------------

class _FullScreenImagePage extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImagePage({required this.imageUrl});

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
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image,
              color: Colors.white70,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }
}
