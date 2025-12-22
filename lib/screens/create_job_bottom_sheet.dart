// lib/screens/create_job_bottom_sheet.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/job_repository.dart';
import '../widgets/renthus_center_message.dart';

// Widgets auxiliares da pasta create_job
import 'create_job/create_job_service_search_field.dart';
import 'create_job/create_job_suggested_services_section.dart';
import 'create_job/create_job_description_section.dart';
import 'create_job/create_job_address_section.dart';
import 'create_job/create_job_photos_section.dart';
import 'create_job/create_job_submit_button.dart';

// Cores padrão do app
const kRoxo = Color(0xFF3B246B);
const kLaranja = Color(0xFFFF6600);
const kGreen = Color(0xFF0DAA00);

class CreateJobBottomSheet extends StatefulWidget {
  final String? initialServiceSuggestion;

  const CreateJobBottomSheet({
    super.key,
    this.initialServiceSuggestion,
  });

  @override
  State<CreateJobBottomSheet> createState() => _CreateJobBottomSheetState();
}

class _CreateJobBottomSheetState extends State<CreateJobBottomSheet> {
  final _supabase = Supabase.instance.client;
  final JobRepository _jobRepository = JobRepository();

  final _searchController = TextEditingController();
  final _detailsController = TextEditingController();

  final _cepController = TextEditingController();
  final _streetController = TextEditingController();
  final _numberController = TextEditingController();
  final _districtController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();

  double? _lat;
  double? _lng;
  bool _isGeocoding = false;

  bool _isSearching = false;
  bool _isSubmitting = false;
  bool _isAddressLoading = false;

  int _currentStep = 0;

  Map<String, dynamic>? _clientAddressFromProfile;
  bool? _useProfileAddress;

  List<String> _suggestedProfessionals = [];
  String? _selectedProfessional;
  String? _autoSuggestedProfessional;
  bool _showSuggestedHelperText = false;
  bool _hasUserSelectedProfessional = false;

  Map<String, String> _professionalToServiceTypeId = {};
  Map<String, String> _professionalToCategoryId = {};

  static const int _maxImages = 3;
  final List<XFile> _selectedImages = [];
  final _imagePicker = ImagePicker();

  static const int _minDescriptionLength = 30;
  static const int _maxDescriptionLength = 800;

