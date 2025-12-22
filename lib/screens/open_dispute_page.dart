import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/job_repository.dart';

import 'package:path/path.dart' as p;

import '../utils/image_utils.dart';

class OpenDisputePage extends StatefulWidget {
  final String jobId;

  const OpenDisputePage({super.key, required this.jobId});

  @override
  State<OpenDisputePage> createState() => _OpenDisputePageState();
}

class _OpenDisputePageState extends State<OpenDisputePage> {
  final supabase = Supabase.instance.client;
  final JobRepository _jobRepo = JobRepository();
  final TextEditingController _descController = TextEditingController();

  bool _isLoading = false;
  final List<XFile> _images = [];
  static const int _maxImages = 5;
  static const int _maxChars = 500;

  /// Prazo desejado pelo cliente para solução do problema
  DateTime? _solutionDeadline;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // IMAGENS
  // ---------------------------------------------------------------------------
  Future<void> _pickImages() async {
    if (_images.length >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Você já selecionou o máximo de $_maxImages fotos.'),
        ),
      );
      return;
    }

    final remaining = _maxImages - _images.length;

    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      imageQuality: 100, // vamos tratar compressão manualmente
    );

    if (picked.isEmpty) return;

    setState(() {
      _images.addAll(picked.take(remaining));
    });

    if (picked.length > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Só é possível enviar $_maxImages fotos por reclamação.'),
        ),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  // ---------------------------------------------------------------------------
  // PRAZO DE SOLUÇÃO
  // ---------------------------------------------------------------------------
  Future<void> _pickSolutionDeadline() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _solutionDeadline ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );

    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _solutionDeadline ?? now.add(const Duration(hours: 24)),
      ),
    );

    final time = pickedTime ?? const TimeOfDay(hour: 23, minute: 59);

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      time.hour,
      time.minute,
    );

    setState(() {
      _solutionDeadline = combined;
    });
  }

  String _solutionDeadlineLabel() {
    if (_solutionDeadline == null) {
      return 'Definir data para solução (opcional)';
    }
    final d = _solutionDeadline!;
    final dia = d.day.toString().padLeft(2, '0');
    final mes = d.month.toString().padLeft(2, '0');
    final ano = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');

    return 'Desejo que o problema seja resolvido até $dia/$mes/$ano às $hh:$mm';
  }

  // ---------------------------------------------------------------------------
  // ENVIAR RECLAMAÇÃO (com compressão + thumb)
  // ---------------------------------------------------------------------------
  Future<void> _submit() async {
    if (_isLoading) return;

    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Descreva o problema antes de enviar a reclamação.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1) cria disputa via JobRepository (já aplica regra de 1 disputa)
      final disputeId = await _jobRepo.openDisputeForCurrentUser(
        jobId: widget.jobId,
        description: _descController.text,
        solutionDeadline: _solutionDeadline,
      );

      // 2) Upload das fotos (se houver), com compressão + thumb
      // 2) Upload das fotos (se houver) com compressão + thumb
      for (final img in _images) {
        final storage = supabase.storage.from('disputes-images');
        final rawBytes = await img.readAsBytes();
        final compressed = await ImageUtils.compressWithThumb(rawBytes);

        String ext = p.extension(img.name);
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
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reclamação enviada! Vamos analisar seu caso e avisaremos pelo app.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Erro ao abrir reclamação: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao abrir reclamação: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final descLength = _descController.text.length;
    final descCounter = '$descLength/$_maxChars';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B246B),
        title: const Text('Abrir reclamação'),
      ),
      body: Column(
        children: [
          // Banner de aviso
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFFFF3E0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.report_problem_outlined,
                    color: Color(0xFFEF6C00), size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Use esta reclamação apenas em casos reais de problema. '
                    'Nossa equipe poderá analisar mensagens, fotos e o histórico do serviço.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF7A4F00),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Conteúdo rolável
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card descrição
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Descreva o que aconteceu',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF3B246B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Explique o que não saiu como combinado: atrasos, qualidade do serviço, atendimento, etc.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _descController,
                          maxLines: 5,
                          maxLength: _maxChars,
                          decoration: const InputDecoration(
                            labelText: 'Detalhes da reclamação',
                            alignLabelWithHint: true,
                            hintText:
                                'Ex.: O profissional não compareceu no horário combinado...',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) {
                            setState(() {}); // atualiza contador
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            descCounter,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Card prazo de solução
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prazo desejado para solução (opcional)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF3B246B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Se quiser, informe até quando você gostaria que o problema estivesse resolvido. '
                          'O prestador verá este prazo ao receber a reclamação.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: _pickSolutionDeadline,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.schedule_outlined,
                                  size: 18,
                                  color: Color(0xFF3B246B),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _solutionDeadlineLabel(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _solutionDeadline == null
                                          ? Colors.black54
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.edit_calendar_outlined,
                                  size: 18,
                                  color: Color(0xFF3B246B),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Card fotos
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fotos do problema (opcional)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF3B246B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Você pode enviar até $_maxImages fotos para ajudar na análise.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (int i = 0; i < _images.length; i++)
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 80,
                                      height: 80,
                                      child: Image.file(
                                        File(_images[i].path),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(i),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(2),
                                        child: const Icon(
                                          Icons.close,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            if (_images.length < _maxImages)
                              InkWell(
                                onTap: _pickImages,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDEDED),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.add_a_photo_outlined,
                                          size: 22, color: Colors.black54),
                                      SizedBox(height: 4),
                                      Text(
                                        'Adicionar',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${_images.length}/$_maxImages fotos',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Rodapé com botão
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.07),
                    blurRadius: 6,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sua reclamação será analisada pela nossa equipe.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B246B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Enviar reclamação',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
