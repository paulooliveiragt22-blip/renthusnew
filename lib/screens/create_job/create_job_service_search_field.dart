import 'package:flutter/material.dart';

const kRoxo = Color(0xFF3B246B);

class CreateJobServiceSearchField extends StatelessWidget {

  const CreateJobServiceSearchField({
    super.key,
    required this.controller,
    required this.isSearching,
    required this.onSearchPressed,
  });
  final TextEditingController controller;
  final bool isSearching;
  final VoidCallback onSearchPressed;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 1,
      maxLines: 2,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: 'O que você precisa para hoje?',
        labelStyle: const TextStyle(fontSize: 13),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(999)),
          borderSide: BorderSide(
            color: kRoxo,
            width: 1.4,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 8,
        ),
        suffixIcon: IconButton(
          icon: isSearching
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kRoxo,
                  ),
                )
              : const Icon(Icons.search, color: kRoxo),
          onPressed: onSearchPressed,
        ),
      ),
    );
  }
}
