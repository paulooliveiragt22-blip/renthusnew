import 'package:flutter/material.dart';

class JobCancelSection extends StatelessWidget {

  const JobCancelSection({
    super.key,
    required this.visible,
    required this.isChangingStatus,
    required this.onCancel,
  });
  final bool visible;
  final bool isChangingStatus;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: OutlinedButton.icon(
        onPressed: isChangingStatus ? null : onCancel,
        icon: const Icon(Icons.cancel_outlined),
        label: const Text('Cancelar este serviço'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}
