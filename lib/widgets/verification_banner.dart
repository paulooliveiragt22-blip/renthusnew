import 'package:flutter/material.dart';

const _kRoxo = Color(0xFF3B246B);
const _kLaranja = Color(0xFFFF6600);

class VerificationBanner extends StatelessWidget {
  final String verificationStatus;
  final VoidCallback onTap;

  const VerificationBanner({
    super.key,
    required this.verificationStatus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    switch (verificationStatus) {
      case 'pending':
      case 'rejected':
        return _buildActionBanner();
      case 'documents_submitted':
        return _buildInfoBanner();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActionBanner() {
    final isPending = verificationStatus == 'pending';
    final backgroundColor =
        isPending ? const Color(0xFFFFF3E0) : const Color(0xFFFFEBEE);
    final message = isPending
        ? 'Complete sua verificação para receber pedidos'
        : 'Seus documentos foram recusados. Toque para reenviar.';

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: _kLaranja, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
              TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Completar →',
                  style: TextStyle(color: _kRoxo, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.hourglass_top_rounded, color: _kRoxo, size: 24),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Seus documentos estão em análise. Avisaremos quando aprovados.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
