import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PixQrPage extends StatelessWidget {
  final String copyPaste;
  final String? expiresAt;

  // ✅ novo (opcional)
  final String? qrCodeUrl;

  const PixQrPage({
    super.key,
    required this.copyPaste,
    this.expiresAt,
    this.qrCodeUrl,
  });

  @override
  Widget build(BuildContext context) {
    const roxo = Color(0xFF3B246B);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: roxo,
        foregroundColor: Colors.white,
        title: const Text('Pix'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ✅ Conteúdo scrollável (evita overflow em telas menores)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (expiresAt != null && expiresAt!.isNotEmpty) ...[
                      Text(
                        'Expira em: $expiresAt',
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // ✅ mostra imagem do QR se tiver URL
                    if (qrCodeUrl != null && qrCodeUrl!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Image.network(
                            qrCodeUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text(
                                'Não foi possível carregar o QR Code.\nUse o copia e cola abaixo.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                  child: CircularProgressIndicator());
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const Text(
                      'Copia e cola',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: roxo,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SelectableText(
                        copyPaste,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),

                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: copyPaste));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pix copiado!')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: roxo,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      icon: const Icon(Icons.copy, color: Colors.white),
                      label: const Text(
                        'Copiar código Pix',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    // ✅ espaço final dentro do scroll (respira melhor)
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ✅ Rodapé “fixo” com safe area (evita encostar na barra do Android)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: roxo,
                    side: const BorderSide(color: roxo),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Voltar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
