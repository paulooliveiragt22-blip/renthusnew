import 'package:flutter/material.dart';

const _kGreen = Color(0xFF0DAA00); // sucesso tipo Google

class CreateJobSubmitButton extends StatelessWidget {
  final bool isSubmitting;
  final bool isFormValid;
  final int currentStep; // 0 ou 1
  final VoidCallback onSubmit;

  const CreateJobSubmitButton({
    super.key,
    required this.isSubmitting,
    required this.isFormValid,
    required this.currentStep,
    required this.onSubmit,
  });

  String _label() {
    if (currentStep == 0) return 'Continuar';
    return 'Solicitar pedido';
  }

  @override
  Widget build(BuildContext context) {
    final enabled = isFormValid && !isSubmitting;

    return SizedBox(
      width: double.infinity,
      height: 44, // slim
      child: ElevatedButton(
        onPressed: enabled ? onSubmit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? _kGreen : _kGreen.withOpacity(0.4),
          disabledBackgroundColor: _kGreen.withOpacity(0.3),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                _label(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
