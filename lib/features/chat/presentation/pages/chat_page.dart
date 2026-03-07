import 'dart:io' show Platform;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:renthus/core/utils/error_handler.dart';
import 'package:renthus/features/chat/data/providers/chat_providers.dart';
import 'package:renthus/features/chat/domain/models/message_model.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({
    super.key,
    required this.conversationId,
    required this.jobTitle,
    required this.otherUserName,
    required this.currentUserId,
    required this.currentUserRole,
    this.isChatLocked = false,
    this.otherUserPhotoUrl,
  });

  final String conversationId;
  final String jobTitle;
  final String otherUserName;
  final String currentUserId;
  final String currentUserRole;
  final bool isChatLocked;
  final String? otherUserPhotoUrl;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();

  bool _sending = false;
  bool _sendingImage = false;
  bool _initialScrollDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  Future<void> _markRead() async {
    try {
      await ref
          .read(chatActionsProvider.notifier)
          .markAsRead(widget.conversationId, widget.currentUserRole);
    } catch (_) {}
  }

  bool _containsContactInfo(String text) {
    final emailReg = RegExp(
      r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
      caseSensitive: false,
    );
    // more specific: requires parenthesis or at least 10 consecutive digits
    final phoneReg = RegExp(
      r'(\(?\d{2}\)?[\s\-]?\d{4,5}[\s\-]?\d{4})',
    );
    final keywordsReg = RegExp(
      r'(whatsapp|zapzap|zap|telefone|celular|instagram|@gmail|@hotmail|@outlook)',
      caseSensitive: false,
    );
    if (emailReg.hasMatch(text)) return true;
    if (phoneReg.hasMatch(text)) return true;
    if (keywordsReg.hasMatch(text)) return true;
    return false;
  }

  Future<void> _sendMessage() async {
    if (widget.isChatLocked) {
      _showLockedSnack();
      return;
    }

    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;

    if (_containsContactInfo(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por segurança, não é permitido compartilhar telefones, '
            'e-mails ou contatos externos pelo chat.',
          ),
        ),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      await ref.read(chatActionsProvider.notifier).sendMessage(
            conversationId: widget.conversationId,
            senderId: widget.currentUserId,
            senderRole: widget.currentUserRole,
            content: text,
          );
      _textController.clear();
      // Aguarda o stream atualizar e o widget reconstruir antes de rolar
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.friendlyErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<String?> _showImageSourceDialog() {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Câmera'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeria'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              title: const Text('Cancelar', textAlign: TextAlign.center),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage() async {
    if (widget.isChatLocked) {
      _showLockedSnack();
      return;
    }
    if (_sendingImage) return;

    try {
      setState(() => _sendingImage = true);

      List<int>? bytes;
      String fileName;

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final source = await _showImageSourceDialog();
        if (!mounted) return;
        if (source == null) {
          setState(() => _sendingImage = false);
          return;
        }

        final picked = await _imagePicker.pickImage(
          source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1600,
          imageQuality: 85,
        );

        if (picked == null) {
          setState(() => _sendingImage = false);
          return;
        }

        bytes = await picked.readAsBytes();
        fileName = picked.name;
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
        );

        if (result == null || result.files.isEmpty) {
          setState(() => _sendingImage = false);
          return;
        }

        final file = result.files.single;
        bytes = file.bytes;
        fileName = file.name;
      }

      if (bytes == null) {
        setState(() => _sendingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não consegui carregar a imagem.')),
        );
        return;
      }

      final chatRepo = ref.read(chatRepositoryProvider);
      final url = await chatRepo.uploadImage(
        conversationId: widget.conversationId,
        bytes: bytes,
        fileName: fileName,
      );

      await ref.read(chatActionsProvider.notifier).sendMessage(
            conversationId: widget.conversationId,
            senderId: widget.currentUserId,
            senderRole: widget.currentUserRole,
            content: '📷 Imagem',
            type: MessageType.image,
            imageUrl: url,
          );

      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.friendlyErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _sendingImage = false);
    }
  }

  void _openImagePreview(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Hero(
            tag: imageUrl,
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => const CircularProgressIndicator(
                  color: Colors.white,
                ),
                errorWidget: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _scrollToBottomIfNearEnd() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final nearBottom = pos.maxScrollExtent - pos.pixels < 400;
    if (nearBottom) _scrollToBottom();
  }

  void _showLockedSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Este chat foi encerrado. Não é possível enviar novas mensagens.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.jobTitle.isNotEmpty
        ? widget.jobTitle
        : 'Chat com ${widget.otherUserName}';

    final messagesAsync =
        ref.watch(messagesStreamProvider(widget.conversationId));

    // Mark as read and auto-scroll when new messages arrive
    ref.listen(messagesStreamProvider(widget.conversationId), (prev, next) {
      if (next.hasValue && (next.value?.isNotEmpty ?? false)) {
        _markRead();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottomIfNearEnd();
        });
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B246B),
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            _buildAppBarAvatar(),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (widget.isChatLocked)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFFFF3E0),
              child: const Text(
                'Este chat foi encerrado porque o pedido foi finalizado ou '
                'cancelado. Você ainda pode visualizar as mensagens, mas não '
                'pode enviar novas.',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF7A4F00),
                  height: 1.3,
                ),
              ),
            ),
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(ErrorHandler.friendlyErrorMessage(error)),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'Nenhuma mensagem ainda.\nEnvie a primeira!',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                // Scroll automático para o final na primeira carga
                if (!_initialScrollDone) {
                  _initialScrollDone = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _scrollToBottom();
                  });
                }

                // Build items list with date separators
                final items = <dynamic>[];
                DateTime? lastDate;
                for (final msg in messages) {
                  final d = msg.createdAt.toLocal();
                  final msgDate = DateTime(d.year, d.month, d.day);
                  if (lastDate == null || msgDate != lastDate) {
                    items.add(msgDate);
                    lastDate = msgDate;
                  }
                  items.add(msg);
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item is DateTime) {
                      return _buildDateSeparator(item);
                    }
                    final m = item as Message;
                    final isMe = m.isMine(widget.currentUserId);
                    return _buildBubble(
                      message: m,
                      isMe: isMe,
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildAppBarAvatar() {
    final photoUrl = (widget.otherUserPhotoUrl ?? '').trim();
    if (photoUrl.isEmpty) {
      return const CircleAvatar(
        radius: 14,
        child: Icon(Icons.person, size: 16),
      );
    }
    return CircleAvatar(
      radius: 14,
      backgroundImage: CachedNetworkImageProvider(photoUrl),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String label;
    if (date == today) {
      label = 'Hoje';
    } else if (date == yesterday) {
      label = 'Ontem';
    } else {
      label =
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ),
    );
  }

  Widget _buildBubble({
    required Message message,
    required bool isMe,
  }) {
    final type = message.type?.name ?? 'text';
    final imageUrl = message.imageUrl;
    final bgColor = isMe ? const Color(0xFF3B246B) : Colors.white;
    final textColor = isMe ? Colors.white : Colors.black87;

    Widget child;

    if (type == 'image' && imageUrl != null) {
      child = GestureDetector(
        onTap: () => _openImagePreview(imageUrl),
        child: Hero(
          tag: imageUrl,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 220,
              height: 260,
              fit: BoxFit.cover,
              placeholder: (_, __) => const SizedBox(
                width: 220,
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 220,
                height: 260,
                color: Colors.black12,
                alignment: Alignment.center,
                child: const Text(
                  'Não foi possível carregar a imagem.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      child = Text(
        message.content,
        style: TextStyle(color: textColor, fontSize: 13),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: type == 'image'
                  ? const EdgeInsets.all(2)
                  : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: const BoxConstraints(maxWidth: 260),
              decoration: BoxDecoration(
                color: type == 'image' ? Colors.transparent : bgColor,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  if (!isMe && type != 'image')
                    const BoxShadow(
                      color: Colors.black12,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                ],
              ),
              child: child,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: Text(
                message.timeFormatted,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        color: Colors.grey.shade100,
        child: Row(
          children: [
            IconButton(
              onPressed: (widget.isChatLocked || _sendingImage)
                  ? null
                  : _pickAndSendImage,
              icon: _sendingImage
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image),
              color: const Color(0xFF3B246B),
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                enabled: !widget.isChatLocked,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: widget.isChatLocked
                      ? 'Chat encerrado'
                      : 'Digite uma mensagem...',
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed:
                  (widget.isChatLocked || _sending) ? null : _sendMessage,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              color: const Color(0xFF3B246B),
            ),
          ],
        ),
      ),
    );
  }
}
