import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/chat_repository.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;

  /// OBS: vamos manter por compatibilidade, mas agora o header oficial vem da view
  final String jobTitle;
  final String otherUserName;

  final String currentUserId;
  final String currentUserRole; // 'client' ou 'provider'

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
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _chatRepo = ChatRepository();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  bool _sending = false;
  bool _sendingImage = false;

  // Header vindo da view
  bool _headerLoading = true;
  String _headerTitle = ''; // job_code
  String _headerSubtitle = ''; // provider.full_name ou clients_full_name
  String? _headerAvatarUrl;

  bool get _isClient => widget.currentUserRole == 'client';

  @override
  void initState() {
    super.initState();
    _loadHeader();
  }

  Future<void> _loadHeader() async {
    setState(() => _headerLoading = true);

    try {
      final header = await _chatRepo.fetchChatHeader(
        conversationId: widget.conversationId,
        isClient: _isClient,
      );

      setState(() {
        _headerTitle = (header['header_title'] as String?)?.trim() ?? '';
        _headerSubtitle = (header['header_subtitle'] as String?)?.trim() ?? '';
        _headerAvatarUrl = (header['header_avatar_url'] as String?)?.trim();
        _headerLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar header do chat: $e');
      // fallback: usa o que veio por parâmetro
      setState(() {
        _headerTitle = widget.jobTitle.trim();
        _headerSubtitle = widget.otherUserName.trim();
        _headerAvatarUrl = null;
        _headerLoading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // HELPER: detectar telefone / email / contato externo
  // ---------------------------------------------------------------------------
  bool _containsContactInfo(String text) {
    final lower = text.toLowerCase();

    final emailReg = RegExp(
      r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
      caseSensitive: false,
    );

    final phoneReg = RegExp(
      r'(\+?\d[\d\s\-\(\)]{7,}\d)',
    );

    final keywordsReg = RegExp(
      r'(whatsapp|zapzap|zap|telefone|celular|número|numero|contato|instagram|@gmail|@hotmail|@outlook)',
      caseSensitive: false,
    );

    if (emailReg.hasMatch(lower)) return true;
    if (phoneReg.hasMatch(lower)) return true;
    if (keywordsReg.hasMatch(lower)) return true;

    return false;
  }

  // ---------------------------------------------------------------------------
  // PREVIEW: confirmar envio da imagem
  // ---------------------------------------------------------------------------
  Future<bool> _confirmImageSend(Uint8List bytes) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'Pré-visualização',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: InteractiveViewer(
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B246B),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Enviar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return ok == true;
  }

  // ---------------------------------------------------------------------------
  // ENVIAR TEXTO (RPC)
  // ---------------------------------------------------------------------------
  Future<void> _sendMessage() async {
    if (widget.isChatLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Este chat foi encerrado. Não é possível enviar novas mensagens.'),
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
      await _chatRepo.sendMessageViaRpc(
        conversationId: widget.conversationId,
        senderRole: widget.currentUserRole,
        content: text,
        type: 'text',
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

  // ---------------------------------------------------------------------------
  // ENVIAR IMAGEM (Storage + RPC) com pré-visualização
  // ---------------------------------------------------------------------------
  Future<void> _pickAndSendImage() async {
    if (widget.isChatLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Este chat foi encerrado. Não é possível enviar novas mensagens.'),
        ),
      );
      return;
    }

    if (_sendingImage) return;

    try {
      setState(() => _sendingImage = true);

      Uint8List? bytes;
      String fileName;

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final picker = ImagePicker();
        final XFile? picked = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
        );

        if (picked == null) {
          if (mounted) setState(() => _sendingImage = false);
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
          if (mounted) setState(() => _sendingImage = false);
          return;
        }

        final file = result.files.single;
        bytes = file.bytes;
        fileName = file.name;
      }

      if (bytes == null) {
        if (mounted) setState(() => _sendingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não consegui carregar a imagem.')),
        );
        return;
      }

      // ✅ Pré-visualização antes de enviar
      final confirm = await _confirmImageSend(bytes);
      if (!confirm) {
        if (mounted) setState(() => _sendingImage = false);
        return;
      }

      final supabase = Supabase.instance.client;
      final storage = supabase.storage.from('chat-images');

      final storageFileName =
          '${widget.conversationId}_${DateTime.now().millisecondsSinceEpoch}_$fileName';

      await storage.uploadBinary(storageFileName, bytes);
      final publicUrl = storage.getPublicUrl(storageFileName);

      // ✅ Mensagem registrada via RPC (sem tabela crua)
      await _chatRepo.sendMessageViaRpc(
        conversationId: widget.conversationId,
        senderRole: widget.currentUserRole,
        content: '',
        type: 'image',
        imageUrl: publicUrl,
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

  // ---------------------------------------------------------------------------
  // PREVIEW FULLSCREEN (para imagens já enviadas)
  // ---------------------------------------------------------------------------
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

  Widget _buildHeaderAvatar() {
    final u = (_headerAvatarUrl ?? '').trim();
    if (u.isEmpty) {
      return const CircleAvatar(
        radius: 14,
        child: Icon(Icons.person, size: 16),
      );
    }
    return CircleAvatar(
      radius: 14,
      backgroundImage: NetworkImage(u),
      onBackgroundImageError: (_, __) {},
      backgroundColor: Colors.white.withOpacity(0.12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerTitle = _headerTitle.isNotEmpty
        ? _headerTitle
        : (widget.jobTitle.isNotEmpty ? widget.jobTitle : 'Chat');

    final headerSubtitle = _headerSubtitle.isNotEmpty
        ? _headerSubtitle
        : (widget.otherUserName.isNotEmpty ? widget.otherUserName : '');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B246B),
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            _buildHeaderAvatar(),
            const SizedBox(width: 8),
            Expanded(
              child: _headerLoading
                  ? const Text(
                      'Carregando...',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ Onde estava "Profissional" -> job_code
                        Text(
                          headerTitle,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                        // ✅ Onde estava "Pedreiro" -> provider/client full_name
                        Text(
                          headerSubtitle,
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
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatRepo.streamMessagesView(
                conversationId: widget.conversationId,
                isClient: _isClient,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

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

                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final senderId = m['sender_id']?.toString();
                    final content = (m['content'] as String?) ?? '';
                    final isMe = senderId == widget.currentUserId;

                    final type = (m['type'] as String?) ?? 'text';
                    final imageUrl = m['image_url'] as String?;
                    final createdStr = m['created_at']?.toString();
                    DateTime? createdAt;
                    if (createdStr != null) {
                      createdAt = DateTime.tryParse(createdStr)?.toLocal();
                    }

                    return _buildBubble(
                      text: content,
                      isMe: isMe,
                      type: type,
                      imageUrl: imageUrl,
                      createdAt: createdAt,
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

  // ---------------------------------------------------------------------------
  // BOLHA
  // ---------------------------------------------------------------------------
  Widget _buildBubble({
    required String text,
    required bool isMe,
    required String type,
    String? imageUrl,
    DateTime? createdAt,
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
      child = Text(text, style: TextStyle(color: textColor, fontSize: 13));
    }

    String timeLabel = '';
    if (createdAt != null) {
      final hh = createdAt.hour.toString().padLeft(2, '0');
      final mm = createdAt.minute.toString().padLeft(2, '0');
      timeLabel = '$hh:$mm';
    }

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
            if (timeLabel.isNotEmpty)
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

  // ---------------------------------------------------------------------------
  // INPUT
  // ---------------------------------------------------------------------------
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
