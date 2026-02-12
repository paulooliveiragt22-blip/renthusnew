import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:renthus/features/chat/data/providers/chat_providers.dart';
import 'package:renthus/features/chat/domain/models/message_model.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String conversationId;
  final String jobTitle;
  final String otherUserName;
  final String currentUserId;
  final String currentUserRole;
  final bool isChatLocked;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.jobTitle,
    required this.otherUserName,
    required this.currentUserId,
    required this.currentUserRole,
    this.isChatLocked = false,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  bool _sending = false;
  bool _sendingImage = false;

  bool _containsContactInfo(String text) {
    final lower = text.toLowerCase();
    final emailReg = RegExp(
      r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
      caseSensitive: false,
    );
    final phoneReg = RegExp(r'(\+?\d[\d\s\-\(\)]{7,}\d)');
    final keywordsReg = RegExp(
      r'(whatsapp|zapzap|zap|telefone|celular|número|numero|contato|instagram|@gmail|@hotmail|@outlook)',
      caseSensitive: false,
    );
    if (emailReg.hasMatch(lower)) return true;
    if (phoneReg.hasMatch(lower)) return true;
    if (keywordsReg.hasMatch(lower)) return true;
    return false;
  }

  Future<void> _sendMessage() async {
    if (widget.isChatLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este chat foi encerrado. Não é possível enviar novas mensagens.',
          ),
        ),
      );
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
            content: text,
          );
      _textController.clear();
      await Future.delayed(const Duration(milliseconds: 100));
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar mensagem: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    if (widget.isChatLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este chat foi encerrado. Não é possível enviar novas mensagens.',
          ),
        ),
      );
      return;
    }

    if (_sendingImage) return;

    try {
      setState(() => _sendingImage = true);

      List<int>? bytes;
      String fileName;

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
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
            content: '[imagem]',
            type: MessageType.image,
            imageUrl: url,
          );

      await Future.delayed(const Duration(milliseconds: 100));
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar imagem: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingImage = false);
    }
  }

  void _openImagePreview(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (_) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Center(
            child: Hero(
              tag: imageUrl,
              child: InteractiveViewer(
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
          ),
        );
      },
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B246B),
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 14,
              child: Icon(Icons.person, size: 16),
            ),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFFFF3E0),
              child: const Text(
                'Este chat foi encerrado porque o pedido foi finalizado ou cancelado. '
                'Você ainda pode visualizar as mensagens, mas não pode enviar novas.',
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
                child: Text('Erro: $error'),
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

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final isMe = m.isMine(widget.currentUserId);
                    return _buildBubble(
                      text: m.content,
                      isMe: isMe,
                      type: m.type?.name ?? 'text',
                      imageUrl: m.imageUrl,
                      createdAt: m.createdAt.toLocal(),
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

  Widget _buildBubble({
    required String text,
    required bool isMe,
    required String type,
    String? imageUrl,
    required DateTime createdAt,
  }) {
    final alignment = isMe ? Alignment.centerRight : Alignment.centerLeft;
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
            child: Image.network(
              imageUrl,
              width: 220,
              height: 260,
              fit: BoxFit.cover,
              loadingBuilder: (context, widget, progress) {
                if (progress == null) return widget;
                return SizedBox(
                  width: 220,
                  height: 260,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              (progress.expectedTotalBytes ?? 1)
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 220,
                  height: 260,
                  color: Colors.black12,
                  alignment: Alignment.center,
                  child: const Text(
                    'Não foi possível carregar a imagem.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                );
              },
            ),
          ),
        ),
      );
    } else {
      child = Text(
        text,
        style: TextStyle(color: textColor, fontSize: 13),
      );
    }

    final timeLabel =
        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: alignment,
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
                    BoxShadow(
                      color: Colors.black12.withOpacity(0.05),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                ],
              ),
              child: child,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: Text(
                timeLabel,
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