  @override
  void initState() {
    super.initState();

    final suggestion = widget.initialServiceSuggestion;
    if (suggestion != null && suggestion.trim().isNotEmpty) {
      _searchController.text = suggestion;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        setState(() => _isSearching = true);
        await _analyzeAndSuggestProfessionals();
      });
    }

    _loadClientAddress();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _detailsController.dispose();

    _cepController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _stateController.dispose();

    super.dispose();
  }

  bool get _hasValidAddressFields {
    return _streetController.text.trim().isNotEmpty &&
        _numberController.text.trim().isNotEmpty &&
        _districtController.text.trim().isNotEmpty &&
        _cityController.text.trim().isNotEmpty;
  }

  bool get _hasChosenAddressMode {
    if (_clientAddressFromProfile == null) return true;
    return _useProfileAddress != null;
  }

  bool get _isFormValid {
    if (_currentStep == 0) {
      final hasService = _selectedProfessional != null;
      final descLen = _detailsController.text.trim().length;
      final descOk = descLen >= _minDescriptionLength;
      return hasService && descOk;
    }
    return _hasChosenAddressMode && _hasValidAddressFields;
  }

  void _showMessage(String message) {
    RenthusCenterMessage.show(context, message);
  }

  void _goToStep(int step) {
    if (step < 0 || step > 1) return;
    setState(() => _currentStep = step);
  }

  void _onStepTapped(int step) {
    if (step <= _currentStep) _goToStep(step);
  }

  Future<void> _onPrimaryButtonPressed() async {
    if (_isSubmitting) return;

    if (_currentStep == 0) {
      if (_validateStep1()) {
        _goToStep(1);
      } else {
        _goToStep(0);
      }
      return;
    }

    await _submit();
  }

  // ==================== ENDEREÇO / PERFIL ====================

  Future<void> _loadClientAddress() async {
    setState(() => _isAddressLoading = true);

    try {
      final res = await _jobRepository.getMyClientProfileAddress();
      if (!mounted) return;

      if (res != null) {
        _clientAddressFromProfile = Map<String, dynamic>.from(res);

        _cepController.text =
            (_clientAddressFromProfile?['address_zip_code'] ?? '').toString();
        _streetController.text =
            (_clientAddressFromProfile?['address_street'] ?? '').toString();
        _numberController.text =
            (_clientAddressFromProfile?['address_number'] ?? '').toString();
        _districtController.text =
            (_clientAddressFromProfile?['address_district'] ?? '').toString();
        _cityController.text =
            (_clientAddressFromProfile?['city'] ?? '').toString();
        _stateController.text =
            (_clientAddressFromProfile?['address_state'] ?? '').toString();

        _useProfileAddress = null;
      }
    } catch (e) {
      debugPrint('Erro ao carregar endereço do cliente: $e');
    } finally {
      if (mounted) setState(() => _isAddressLoading = false);
    }
  }

  /// Tenta resolver lat/lng, mas **NÃO bloqueia** o envio se falhar (MODELO B).
  Future<bool> _resolveLatLng() async {
    // se já tem, ok
    if (_lat != null && _lng != null) return true;

    final address = [
      _streetController.text,
      _numberController.text,
      _districtController.text,
      _cityController.text,
      _stateController.text,
    ].where((e) => e.trim().isNotEmpty).join(', ');

    if (address.isEmpty) return false;

    setState(() => _isGeocoding = true);

    try {
      final res = await Supabase.instance.client.functions.invoke(
        'geocode-address',
        body: {'query': address},
      );

      final data = res.data as Map?;
      final found = data?['found'] == true;

      if (!found) {
        if (mounted) {
          setState(() {
            _lat = null;
            _lng = null;
          });
        }
        return false;
      }

      final lat = (data?['lat'] as num?)?.toDouble();
      final lng = (data?['lng'] as num?)?.toDouble();

      if (lat == null || lng == null) return false;

      _lat = lat;
      _lng = lng;
      return true;
    } on FunctionException catch (err) {
      debugPrint(
        'Geocode FunctionException: status=${err.status} details=${err.details}',
      );
      return false;
    } catch (err) {
      debugPrint('Erro ao geocodificar endereço: $err');
      return false;
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  Future<void> _searchCep() async {
    final raw = _cepController.text;
    final cep = raw.replaceAll(RegExp(r'[^0-9]'), '');

    if (cep.length != 8) {
      _showMessage('Digite um CEP válido (8 dígitos).');
      return;
    }

    setState(() => _isAddressLoading = true);

    try {
      final url = Uri.parse('https://viacep.com.br/ws/$cep/json/');
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(url);
      final response = await request.close();
      final body = await response.transform(const Utf8Decoder()).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      if (data['erro'] == true) throw Exception('CEP não encontrado');

      setState(() {
        _streetController.text = (data['logradouro'] ?? '').toString();
        _districtController.text = (data['bairro'] ?? '').toString();
        _cityController.text = (data['localidade'] ?? '').toString();
        _stateController.text = (data['uf'] ?? '').toString();

        // quando muda endereço, zera lat/lng pra tentar de novo no submit
        _lat = null;
        _lng = null;
      });
    } catch (e) {
      debugPrint('Erro ao buscar CEP: $e');
      _showMessage('Erro ao buscar CEP. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isAddressLoading = false);
    }
  }

  // ==================== SUGESTÃO DE SERVIÇOS ====================

  int _searchSeq = 0;

  Future<void> _analyzeAndSuggestProfessionals() async {
    final int seq = ++_searchSeq;

    final text = _searchController.text.trim();
    final lowerText = text.toLowerCase();

    if (text.isEmpty) {
      if (mounted) setState(() => _isSearching = false);
      return;
    }

    // ✅ tokens mais enxutos (sem mudar ideia)
    final tokens = lowerText
        .split(RegExp(r'\s+'))
        .map((t) => t.trim())
        .where((t) => t.length >= 3)
        .toSet()
        .toList();

    // limita tokens para não explodir OR
    if (tokens.length > 4) {
      tokens.removeRange(4, tokens.length);
    }

    // mantém sua regra do "foto"
    if (tokens.any((t) => t.startsWith('foto'))) {
      if (!tokens.contains('foto')) tokens.add('foto');
    }

    try {
      final List<String> conditions = [];

      // ✅ texto completo ainda procura em name + description
      conditions.add('name.ilike.%$text%');
      conditions.add('description.ilike.%$text%');

      // ✅ tokens só em name (bem mais leve)
      for (final token in tokens) {
        conditions.add('name.ilike.%$token%');
      }

      final orFilter = conditions.join(',');

      // ✅ busca enxuta: sem description no retorno
      final subRes = await _supabase
          .from('v_service_types_search')
          .select('id, name, category_id')
          .or(orFilter)
          .limit(12);

      // se outra busca começou depois, ignora esta resposta
      if (!mounted || seq != _searchSeq) return;

      final Map<String, String> mapSub = {};
      final Map<String, String> mapCat = {};

      for (final row in subRes as List<dynamic>) {
        final data = row as Map<String, dynamic>;
        final id = data['id'] as String?;
        final name = data['name'] as String?;
        final categoryId = data['category_id'] as String?;
        if (id == null || name == null || categoryId == null) continue;

        mapSub[name] = id;
        mapCat[name] = categoryId;
      }

      // fallback igual ao seu, mas também enxuto
      if (mapSub.isEmpty) {
        final fallback = await _supabase
            .from('v_service_types_public')
            .select('id, name, category_id')
            .eq('is_active', true)
            .order('name')
            .limit(10);

        if (!mounted || seq != _searchSeq) return;

        for (final row in fallback as List<dynamic>) {
          final data = row as Map<String, dynamic>;
          final id = data['id'] as String?;
          final name = data['name'] as String?;
          final categoryId = data['category_id'] as String?;
          if (id == null || name == null || categoryId == null) continue;

          mapSub[name] = id;
          mapCat[name] = categoryId;
        }
      }

      // ✅ não derruba a seleção do usuário se ele já escolheu algo
      final prevSelected = _selectedProfessional;

      setState(() {
        _professionalToServiceTypeId = mapSub;
        _professionalToCategoryId = mapCat;
        _suggestedProfessionals = mapSub.keys.toList();

        if (_hasUserSelectedProfessional && prevSelected != null) {
          // mantém seleção se ainda existe
          _selectedProfessional = _suggestedProfessionals.contains(prevSelected)
              ? prevSelected
              : null;
        } else {
          _selectedProfessional = null;
        }

        _autoSuggestedProfessional = _suggestedProfessionals.isNotEmpty
            ? _suggestedProfessionals.first
            : null;

        _showSuggestedHelperText = _suggestedProfessionals.isNotEmpty;
      });
    } catch (e, st) {
      debugPrint('Erro ao buscar service types: $e\n$st');
      if (!mounted || seq != _searchSeq) return;
      _showMessage('Erro ao buscar serviços. Tente novamente.');
    } finally {
      if (mounted && seq == _searchSeq) setState(() => _isSearching = false);
    }
  }

  String? _getServiceTypeIdForProfessional(String? professional) {
    if (professional == null) return null;
    return _professionalToServiceTypeId[professional];
  }

  String? _getCategoryIdForProfessional(String? professional) {
    if (professional == null) return null;
    return _professionalToCategoryId[professional];
  }

  // ==================== FOTOS ====================

  Future<void> _pickImages() async {
    final images = await _imagePicker.pickMultiImage();
    if (images.isEmpty) return;

    setState(() {
      _selectedImages.addAll(images);
      if (_selectedImages.length > _maxImages) {
        _selectedImages.removeRange(_maxImages, _selectedImages.length);
      }
    });

    if (_selectedImages.length >= _maxImages) {
      _showMessage('Limite de $_maxImages fotos por pedido.');
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  // ==================== VALIDAÇÕES ====================

  bool _validateStep1() {
    if (_selectedProfessional == null) {
      _showMessage('Selecione um serviço.');
      return false;
    }

    final rawDesc = _detailsController.text.trim();
    if (rawDesc.length < _minDescriptionLength) {
      _showMessage(
        'Descreva melhor o serviço (mínimo $_minDescriptionLength caracteres).',
      );
      return false;
    }
    if (rawDesc.length > _maxDescriptionLength) {
      _showMessage(
        'Descrição muito longa (máximo $_maxDescriptionLength caracteres).',
      );
      return false;
    }

    return true;
  }

  bool _validateStep2() {
    if (!_hasChosenAddressMode) {
      _showMessage(
        'Escolha se vai usar o endereço do cadastro ou informar outro endereço.',
      );
      return false;
    }

    if (!_hasValidAddressFields) {
      _showMessage('Informe o endereço (rua, número, bairro e cidade).');
      return false;
    }

    return true;
  }

  // ==================== SUBMIT ====================

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (!_validateStep1()) {
      _goToStep(0);
      return;
    }
    if (!_validateStep2()) {
      _goToStep(1);
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      _showMessage('Faça login novamente.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final serviceTypeId =
          _getServiceTypeIdForProfessional(_selectedProfessional);
      final categoryId = _getCategoryIdForProfessional(_selectedProfessional);

      if (serviceTypeId == null || categoryId == null) {
        _showMessage(
          'Não foi possível identificar o tipo de serviço/categoria. Selecione novamente.',
        );
        return;
      }

      final detected = _selectedProfessional ?? '';

      String title = detected.isNotEmpty ? detected : 'Orçamento';
      if (title.length > 80) title = '${title.substring(0, 77)}...';

      final description = _detailsController.text.trim();

      final street = _streetController.text.trim();
      final number = _numberController.text.trim();
      final district = _districtController.text.trim();
      final city = _cityController.text.trim();
      final state = _stateController.text.trim();

      final cepText = _cepController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final String? zipcode =
          (cepText.isNotEmpty && cepText.length == 8) ? cepText : null;

      // MODELO B: tenta geocode, mas não bloqueia se falhar
      final resolved = await _resolveLatLng();
      if (!resolved) {
        // deixa null mesmo (RPC ajustada vai aceitar)
        _lat = null;
        _lng = null;

        // opcional: mensagem suave (não bloqueia)
        _showMessage(
          'Não conseguimos localizar o endereço no mapa agora. '
          'Seu pedido será enviado mesmo assim.',
        );
      }

      // ✅ RPC create_job (lat/lng agora podem ser null)
      final jobId = await _jobRepository.createJobViaRpc(
        serviceTypeId: serviceTypeId,
        categoryId: categoryId,
        title: title,
        description: description,
        serviceDetected: detected,
        street: street,
        number: number,
        district: district,
        city: city,
        state: state,
        zipcode: zipcode,
        lat: _lat,
        lng: _lng,
      );

      // ✅ Fotos: storage + RPC add_job_photo
      if (_selectedImages.isNotEmpty) {
        try {
          await _jobRepository.uploadJobPhotos(
            jobId: jobId,
            files: _selectedImages.map((x) => File(x.path)).toList(),
          );
        } catch (e, st) {
          debugPrint('Erro ao enviar fotos do job: $e\n$st');
        }
      }

      if (!mounted) return;

      _showMessage('Pedido enviado com sucesso!');
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) Navigator.of(context).pop(jobId);
      });
    } catch (e, st) {
      debugPrint('Erro ao criar pedido: $e\n$st');
      if (!mounted) return;
      _showMessage('Erro ao criar pedido. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ==================== UI / BUILD ====================

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final hasProfileAddress = _clientAddressFromProfile != null;

    final stepContent =
        _currentStep == 0 ? _buildStep1() : _buildStep2(hasProfileAddress);
    final int buttonStep = (_currentStep == 0) ? 0 : 2;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxSheetHeight = mediaQuery.size.height * 0.9;
              final available = constraints.maxHeight;
              final sheetHeight =
                  available > maxSheetHeight ? maxSheetHeight : available;

              return Container(
                height: sheetHeight,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: Column(
                    children: [
                      _TwoStepHeader(
                        currentStep: _currentStep,
                        onStepTap: _onStepTapped,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...stepContent,
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: CreateJobSubmitButton(
                          isSubmitting: _isSubmitting,
                          isFormValid: _isFormValid,
                          currentStep: buttonStep,
                          onSubmit: _onPrimaryButtonPressed,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------- CONTEÚDO DAS ETAPAS ----------

  List<Widget> _buildStep1() {
    return [
      const Text(
        'Serviço *',
        style:
            TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kRoxo),
      ),
      const SizedBox(height: 8),
      CreateJobServiceSearchField(
        controller: _searchController,
        isSearching: _isSearching,
        onSearchPressed: () async {
          if (_searchController.text.trim().isEmpty) {
            _showMessage(
              'Descreva rapidamente o que você precisa ou o serviço específico.',
            );
            return;
          }
          setState(() => _isSearching = true);
          await _analyzeAndSuggestProfessionals();
        },
      ),
      CreateJobSuggestedServicesSection(
        suggestedProfessionals: _suggestedProfessionals,
        selectedProfessional: _selectedProfessional,
        autoSuggestedProfessional: _autoSuggestedProfessional,
        showSuggestedHelperText: _showSuggestedHelperText,
        hasUserSelectedProfessional: _hasUserSelectedProfessional,
        onSelectProfessional: (prof) {
          setState(() {
            _selectedProfessional = prof;
            _hasUserSelectedProfessional = prof != null;
          });
        },
      ),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F2FF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'Dica: informe na descrição quando você precisa do serviço (ex: hoje, amanhã, final de semana).',
          style: TextStyle(fontSize: 12, color: Colors.black87),
        ),
      ),
      const SizedBox(height: 14),
      const Text(
        'Descrição do serviço *',
        style:
            TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kRoxo),
      ),
      const SizedBox(height: 8),
      CreateJobDescriptionSection(
        controller: _detailsController,
        maxLength: _maxDescriptionLength,
        onChanged: (_) => setState(() {}),
      ),
    ];
  }

  List<Widget> _buildStep2(bool hasProfileAddress) {
    return [
      const Text(
        'Onde o serviço será feito *',
        style:
            TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kRoxo),
      ),
      const SizedBox(height: 8),
      CreateJobAddressSection(
        cepController: _cepController,
        streetController: _streetController,
        numberController: _numberController,
        districtController: _districtController,
        cityController: _cityController,
        stateController: _stateController,
        hasProfileAddress: hasProfileAddress,
        useProfileAddress: _useProfileAddress,
        isAddressLoading: _isAddressLoading,
        onSearchCep: _searchCep,
        onSelectAddressMode: (useProfile) {
          setState(() {
            _useProfileAddress = useProfile;

            // trocou endereço -> zera lat/lng pra tentar geocode novo depois
            _lat = null;
            _lng = null;

            if (useProfile && _clientAddressFromProfile != null) {
              _cepController.text =
                  (_clientAddressFromProfile?['address_zip_code'] ?? '')
                      .toString();
              _streetController.text =
                  (_clientAddressFromProfile?['address_street'] ?? '')
                      .toString();
              _numberController.text =
                  (_clientAddressFromProfile?['address_number'] ?? '')
                      .toString();
              _districtController.text =
                  (_clientAddressFromProfile?['address_district'] ?? '')
                      .toString();
              _cityController.text =
                  (_clientAddressFromProfile?['city'] ?? '').toString();
              _stateController.text =
                  (_clientAddressFromProfile?['address_state'] ?? '')
                      .toString();
            }
          });
        },
      ),
      const SizedBox(height: 12),
      CreateJobPhotosSection(
        photos: _selectedImages,
        onAddPhoto: _pickImages,
        onRemovePhoto: _removeImage,
      ),
      if (_selectedImages.length >= _maxImages)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'Limite de 3 fotos por pedido.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
    ];
  }
}

// ============================================================================
// HEADER 2 ETAPAS
// ============================================================================
class _TwoStepHeader extends StatelessWidget {
  final int currentStep; // 0..1
  final ValueChanged<int>? onStepTap;

  const _TwoStepHeader({
    required this.currentStep,
    this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 3,
            child: Row(
              children: List.generate(2, (index) {
                final isActive = index <= currentStep;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: index == 1 ? 0 : 4),
                    decoration: BoxDecoration(
                      color: isActive ? kGreen : const Color(0xFFE5E1EC),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _stepTitle(
                index: 0,
                label: 'Serviço',
                isCurrent: currentStep == 0,
              ),
              _stepTitle(
                index: 1,
                label: 'Local',
                isCurrent: currentStep == 1,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _stepTitle({
    required int index,
    required String label,
    required bool isCurrent,
  }) {
    final textStyle = TextStyle(
      fontSize: 13,
      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
      color: isCurrent ? kRoxo : Colors.grey.shade600,
    );

    if (onStepTap == null) {
      return Expanded(
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
      );
    }

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onStepTap!(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        ),
      ),
    );
  }
}
