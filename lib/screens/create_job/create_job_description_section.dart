import 'package:flutter/material.dart';

const kRoxo = Color(0xFF3B246B);
const kLaranja = Color(0xFFFF6600);

class CreateJobDescriptionSection extends StatelessWidget {
  final TextEditingController controller;
  final int maxLength;
  final ValueChanged<String>? onChanged;

  const CreateJobDescriptionSection({
    super.key,
    required this.controller,
    required this.maxLength,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Descreva melhor o serviço (mínimo de 30 caracteres)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: kLaranja,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          maxLength: maxLength,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText:
                'Conte detalhes do local, tamanho do ambiente, o que precisa ser feito...',
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(18)),
              borderSide: BorderSide(
                color: kRoxo,
                width: 1.4,
              ),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }
}
