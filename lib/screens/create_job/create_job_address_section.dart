import 'package:flutter/material.dart';

const _kRoxo = Color(0xFF3B246B);
const _kGrey = Color(0xFF9E9E9E);

class CreateJobAddressSection extends StatelessWidget {

  const CreateJobAddressSection({
    super.key,
    required this.cepController,
    required this.streetController,
    required this.numberController,
    required this.districtController,
    required this.cityController,
    required this.stateController,
    required this.hasProfileAddress,
    required this.useProfileAddress,
    required this.isAddressLoading,
    required this.onSearchCep,
    required this.onSelectAddressMode,
  });
  final TextEditingController cepController;
  final TextEditingController streetController;
  final TextEditingController numberController;
  final TextEditingController districtController;
  final TextEditingController cityController;
  final TextEditingController stateController;

  final bool hasProfileAddress;
  final bool? useProfileAddress;
  final bool isAddressLoading;

  final VoidCallback onSearchCep;
  final ValueChanged<bool> onSelectAddressMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TÍTULO
        const Text(
          'Onde o serviço será realizado *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _kRoxo,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Informe o endereço completo para que os prestadores saibam a distância até você.',
          style: TextStyle(fontSize: 12, color: _kGrey),
        ),

        const SizedBox(height: 16),

        // USAR ENDEREÇO DO PERFIL
        if (hasProfileAddress) ...[
          Row(
            children: [
              Expanded(
                child: _AddressChoice(
                  label: 'Usar endereço do cadastro',
                  selected: useProfileAddress == true,
                  onTap: () => onSelectAddressMode(true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AddressChoice(
                  label: 'Outro endereço',
                  selected: useProfileAddress == false,
                  onTap: () => onSelectAddressMode(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // CEP
        Row(
          children: [
            Expanded(
              child: _Input(
                controller: cepController,
                label: 'CEP',
                hint: '00000-000',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: isAddressLoading ? null : onSearchCep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kRoxo,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isAddressLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Buscar'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // RUA*
        _Input(
          controller: streetController,
          label: 'Rua *',
          hint: 'Ex: Av. Brasil',
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _Input(
                controller: numberController,
                label: 'Número *',
                hint: 'Ex: 123',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Input(
                controller: districtController,
                label: 'Bairro *',
                hint: 'Ex: Centro',
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _Input(
                controller: cityController,
                label: 'Cidade *',
                hint: 'Ex: Sorriso',
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 72,
              child: _Input(
                controller: stateController,
                label: 'UF *',
                hint: 'MT',
                textCapitalization: TextCapitalization.characters,
                maxLength: 2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AddressChoice extends StatelessWidget {

  const _AddressChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF2ECFF) : Colors.white,
          border: Border.all(
            color: selected ? _kRoxo : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? _kRoxo : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {

  const _Input({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.sentences,
    this.maxLength,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      decoration: InputDecoration(
        counterText: '',
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}
