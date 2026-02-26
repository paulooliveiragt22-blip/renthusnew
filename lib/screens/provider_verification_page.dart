import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:renthus/core/providers/supabase_provider.dart';
import 'package:renthus/core/utils/error_handler.dart';
import 'package:renthus/features/jobs/data/providers/job_providers.dart';

const _kRoxo = Color(0xFF3B246B);
const _kGreen = Color(0xFF0DAA00);


final _imagePicker = ImagePicker();

class _CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length && i < 11; i++) {
      if (i == 3 || i == 6) buf.write('.');
      if (i == 9) buf.write('-');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _CepInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length && i < 8; i++) {
      if (i == 5) buf.write('-');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class ProviderVerificationPage extends ConsumerStatefulWidget {
  const ProviderVerificationPage({super.key});

  @override
  ConsumerState<ProviderVerificationPage> createState() =>
      _ProviderVerificationPageState();
}

class _ProviderVerificationPageState
    extends ConsumerState<ProviderVerificationPage> {
  int _currentStep = 0;
  bool _submitting = false;
  late final PageController _pageController;

  final _step0FormKey = GlobalKey<FormState>();
  final _step1FormKey = GlobalKey<FormState>();

  // Step 0 controllers
  final _cpfCtrl = TextEditingController();
  final _motherNameCtrl = TextEditingController();
  final _professionCtrl = TextEditingController();
  final _cepCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _complementCtrl = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  DateTime? _birthdate;
  int? _monthlyIncome;
  String _documentType = 'rg';
  File? _frontFile;
  File? _backFile;
  File? _selfieFile;

  // Step 1 controllers
  final _holderNameCtrl = TextEditingController();
  final _agencyCtrl = TextEditingController();
  final _agencyDigitCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _accountDigitCtrl = TextEditingController();
  String? _selectedBank;
  String _accountType = 'checking';

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final me = ref.read(providerMeProvider).valueOrNull;
      if (me != null) {
        final name = (me['full_name'] as String?) ?? '';
        if (_holderNameCtrl.text.isEmpty && name.isNotEmpty) {
          _holderNameCtrl.text = name;
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cpfCtrl.dispose();
    _motherNameCtrl.dispose();
    _professionCtrl.dispose();
    _cepCtrl.dispose();
    _streetCtrl.dispose();
    _numberCtrl.dispose();
    _complementCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _referenceCtrl.dispose();
    _holderNameCtrl.dispose();
    _agencyCtrl.dispose();
    _agencyDigitCtrl.dispose();
    _accountNumberCtrl.dispose();
    _accountDigitCtrl.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _pickImage(void Function(File) onPicked) async {
    final xFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (xFile != null) onPicked(File(xFile.path));
  }

  String get _providerId =>
      ref.read(providerMeProvider).valueOrNull?['provider_id']?.toString() ??
      '';

  Future<void> _submitStep0() async {
    if (!_step0FormKey.currentState!.validate()) return;
    if (_frontFile == null || _backFile == null || _selfieFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Envie todas as fotos dos documentos e a selfie.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final pid = _providerId;
      if (pid.isEmpty) throw Exception('Provider não encontrado.');

      final bucket = supabase.storage.from('provider-documents');

      await bucket.upload(
        '$pid/doc_front.jpg',
        _frontFile!,
        fileOptions: const FileOptions(upsert: true),
      );
      await bucket.upload(
        '$pid/doc_back.jpg',
        _backFile!,
        fileOptions: const FileOptions(upsert: true),
      );
      await bucket.upload(
        '$pid/selfie.jpg',
        _selfieFile!,
        fileOptions: const FileOptions(upsert: true),
      );

      final frontUrl = bucket.getPublicUrl('$pid/doc_front.jpg');
      final backUrl = bucket.getPublicUrl('$pid/doc_back.jpg');
      final selfieUrl = bucket.getPublicUrl('$pid/selfie.jpg');

      await supabase.rpc('submit_provider_verification_documents', params: {
        'p_cpf': _cpfCtrl.text.replaceAll(RegExp(r'\D'), ''),
        'p_document_type': _documentType,
        'p_document_front_url': frontUrl,
        'p_document_back_url': backUrl,
        'p_selfie_url': selfieUrl,
        'p_mother_name': _motherNameCtrl.text.trim(),
        'p_birthdate': _birthdate?.toIso8601String().split('T').first,
        'p_monthly_income': _monthlyIncome,
        'p_professional_occupation': _professionCtrl.text.trim(),
        'p_address_street': _streetCtrl.text.trim(),
        'p_address_number': _numberCtrl.text.trim(),
        'p_address_complement': _complementCtrl.text.trim().isEmpty
            ? 'SN'
            : _complementCtrl.text.trim(),
        'p_address_district': _neighborhoodCtrl.text.trim(),
        'p_address_zip_code': _cepCtrl.text.replaceAll(RegExp(r'\D'), ''),
        'p_address_reference': _referenceCtrl.text.trim().isEmpty
            ? 'Próximo ao centro'
            : _referenceCtrl.text.trim(),
      });

      _goToStep(1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.friendlyErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitStep1() async {
    if (!_step1FormKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final pid = _providerId;
      if (pid.isEmpty) throw Exception('Provider não encontrado.');

      await supabase.rpc('submit_provider_bank_data', params: {
        'p_bank_code': _selectedBank,
        'p_bank_branch_number': _agencyCtrl.text.trim(),
        'p_bank_branch_check_digit': _agencyDigitCtrl.text.trim(),
        'p_bank_account_number': _accountNumberCtrl.text.trim(),
        'p_bank_account_check_digit': _accountDigitCtrl.text.trim(),
        'p_bank_account_type': _accountType,
        'p_bank_holder_name': _holderNameCtrl.text.trim(),
      });

      _goToStep(2);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.friendlyErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ───────────── BUILD ─────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificação da conta'),
        backgroundColor: _kRoxo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep0(),
                _buildStep1(),
                _buildStep2(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────── STEP INDICATOR ─────────────

  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
      child: Row(
        children: [
          _buildStepCircle(0),
          Expanded(child: _buildStepLine(0)),
          _buildStepCircle(1),
          Expanded(child: _buildStepLine(1)),
          _buildStepCircle(2),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step) {
    final isCompleted = step < _currentStep;
    final isCurrent = step == _currentStep;

    Color bg;
    Widget child;
    if (isCompleted) {
      bg = _kGreen;
      child = const Icon(Icons.check, color: Colors.white, size: 18);
    } else if (isCurrent) {
      bg = _kRoxo;
      child = Text(
        '${step + 1}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      );
    } else {
      bg = Colors.grey.shade300;
      child = Text(
        '${step + 1}',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      );
    }

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _buildStepLine(int afterStep) {
    final filled = _currentStep > afterStep;
    return Container(
      height: 3,
      color: filled ? _kGreen : Colors.grey.shade300,
    );
  }

  // ───────────── STEP 0 ─────────────

  Widget _buildStep0() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _step0FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Dados pessoais'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cpfCtrl,
              decoration: const InputDecoration(
                labelText: 'CPF',
                hintText: '000.000.000-00',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _CpfInputFormatter(),
              ],
              validator: (v) =>
                  (v == null || v.length < 14) ? 'CPF inválido' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _motherNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome da mãe',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate:
                      _birthdate ?? DateTime(now.year - 25, now.month, now.day),
                  firstDate: DateTime(1940),
                  lastDate: DateTime(now.year - 18, now.month, now.day),
                  locale: const Locale('pt', 'BR'),
                );
                if (picked != null) setState(() => _birthdate = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data de nascimento',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  _birthdate != null
                      ? '${_birthdate!.day.toString().padLeft(2, '0')}/'
                          '${_birthdate!.month.toString().padLeft(2, '0')}/'
                          '${_birthdate!.year}'
                      : '',
                  style: TextStyle(
                    color: _birthdate != null
                        ? Colors.black87
                        : Colors.grey.shade500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              value: _monthlyIncome,
              decoration: const InputDecoration(
                labelText: 'Renda mensal estimada',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 100000, child: Text('Até R\$ 1.000')),
                DropdownMenuItem(
                    value: 300000, child: Text('R\$ 1.000 a R\$ 3.000')),
                DropdownMenuItem(
                    value: 500000, child: Text('R\$ 3.000 a R\$ 5.000')),
                DropdownMenuItem(
                    value: 1000000, child: Text('R\$ 5.000 a R\$ 10.000')),
                DropdownMenuItem(
                    value: 1500000, child: Text('Acima de R\$ 10.000')),
              ],
              onChanged: (v) => setState(() => _monthlyIncome = v),
              validator: (v) => v == null ? 'Selecione uma faixa' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _professionCtrl,
              decoration: const InputDecoration(
                labelText: 'Profissão / Ocupação',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
            ),
            const SizedBox(height: 28),

            // Endereço
            _sectionTitle('Endereço'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cepCtrl,
              decoration: InputDecoration(
                labelText: 'CEP',
                hintText: '00000-000',
                border: const OutlineInputBorder(),
                suffixIcon: TextButton(
                  onPressed: () {},
                  child: const Text('Buscar'),
                ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _CepInputFormatter(),
              ],
              validator: (v) =>
                  (v == null || v.length < 9) ? 'CEP inválido' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _streetCtrl,
              decoration: const InputDecoration(
                labelText: 'Rua',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _numberCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Número',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Obrigatório'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _complementCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Complemento',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _neighborhoodCtrl,
              decoration: const InputDecoration(
                labelText: 'Bairro',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _referenceCtrl,
              decoration: const InputDecoration(
                labelText: 'Ponto de referência',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
            ),
            const SizedBox(height: 28),

            // Documentos
            _sectionTitle('Documentos de identificação'),
            const SizedBox(height: 12),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('RG'),
                  selected: _documentType == 'rg',
                  selectedColor: _kRoxo.withOpacity(0.15),
                  onSelected: (_) =>
                      setState(() => _documentType = 'rg'),
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text('CNH'),
                  selected: _documentType == 'cnh',
                  selectedColor: _kRoxo.withOpacity(0.15),
                  onSelected: (_) =>
                      setState(() => _documentType = 'cnh'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildPhotoSelector(
              label: 'Foto da frente',
              file: _frontFile,
              onTap: () => _pickImage((f) => setState(() => _frontFile = f)),
            ),
            const SizedBox(height: 14),
            _buildPhotoSelector(
              label: 'Foto do verso',
              file: _backFile,
              onTap: () => _pickImage((f) => setState(() => _backFile = f)),
            ),
            const SizedBox(height: 14),
            _buildPhotoSelector(
              label: 'Selfie segurando o documento',
              hint: 'Segure o documento ao lado do rosto',
              file: _selfieFile,
              onTap: () => _pickImage((f) => setState(() => _selfieFile = f)),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submitStep0,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kRoxo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Próximo',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ───────────── STEP 1 ─────────────

  Widget _buildStep1() {
    const banks = <String, String>{
      '001': 'Banco do Brasil',
      '033': 'Santander',
      '104': 'Caixa Econômica',
      '237': 'Bradesco',
      '341': 'Itaú Unibanco',
      '260': 'Nubank',
      '077': 'Banco Inter',
      '336': 'C6 Bank',
      '290': 'PagBank',
      '380': 'PicPay',
      '403': 'Cora',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _step1FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Dados bancários'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _holderNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Titular da conta',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _selectedBank,
              decoration: const InputDecoration(
                labelText: 'Banco',
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              items: banks.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text('${e.key} – ${e.value}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedBank = v),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Selecione o banco' : null,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _agencyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Agência',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                    validator: (v) => (v == null || v.length < 4)
                        ? 'Mínimo 4 dígitos'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _agencyDigitCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dígito',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(1),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _accountNumberCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Número da conta',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Campo obrigatório'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _accountDigitCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dígito',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(1),
                    ],
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Obrigatório'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Corrente'),
                  selected: _accountType == 'checking',
                  selectedColor: _kRoxo.withOpacity(0.15),
                  onSelected: (_) =>
                      setState(() => _accountType = 'checking'),
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text('Poupança'),
                  selected: _accountType == 'savings',
                  selectedColor: _kRoxo.withOpacity(0.15),
                  onSelected: (_) =>
                      setState(() => _accountType = 'savings'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3EEFF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline, size: 20, color: _kRoxo),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Seus dados bancários são usados exclusivamente para '
                      'transferir os pagamentos dos serviços que você realizar.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submitStep1,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kRoxo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Enviar para análise',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ───────────── STEP 2 ─────────────

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF3EEFF),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.hourglass_top_rounded,
              size: 64,
              color: _kRoxo,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Enviado para análise!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _kRoxo,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Seus documentos e dados bancários foram recebidos. '
            'A análise costuma levar até 24 horas úteis.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
            color: Colors.grey.shade50,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _timelineRow('✅', 'Dados pessoais enviados'),
                  _timelineDivider(),
                  _timelineRow('✅', 'Documentos enviados'),
                  _timelineDivider(),
                  _timelineRow('✅', 'Dados bancários enviados'),
                  _timelineDivider(),
                  _timelineRow('🔄', 'Análise em andamento'),
                  _timelineDivider(),
                  _timelineRow('⬜', 'Conta ativada'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => context.go('/provider'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kRoxo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Voltar ao início',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────── HELPERS ─────────────

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: _kRoxo,
      ),
    );
  }

  Widget _buildPhotoSelector({
    required String label,
    String? hint,
    required File? file,
    required VoidCallback onTap,
  }) {
    if (file != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              file,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onTap,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    'Trocar',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade400,
            style: BorderStyle.solid,
          ),
          color: Colors.grey.shade50,
        ),
        child: CustomPaint(
          painter: _DashedBorderPainter(color: Colors.grey.shade400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined,
                  size: 32, color: Colors.grey.shade500),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 4),
                Text(
                  hint,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _timelineRow(String emoji, String text) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _timelineDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 9),
      child: Container(
        width: 2,
        height: 20,
        color: Colors.grey.shade300,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final rRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );

    final path = Path()..addRRect(rRect);
    final metrics = path.computeMetrics().first;
    double distance = 0;
    while (distance < metrics.length) {
      final next = distance + dashWidth;
      canvas.drawPath(
        metrics.extractPath(distance, next.clamp(0, metrics.length)),
        paint,
      );
      distance = next + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color;
}
