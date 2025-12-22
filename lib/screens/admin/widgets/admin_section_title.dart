import 'package:flutter/material.dart';

class AdminSectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onAction;
  final String? actionLabel;

  const AdminSectionTitle({
    super.key,
    required this.title,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const Spacer(),
        if (onAction != null && actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!,
                style: const TextStyle(color: Color(0xFF3B246B))),
          )
      ],
    );
  }
}
