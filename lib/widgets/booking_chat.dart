// lib/widgets/booking_chat.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img_pkg;

import 'package:renthus/core/providers/supabase_provider.dart';

class BookingChat extends ConsumerStatefulWidget {
  final String bookingId;
  const BookingChat({super.key, required this.bookingId});

  @override
  ConsumerState<BookingChat> createState() => _BookingChatState();
}

class _BookingChatState extends ConsumerState<BookingChat> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;
  bool _uploading = false;

  Stream<List<Map<String, dynamic>>> _messagesStream(String bookingId) {
    final client = ref.read(supabaseProvider);
    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('booking_id', bookingId)
        .order('created_at');
  }

  String _formatTime(String? value) {
    if (value == null || value.isEmpty) return '';
    try {
      final d = DateTime.parse(value).toLocal();
      return DateFormat('HH:mm').format(d);
    } catch (_) {
      return value;
    }
  }

  Future<void> _sendMessageToDb({required String content, String? thumbUrl}) async {
    final client = ref.read(supabaseProvider);
    final user = client.auth.currentUser;
    if (user == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Você precisa estar logado para enviar mensagens')));
      return;
    }

    await client.from('messages').insert({
      'booking_id': widget.bookingId,
      'sender_id': user.id,
      'sender_role': (user.userMetadata?['role'] as String?) ?? '',
      'content': content,
      'thumb_url': thumbUrl,
    });
  }

  Future<void> _sendMessage({required String content}) async {
    final text = content.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await _sendMessageToDb(content: text, thumbUrl: null);
      _ctrl.clear();
      await Future.delayed(const Duration(milliseconds: 150));
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar mensagem: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // tenta retornar public url ou signed
  Future<String?> _getPublicOrSignedUrl(String bucket, String path) async {
    final client = ref.read(supabaseProvider);
    try {
      final dynamic pub = client.storage.from(bucket).getPublicUrl(path);
      if (pub is String && pub.isNotEmpty) return pub;
      if (pub is Map) {
        final p = pub['publicUrl'] ?? pub['public_url'] ?? pub['publicURI'];
        if (p is String && p.isNotEmpty) return p;
      }
    } catch (_) {}

    try {
      final dynamic signed = await client.storage.from(bucket).createSignedUrl(path, 60 * 60 * 24);
      if (signed is String && signed.isNotEmpty) return signed;
      if (signed is Map) {
        final s = signed['signedURL'] ?? signed['signed_url'] ?? signed['signedUrl'];
        if (s is String && s.isNotEmpty) return s;
      }
    } catch (_) {}

    return null;
  }

  Uint8List? _generateThumbnail(Uint8List bytes, {int width = 400, int quality = 75}) {
    try {
      final img_pkg.Image? src = img_pkg.decodeImage(bytes);
      if (src == null) return null;
      final img_pkg.Image thumb = img_pkg.copyResize(src, width: width);
      final List<int> jpg = img_pkg.encodeJpg(thumb, quality: quality);
      return Uint8List.fromList(jpg);
    } catch (e) {
      debugPrint('Erro ao gerar thumbnail: $e');
      return null;
    }
  }

  Future<Map<String, String>?> _uploadImageAndThumb(PlatformFile file) async {
    final client = ref.read(supabaseProvider);
    const String bucket = 'chat-attachments';
    setState(() => _uploading = true);
    try {
      // extensão segura
      String ext = '';
      if (file.extension != null && file.extension!.isNotEmpty) ext = '.${file.extension}';
      else {
        final m = RegExp(r'\.[A-Za-z0-9]+$').firstMatch(file.name ?? '');
        if (m != null) ext = m.group(0) ?? '';
      }

      final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
      final originalPath = '${widget.bookingId}/$timestamp$ext';
      final thumbPath = '${widget.bookingId}/thumbs/${timestamp}_thumb.jpg';

      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        final f = File(file.path!);
        bytes = await f.readAsBytes();
      }
      if (bytes == null) throw Exception('Não foi possível ler os bytes do arquivo');

      // upload original
      await client.storage.from(bucket).uploadBinary(originalPath, bytes, fileOptions: const FileOptions(cacheControl: '3600'));

      // gerar e upload do thumb
      final Uint8List? thumbBytes = _generateThumbnail(bytes);
      if (thumbBytes != null) {
        await client.storage.from(bucket).uploadBinary(thumbPath, thumbBytes, fileOptions: const FileOptions(cacheControl: '3600'));
      }

      final fullUrl = await _getPublicOrSignedUrl(bucket, originalPath);
      String? thumbUrl;
      if (thumbBytes != null) thumbUrl = await _getPublicOrSignedUrl(bucket, thumbPath);

      if (fullUrl == null) throw Exception('Não foi possível obter URL do arquivo enviado.');
      return {'full': fullUrl, 'thumb': thumbUrl ?? fullUrl};
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao fazer upload: $e')));
      return null;
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickAndUploadImageWithThumb() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);
      if (result == null || result.files.isEmpty) return;
      final PlatformFile file = result.files.first;

      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enviar imagem'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (kIsWeb)
                  if (file.bytes != null) Image.memory(file.bytes!, height: 160) else const SizedBox.shrink()
                else if (file.path != null)
                  Image.file(File(file.path!), height: 160)
                else
                  const SizedBox.shrink(),
                const SizedBox(height: 8),
                Text(file.name),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enviar')),
          ],
        ),
      );

      if (confirm != true) return;

      final uploaded = await _uploadImageAndThumb(file);
      if (uploaded == null) return;

      final thumb = uploaded['thumb']!;
      final full = uploaded['full']!;
      final content = '[![attachment]($thumb)]($full)';

      setState(() => _sending = true);
      try {
        await _sendMessageToDb(content: content, thumbUrl: thumb);
        _ctrl.clear();
        await Future.delayed(const Duration(milliseconds: 150));
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar mensagem: $e')));
      } finally {
        if (mounted) setState(() => _sending = false);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro no picker: $e')));
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> m) {
    final String senderId = (m['sender_id'] ?? '').toString();
    final String content = (m['content'] ?? '').toString();
    final String senderRole = (m['sender_role'] ?? '').toString();
    final String createdAt = (m['created_at'] ?? '').toString();
    final currentUserId = ref.read(supabaseProvider).auth.currentUser?.id;
    final bool isMe = currentUserId == senderId;

    // padrão com thumb: [![alt](thumbUrl)](fullUrl)
    final RegExp thumbLinkRegex = RegExp(r'\[\!\[.*?\]\((https?:\/\/[^\s)]+)\)\]\((https?:\/\/[^\s)]+)\)');
    final RegExpMatch? thumbMatch = thumbLinkRegex.firstMatch(content);
    if (thumbMatch != null) {
      final String thumbUrl = thumbMatch.group(1) ?? '';
      final String fullUrl = thumbMatch.group(2) ?? '';
      final String textPart = content.replaceAll(thumbLinkRegex, '').trim();

      final Color bubbleColor = isMe ? Theme.of(context).colorScheme.primary : Colors.grey.shade200;
      final Color textColor = isMe ? Colors.white : Colors.black87;

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              CircleAvatar(child: Text((senderRole.isNotEmpty ? senderRole[0].toUpperCase() : '?'))),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (textPart.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: bubbleColor, borderRadius: BorderRadius.circular(12)),
                      child: Text(textPart, style: TextStyle(color: textColor)),
                    ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      if (fullUrl.isNotEmpty) Navigator.push(context, MaterialPageRoute(builder: (_) => _FullImageScreen(url: fullUrl)));
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(thumbUrl, width: 200, fit: BoxFit.cover, errorBuilder: (c, e, s) => const SizedBox(height: 120, child: Center(child: Icon(Icons.broken_image)))),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(_formatTime(createdAt), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
            if (isMe) const SizedBox(width: 8),
          ],
        ),
      );
    }

    // fallback: imagem simples ![alt](url)
    final RegExp imageRegex = RegExp(r'!\[.*?\]\((https?:\/\/[^\s)]+)\)');
    final RegExpMatch? match = imageRegex.firstMatch(content);
    final bool hasImage = match != null;
    final String? imageUrl = hasImage ? match!.group(1) : null;
    String textPart = content;
    if (hasImage) textPart = content.replaceAll(imageRegex, '').trim();

    final Color bubbleColor = isMe ? Theme.of(context).colorScheme.primary : Colors.grey.shade200;
    final Color textColor = isMe ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(child: Text((senderRole.isNotEmpty ? senderRole[0].toUpperCase() : '?'))),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (textPart.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: bubbleColor, borderRadius: BorderRadius.circular(12)),
                    child: Text(textPart, style: TextStyle(color: textColor)),
                  ),
                if (hasImage && imageUrl != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      if (imageUrl.isNotEmpty) Navigator.push(context, MaterialPageRoute(builder: (_) => _FullImageScreen(url: imageUrl)));
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(imageUrl!, width: 200, fit: BoxFit.cover, errorBuilder: (c, e, s) => const SizedBox(height: 120, child: Center(child: Icon(Icons.broken_image)))),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(_formatTime(createdAt), style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 420,
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream(widget.bookingId),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Erro no chat: ${snapshot.error}'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final messages = snapshot.data!;
                if (messages.isEmpty) return const Center(child: Text('Nenhuma mensagem. Comece a conversar ✉️'));

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
                });

                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) {
                    final dynamic item = messages[i];
                    if (item is Map<String, dynamic>) return _buildMessageBubble(item);
                    return const SizedBox.shrink();
                  },
                );
              },
            ),
          ),

          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: Colors.transparent,
              child: Row(
                children: [
                  IconButton(
                    icon: _uploading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.attach_file),
                    onPressed: _uploading ? null : _pickAndUploadImageWithThumb,
                    tooltip: 'Anexar imagem',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Escreva uma mensagem...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(content: _ctrl.text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _sending
                      ? const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                      : IconButton(onPressed: () => _sendMessage(content: _ctrl.text), icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullImageScreen extends StatelessWidget {
  final String url;
  const _FullImageScreen({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(url, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 80)),
        ),
      ),
    );
  }
}
