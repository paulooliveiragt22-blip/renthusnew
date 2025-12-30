import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pix_qr_page.dart';

class ClientCheckoutPage extends StatefulWidget {
  final String jobId;
  final String quoteId;
  final String initialMethod; // 'pix' | 'card'

  final String? jobTitle;
  final String? providerName;

  const ClientCheckoutPage({
    super.key,
    required this.jobId,
    required this.quoteId,
    this.jobTitle,
    this.providerName,
    this.initialMethod = 'pix',
  });

  @override
  State<ClientCheckoutPage> createState() => _ClientCheckoutPageState();
}

class _ClientCheckoutPageState extends State<ClientCheckoutPage> {
  final supabase = Supabase.instance.client;

  static const String pagarmePublicKey = 'pk_wEV5Waukvib7djrQ';

  // cache keys (manual address)
  static const _kAddrZip = 'checkout_manual_zip';
  static const _kAddrStreet = 'checkout_manual_street';
  static const _kAddrNumber = 'checkout_manual_number';
  static const _kAddrComplement = 'checkout_manual_complement';
  static const _kAddrNeighborhood = 'checkout_manual_neighborhood';
  static const _kAddrCity = 'checkout_manual_city';
  static const _kAddrState = 'checkout_manual_state';

  bool loading = false;
  String? error;

  String _method = 'pix';

  // pagador
  final _payerName = TextEditingController();
  final _payerEmail = TextEditingController();
  final _payerCpf = TextEditingController();
  final _payerPhone = TextEditingController();

  // endereço cobrança (card)
  final _zip = TextEditingController(); // começa limpo
  final _street = TextEditingController();
  final _number = TextEditingController();
  final _complement = TextEditingController();
  final _neighborhood = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController(text: 'MT');

  // seleção de endereço
  bool _useProfileAddress = false;

  // CEP autofill
  DateTime? _lastCepTyping;
  bool _cepLoading = false;

  // controle pra sobrescrever campos quando CEP mudar
  String _lastAutoFilledCep = '';

  // snapshot do endereço manual (pra restaurar ao voltar do "usar cadastro")
  Map<String, String>? _manualAddressSnapshot;

  // melhoria: marca se usuário já mexeu no endereço manual nesta sessão
  bool _manualTouched = false;

  // cartão
  final _cardNumber = TextEditingController();
  final _cardHolderName = TextEditingController();
  final _cardExpMonth = TextEditingController();
  final _cardExpYear = TextEditingController();
  final _cardCvv = TextEditingController();

  @override
  void initState() {
    super.initState();
    _method = widget.initialMethod;

    _zip.addListener(_onZipChanged);
    _attachManualTouchedListeners();
    _attachManualAddressCacheListeners();

    // Prefetch do pagador (nome/email/telefone/cpf) vindo da view
    _prefetchClientMe();

    // CEP NÃO restaura automaticamente ao abrir — só carrega se usuário marcar endereço do cadastro
  }

  String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');
  bool _isEmail(String s) => s.contains('@') && s.contains('.');
  bool _validUf(String s) => RegExp(r'^[A-Z]{2}$').hasMatch(s);

  bool _isValidBRPhone(String raw) {
    final d = _digitsOnly(raw);
    return d.length == 10 || d.length == 11;
  }

  void _setError(String msg) {
    setState(() => error = msg);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _fail(String msg) {
    _setError(msg);
    return false;
  }

  // ------------------ mensagens amigáveis ------------------
  String _msgCardNotApproved() {
    return 'Pagamento não aprovado.\nNão foi possível concluir o pagamento com este cartão. Verifique os dados ou tente outro cartão.';
  }

  String _msgPixFailed() {
    return 'Não foi possível gerar o Pix no momento.\nTente novamente em instantes.';
  }

  String _msgUnexpected() {
    return 'Ocorreu um problema ao processar o pagamento.\nTente novamente ou escolha outro método.';
  }

  // Evita mostrar payload técnico pro cliente
  String _friendlyErrorForTokenize(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('422') ||
        s.contains('invalid') ||
        s.contains('request is invalid') ||
        s.contains('card number') ||
        s.contains('token')) {
      return 'Não foi possível validar os dados do cartão.\nVerifique o número, validade e CVV, ou tente outro cartão.';
    }
    return 'Não foi possível validar o cartão agora.\nTente novamente ou use Pix.';
  }

  String _friendlyErrorForBackend(int? status, dynamic data) {
    // Edge function: { error: "...", code: "...", message: "..." }
    final errStr = (data is Map<String, dynamic>)
        ? (data['error'] ?? data['message'] ?? '').toString()
        : '';

    // Quando cartão falha, preferimos mensagem genérica (não expor gateway)
    if (_method == 'card') {
      if (status == 400) return _msgCardNotApproved();
      if (status == 500) return _msgUnexpected();
    }

    // Pix: erro técnico ao criar
    if (_method == 'pix') {
      if (status == 400 || status == 500) return _msgPixFailed();
    }

    // fallback com algo leve
    if (errStr.isNotEmpty) return errStr;
    return _msgUnexpected();
  }

  // ------------------ view ------------------
  Future<Map<String, dynamic>?> _getClientMe() async {
    final res = await supabase.from('v_client_me').select('''
      full_name,
      phone,
      email,
      cpf,
      city,
      address_zip_code,
      address_street,
      address_number,
      address_district,
      address_state
    ''').maybeSingle();

    return res;
  }

  Future<void> _prefetchClientMe() async {
    try {
      final me = await _getClientMe();
      if (me == null) return;

      if (_payerName.text.trim().isEmpty) {
        _payerName.text = (me['full_name'] ?? '').toString();
      }

      if (_payerPhone.text.trim().isEmpty) {
        _payerPhone.text = _digitsOnly((me['phone'] ?? '').toString());
      }

      if (_payerEmail.text.trim().isEmpty) {
        final meEmail = (me['email'] ?? '').toString().trim();
        if (_isEmail(meEmail)) _payerEmail.text = meEmail;
      }

      if (_payerCpf.text.trim().isEmpty) {
        final cpf = _digitsOnly((me['cpf'] ?? '').toString());
        if (cpf.isNotEmpty) _payerCpf.text = cpf;
      }
    } catch (_) {
      // silencioso
    }
  }

  bool _addressFieldsHaveSomething() {
    return _digitsOnly(_zip.text).isNotEmpty ||
        _street.text.trim().isNotEmpty ||
        _number.text.trim().isNotEmpty ||
        _neighborhood.text.trim().isNotEmpty ||
        _city.text.trim().isNotEmpty ||
        _state.text.trim().isNotEmpty;
  }

  // ---------- CEP mask formatter (#####-###) ----------
  String _formatCep(String raw) {
    final d = _digitsOnly(raw);
    final cut = d.length > 8 ? d.substring(0, 8) : d;
    if (cut.length <= 5) return cut;
    return '${cut.substring(0, 5)}-${cut.substring(5)}';
  }

  // ---------- manual address snapshot ----------
  Map<String, String> _captureManualAddress() {
    return {
      'zip': _formatCep(_zip.text),
      'street': _street.text,
      'number': _number.text,
      'complement': _complement.text,
      'neighborhood': _neighborhood.text,
      'city': _city.text,
      'state': _state.text,
    };
  }

  bool _isSnapshotUseful(Map<String, String>? snap) {
    if (snap == null) return false;
    return _digitsOnly(snap['zip'] ?? '').isNotEmpty ||
        (snap['street'] ?? '').trim().isNotEmpty ||
        (snap['number'] ?? '').trim().isNotEmpty ||
        (snap['neighborhood'] ?? '').trim().isNotEmpty ||
        (snap['city'] ?? '').trim().isNotEmpty ||
        (snap['state'] ?? '').trim().isNotEmpty;
  }

  void _restoreManualAddress(Map<String, String> snap) {
    _zip.text = _formatCep(snap['zip'] ?? '');
    _street.text = snap['street'] ?? '';
    _number.text = snap['number'] ?? '';
    _complement.text = snap['complement'] ?? '';
    _neighborhood.text = snap['neighborhood'] ?? '';
    _city.text = snap['city'] ?? '';
    _state.text = (snap['state'] ?? 'MT').toUpperCase();

    final cep = _digitsOnly(_zip.text);
    if (cep.length == 8 && _lastAutoFilledCep != cep) {
      Future.microtask(() => _fetchAndFillCep(cep));
    }
  }

  // ---------- marcar que usuário mexeu no manual ----------
  void _attachManualTouchedListeners() {
    void touched() {
      if (_method != 'card') return;
      if (_useProfileAddress) return;
      _manualTouched = true;
    }

    _zip.addListener(touched);
    _street.addListener(touched);
    _number.addListener(touched);
    _complement.addListener(touched);
    _neighborhood.addListener(touched);
    _city.addListener(touched);
    _state.addListener(touched);
  }

  // ---------- cache manual address (SharedPreferences) ----------
  void _attachManualAddressCacheListeners() {
    void saver() {
      if (_method != 'card') return;
      if (_useProfileAddress) return;
      _saveManualAddressToCache();
    }

    _zip.addListener(saver);
    _street.addListener(saver);
    _number.addListener(saver);
    _complement.addListener(saver);
    _neighborhood.addListener(saver);
    _city.addListener(saver);
    _state.addListener(saver);
  }

  Future<void> _saveManualAddressToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAddrZip, _formatCep(_zip.text));
      await prefs.setString(_kAddrStreet, _street.text);
      await prefs.setString(_kAddrNumber, _number.text);
      await prefs.setString(_kAddrComplement, _complement.text);
      await prefs.setString(_kAddrNeighborhood, _neighborhood.text);
      await prefs.setString(_kAddrCity, _city.text);
      await prefs.setString(_kAddrState, _state.text.toUpperCase());
    } catch (_) {}
  }

  Future<Map<String, String>?> _readManualAddressCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final zip = prefs.getString(_kAddrZip) ?? '';
      final street = prefs.getString(_kAddrStreet) ?? '';
      final number = prefs.getString(_kAddrNumber) ?? '';
      final complement = prefs.getString(_kAddrComplement) ?? '';
      final neighborhood = prefs.getString(_kAddrNeighborhood) ?? '';
      final city = prefs.getString(_kAddrCity) ?? '';
      final state = (prefs.getString(_kAddrState) ?? '').toUpperCase();

      final hasSomething = _digitsOnly(zip).isNotEmpty ||
          street.trim().isNotEmpty ||
          neighborhood.trim().isNotEmpty ||
          city.trim().isNotEmpty ||
          number.trim().isNotEmpty;

      if (!hasSomething) return null;

      return {
        'zip': zip,
        'street': street,
        'number': number,
        'complement': complement,
        'neighborhood': neighborhood,
        'city': city,
        'state': state,
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> _applyProfileAddress() async {
    final me = await _getClientMe();
    if (me == null) return;

    _zip.text = _formatCep((me['address_zip_code'] ?? '').toString());
    _street.text = (me['address_street'] ?? '').toString();
    _number.text = (me['address_number'] ?? '').toString();
    _complement.text = '';
    _neighborhood.text = (me['address_district'] ?? '').toString();
    _city.text = (me['city'] ?? '').toString();
    _state.text = ((me['address_state'] ?? 'MT').toString()).toUpperCase();

    _lastAutoFilledCep = _digitsOnly(_zip.text);
  }

  void _clearAddressFieldsKeepUf() {
    _zip.clear();
    _street.clear();
    _number.clear();
    _complement.clear();
    _neighborhood.clear();
    _city.clear();
    if (_state.text.trim().isEmpty) _state.text = 'MT';
    _lastAutoFilledCep = '';
  }

  // Troca método (Pix/Card) sem perder o que já digitou
  Future<void> _setMethod(String value) async {
    if (_method == value) return;

    setState(() => _method = value);

    if (_method != 'card') return;

    if (_useProfileAddress) {
      await _applyProfileAddress();
      if (mounted) setState(() {});
    }
  }

  // Listener do CEP: roda apenas em modo manual
  void _onZipChanged() {
    if (_method != 'card') return;
    if (_useProfileAddress) return;

    final formatted = _formatCep(_zip.text);
    if (_zip.text != formatted) {
      final sel = formatted.length;
      _zip.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: sel),
      );
    }

    final cep = _digitsOnly(_zip.text);
    if (cep.length != 8) return;

    _lastCepTyping = DateTime.now();
    Future.delayed(const Duration(milliseconds: 250), () async {
      final last = _lastCepTyping;
      if (last == null) return;
      if (DateTime.now().difference(last).inMilliseconds < 250) return;

      await _fetchAndFillCep(cep);
    });
  }

  Future<void> _fetchAndFillCep(String cep8) async {
    if (_cepLoading) return;

    // Regra: só substitui se for um NOVO CEP digitado
    final isNewCep = _lastAutoFilledCep != cep8;
    if (!isNewCep) return;

    setState(() => _cepLoading = true);

    try {
      final uri = Uri.parse('https://viacep.com.br/ws/$cep8/json/');
      final res = await http.get(uri);
      if (res.statusCode < 200 || res.statusCode >= 300) return;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['erro'] == true) return;

      final rua = (data['logradouro'] ?? '').toString();
      final bairro = (data['bairro'] ?? '').toString();
      final cidade = (data['localidade'] ?? '').toString();
      final uf = (data['uf'] ?? '').toString();

      if (_street.text.trim().isEmpty || rua.trim().isNotEmpty) {
        if (rua.trim().isNotEmpty) _street.text = rua;
      }

      if (_neighborhood.text.trim().isEmpty || bairro.trim().isNotEmpty) {
        if (bairro.trim().isNotEmpty) _neighborhood.text = bairro;
      }

      if (_city.text.trim().isEmpty || cidade.trim().isNotEmpty) {
        if (cidade.trim().isNotEmpty) _city.text = cidade;
      }

      if (_state.text.trim().isEmpty || uf.trim().isNotEmpty) {
        if (uf.isNotEmpty) _state.text = uf.toUpperCase();
      }

      _lastAutoFilledCep = cep8;
      await _saveManualAddressToCache();
    } catch (_) {
      // silencioso
    } finally {
      if (mounted) setState(() => _cepLoading = false);
    }
  }

  Map<String, dynamic> _buildPayerPayload() {
    return {
      'name': _payerName.text.trim(),
      'email': _payerEmail.text.trim(),
      'document': _digitsOnly(_payerCpf.text),
      'phone': _digitsOnly(_payerPhone.text),
    };
  }

  Map<String, dynamic> _buildBillingPayload() {
    final uf = _state.text.trim().toUpperCase();

    return {
      'zip_code': _digitsOnly(_zip.text),
      'street': _street.text.trim(),
      'number': _number.text.trim(),
      'complement':
          _complement.text.trim().isEmpty ? null : _complement.text.trim(),
      'neighborhood': _neighborhood.text.trim(),
      'city': _city.text.trim(),
      'state': uf,
      'country': 'BR',
    };
  }

  bool _validate() {
    final name = _payerName.text.trim();
    final cpf = _digitsOnly(_payerCpf.text);
    final phone = _digitsOnly(_payerPhone.text);

    if (name.isEmpty) return _fail('Informe o nome do pagador.');
    if (cpf.length != 11)
      return _fail('CPF deve ter 11 dígitos (somente números).');

    if (!_isValidBRPhone(phone)) {
      return _fail(
          'Informe o telefone com DDD (10 ou 11 dígitos). Ex: 11999998888');
    }

    final email = _payerEmail.text.trim();
    if (!_isEmail(email)) {
      return _fail(_method == 'pix'
          ? 'Informe um e-mail válido para o Pix.'
          : 'Informe um e-mail válido.');
    }

    if (_method == 'pix') return true;

    final zip = _digitsOnly(_zip.text);
    if (zip.length != 8)
      return _fail('CEP deve ter 8 dígitos (somente números).');

    final uf = _state.text.trim().toUpperCase();
    if (!_validUf(uf)) return _fail('UF inválida. Ex: MT');

    if (_street.text.trim().isEmpty) return _fail('Informe a rua.');
    if (_number.text.trim().isEmpty) return _fail('Informe o número.');
    if (_neighborhood.text.trim().isEmpty) return _fail('Informe o bairro.');
    if (_city.text.trim().isEmpty) return _fail('Informe a cidade.');

    return _validateCard();
  }

  bool _validateCard() {
    final cardNumber = _digitsOnly(_cardNumber.text);
    final month = _digitsOnly(_cardExpMonth.text);
    final year = _digitsOnly(_cardExpYear.text);
    final cvv = _digitsOnly(_cardCvv.text);

    if (_cardHolderName.text.trim().isEmpty)
      return _fail('Informe o nome impresso no cartão.');
    if (cardNumber.length < 13 || cardNumber.length > 19)
      return _fail('Número do cartão inválido.');
    if (month.length != 2) return _fail('Mês inválido (MM).');

    final m = int.tryParse(month) ?? 0;
    if (m < 1 || m > 12) return _fail('Mês inválido (01-12).');

    if (year.length != 2 && year.length != 4) return _fail('Ano inválido.');
    if (cvv.length < 3 || cvv.length > 4) return _fail('CVV inválido.');

    return true;
  }

  Future<String> _tokenizeCardPagarme() async {
    if (pagarmePublicKey.contains('COLOQUE_')) {
      // evita conflito com Exception custom no projeto
      throw StateError(
          'Defina sua PAGARME public key no app (pagarmePublicKey).');
    }

    final cardNumber = _digitsOnly(_cardNumber.text);
    final month = _digitsOnly(_cardExpMonth.text);
    final yearRaw = _digitsOnly(_cardExpYear.text);
    final year = yearRaw.length == 2 ? '20$yearRaw' : yearRaw;
    final cvv = _digitsOnly(_cardCvv.text);

    final uri = Uri.parse(
        'https://api.pagar.me/core/v5/tokens?appId=$pagarmePublicKey');

    final payload = {
      'type': 'card',
      'card': {
        'number': cardNumber,
        'holder_name': _cardHolderName.text.trim(),
        'exp_month': month,
        'exp_year': year,
        'cvv': cvv,
      },
    };

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      // joga a exception, mas a UI vai transformar em mensagem amigável
      throw StateError(
          'Falha ao tokenizar cartão (${res.statusCode}): ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    final tokenId = decoded['id']?.toString();
    if (tokenId == null || tokenId.isEmpty) {
      throw StateError('Token inválido retornado pela Pagar.me.');
    }

    return tokenId;
  }

  String _methodLabel(String m) => m == 'card' ? 'cartão' : 'Pix';

  Future<String?> _showPendingChoiceDialog({
    required String message,
    required String continueLabel,
    required String switchLabel,
  }) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Pagamento pendente'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'continue'),
              child: Text(continueLabel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'switch'),
              child: Text(switchLabel),
            ),
          ],
        );
      },
    );
  }

  String _friendlyPaymentError(dynamic data, Object e) {
    // se erro veio do tokenize do cartão
    if (_method == 'card' &&
        (e is StateError || e.toString().toLowerCase().contains('tokenizar'))) {
      return _friendlyErrorForTokenize(e);
    }

    // tenta puxar mensagem do backend
    final backendMsg = (data is Map && data['error'] != null)
        ? data['error'].toString()
        : null;
    final backendCode =
        (data is Map && data['code'] != null) ? data['code'].toString() : null;

    // Não mostrar o "PENDING_EXISTS" como erro feio
    if (backendCode == 'PENDING_EXISTS') {
      return 'Você já tem um pagamento pendente. Escolha se deseja continuar nele ou trocar o método.';
    }

    if (backendMsg != null && backendMsg.trim().isNotEmpty) {
      final msg = backendMsg.toLowerCase();
      if (msg.contains('card_token')) {
        return 'Não foi possível validar o cartão. Confira os dados e tente novamente.';
      }
      if (msg.contains('payer.email')) {
        return 'E-mail inválido. Verifique e tente novamente.';
      }
      if (msg.contains('cpf') || msg.contains('payer.document')) {
        return 'CPF inválido. Verifique e tente novamente.';
      }
      if (msg.contains('billing_address')) {
        return 'Endereço de cobrança incompleto. Verifique e tente novamente.';
      }
      return backendMsg;
    }

    final raw = e.toString().toLowerCase();
    if (raw.contains('timed out') || raw.contains('timeout')) {
      return 'A conexão demorou. Verifique sua internet e tente novamente.';
    }

    // fallback por método
    return _method == 'card' ? _msgCardNotApproved() : _msgPixFailed();
  }

  Future<void> _handlePixSuccess(Map<String, dynamic> data) async {
    final pix = data['pix'];

    final copyPaste = (pix?['qr_code'] ?? pix?['copy_paste'])?.toString();
    final qrUrl = pix?['qr_code_url']?.toString();
    final expiresAt = pix?['expires_at']?.toString();

    if (copyPaste == null || copyPaste.isEmpty) {
      _setError(_msgPixFailed());
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PixQrPage(
          copyPaste: copyPaste,
          expiresAt: expiresAt,
          qrCodeUrl: qrUrl,
        ),
      ),
    );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _handleCardSuccess(Map<String, dynamic> data) async {
    final status = (data['payment']?['status'] ?? '').toString();

    final msg = status == 'paid'
        ? 'Pagamento aprovado!'
        : 'Pagamento iniciado. Aguarde confirmação.';

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    Navigator.pop(context, true);
  }

  Future<void> _pay() async {
    if (loading) return;

    setState(() {
      loading = true;
      error = null;
    });

    dynamic data; // para montar mensagem amigável

    try {
      if (!_validate()) return;

      Future<Map<String, dynamic>> invokeCheckout({
        required String method,
        required bool forceNew,
      }) async {
        final payer = _buildPayerPayload();

        Map<String, dynamic>? billing;
        String? cardToken;

        if (method == 'card') {
          billing = _buildBillingPayload();
          try {
            cardToken = await _tokenizeCardPagarme();
          } catch (e) {
            // já traduz aqui para não explodir no catch com payload feio
            throw StateError(_friendlyErrorForTokenize(e));
          }
        }

        final res = await supabase.functions.invoke(
          'create-payment',
          body: {
            'job_id': widget.jobId,
            'quote_id': widget.quoteId,
            'payment_method': method,
            if (forceNew) 'force_new': true,
            if (cardToken != null) 'card_token': cardToken,
            'payer': payer,
            'billing_address': billing,
          },
        );

        data = res.data;

        // 409 pendente (mensagem amigável deve aparecer via dialog)
        if (res.status == 409 &&
            data is Map &&
            data['code'] == 'PENDING_EXISTS') {
          throw _PendingExistsException();
        }

        if (res.status != 200 ||
            data == null ||
            data is! Map ||
            data['ok'] != true) {
          final friendly = _friendlyErrorForBackend(res.status, data);
          throw StateError(friendly);
        }

        return Map<String, dynamic>.from(data as Map);
      }

      // 1) Primeiro tenta com o método atual
      Map<String, dynamic> result;
      try {
        result = await invokeCheckout(method: _method, forceNew: false);
      } on _PendingExistsException {
        final pending = (data as Map)['pending'] as Map<String, dynamic>?;
        final pendingMethod =
            (pending?['method'] ?? '').toString(); // 'pix' | 'card'
        final requestedMethod = _method;

        final backendMsg = (data as Map)['message']?.toString();
        final msg = (backendMsg != null && backendMsg.trim().isNotEmpty)
            ? backendMsg
            : 'Você já tem um pagamento pendente por ${_methodLabel(pendingMethod)}. '
                'Deseja continuar nele ou trocar para ${_methodLabel(requestedMethod)}?';

        final choice = await _showPendingChoiceDialog(
          message: msg,
          continueLabel: 'Continuar',
          switchLabel: 'Trocar para ${_methodLabel(requestedMethod)}',
        );

        if (!mounted) return;

        if (choice == 'continue') {
          // continuar no pending existente
          if (pendingMethod == 'pix') {
            final pix = pending?['pix'] as Map<String, dynamic>?;
            final copyPaste =
                (pix?['qr_code'] ?? pix?['copy_paste'])?.toString();
            final qrUrl = pix?['qr_code_url']?.toString();
            final expiresAt = pix?['expires_at']?.toString();

            if (copyPaste != null && copyPaste.isNotEmpty) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PixQrPage(
                    copyPaste: copyPaste,
                    expiresAt: expiresAt,
                    qrCodeUrl: qrUrl,
                  ),
                ),
              );
              if (!mounted) return;
              Navigator.pop(context, true);
              return;
            }

            _setError(
                'Existe um Pix pendente, mas não foi possível abrir o QR Code.');
            return;
          }

          // pending cartão: não tem “tela” para retomar (depende do status no gateway/webhook)
          _setError(
              'Você já tem um pagamento pendente por cartão. Aguarde a confirmação ou tente novamente mais tarde.');
          return;
        }

        if (choice == 'switch') {
          // OBS: aqui só funciona se backend aceitar "force_new": true e cancelar/substituir o anterior.
          // Se você decidiu a regra "bloquear duplicidade apenas quando status=paid", então o backend
          // deve permitir criar outro mesmo com pending.
          result =
              await invokeCheckout(method: requestedMethod, forceNew: true);
        } else {
          return;
        }
      }

      if (!mounted) return;

      if (_method == 'pix') {
        await _handlePixSuccess(result);
        return;
      }

      await _handleCardSuccess(result);
    } catch (e) {
      if (!mounted) return;
      final msg = _friendlyPaymentError(data, e);
      _setError('Erro no pagamento: $msg');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    _zip.removeListener(_onZipChanged);

    _payerName.dispose();
    _payerEmail.dispose();
    _payerCpf.dispose();
    _payerPhone.dispose();

    _zip.dispose();
    _street.dispose();
    _number.dispose();
    _complement.dispose();
    _neighborhood.dispose();
    _city.dispose();
    _state.dispose();

    _cardNumber.dispose();
    _cardHolderName.dispose();
    _cardExpMonth.dispose();
    _cardExpYear.dispose();
    _cardCvv.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const roxo = Color(0xFF3B246B);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.only(left: 8, right: 16, top: 8, bottom: 12),
              color: roxo,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Checkout',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Método de pagamento'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _methodChip('pix', 'Pix'),
                        const SizedBox(width: 10),
                        _methodChip('card', 'Cartão'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _sectionTitle('Dados do pagador'),
                    const SizedBox(height: 8),
                    _card(
                      child: Column(
                        children: [
                          _field(_payerName, 'Nome do pagador'),
                          const SizedBox(height: 8),
                          _field(
                            _payerEmail,
                            _method == 'pix'
                                ? 'E-mail (obrigatório)'
                                : 'E-mail do pagador',
                            keyboard: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 8),
                          _field(
                            _payerCpf,
                            'CPF (somente números)',
                            keyboard: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _field(
                            _payerPhone,
                            'Telefone com DDD (somente números)',
                            keyboard: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_method == 'card') ...[
                      _sectionTitle('Endereço de cobrança'),
                      const SizedBox(height: 8),
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            RadioListTile<bool>(
                              value: false,
                              groupValue: _useProfileAddress,
                              onChanged: (v) async {
                                if (v == null) return;

                                setState(() => _useProfileAddress = false);

                                if (_isSnapshotUseful(_manualAddressSnapshot)) {
                                  _restoreManualAddress(
                                      _manualAddressSnapshot!);
                                  if (mounted) setState(() {});
                                  return;
                                }

                                final cached = await _readManualAddressCache();
                                if (_isSnapshotUseful(cached)) {
                                  _restoreManualAddress(cached!);
                                  if (mounted) setState(() {});
                                  return;
                                }

                                if (!_addressFieldsHaveSomething()) {
                                  _clearAddressFieldsKeepUf();
                                }

                                if (mounted) setState(() {});
                              },
                              title: const Text('Digitar endereço'),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              visualDensity: const VisualDensity(
                                  horizontal: -2, vertical: -2),
                            ),
                            RadioListTile<bool>(
                              value: true,
                              groupValue: _useProfileAddress,
                              onChanged: (v) async {
                                if (v == null) return;

                                _manualAddressSnapshot =
                                    _captureManualAddress();
                                await _saveManualAddressToCache();

                                setState(() => _useProfileAddress = true);
                                await _applyProfileAddress();
                                if (mounted) setState(() {});
                              },
                              title: const Text('Usar endereço do cadastro'),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              visualDensity: const VisualDensity(
                                  horizontal: -2, vertical: -2),
                            ),
                            if (_useProfileAddress) ...[
                              const SizedBox(height: 4),
                              const Text(
                                'Para alterar o endereço, selecione "Digitar endereço".',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.black54),
                              ),
                            ],
                            const Divider(height: 14),
                            _field(
                              _zip,
                              'CEP',
                              keyboard: TextInputType.number,
                              enabled: !_useProfileAddress,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9-]')),
                                LengthLimitingTextInputFormatter(9),
                              ],
                              suffix: _cepLoading
                                  ? const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: SizedBox(
                                        height: 14,
                                        width: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            _field(_street, 'Rua',
                                enabled: !_useProfileAddress),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                    child: _field(_number, 'Número',
                                        enabled: !_useProfileAddress)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _field(
                                    _state,
                                    'UF (ex: MT)',
                                    keyboard: TextInputType.text,
                                    enabled: !_useProfileAddress,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[a-zA-Z]')),
                                      LengthLimitingTextInputFormatter(2),
                                      UpperCaseTextFormatter(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _field(_complement, 'Complemento (opcional)',
                                enabled: !_useProfileAddress),
                            const SizedBox(height: 8),
                            _field(_neighborhood, 'Bairro',
                                enabled: !_useProfileAddress),
                            const SizedBox(height: 8),
                            _field(_city, 'Cidade',
                                enabled: !_useProfileAddress),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _sectionTitle('Dados do cartão'),
                      const SizedBox(height: 8),
                      _card(
                        child: Column(
                          children: [
                            _field(_cardHolderName, 'Nome impresso no cartão'),
                            const SizedBox(height: 8),
                            _field(
                              _cardNumber,
                              'Número do cartão',
                              keyboard: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(19),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _field(
                                    _cardExpMonth,
                                    'MM',
                                    keyboard: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(2),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _field(
                                    _cardExpYear,
                                    'AAAA ou AA',
                                    keyboard: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(4),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _field(
                                    _cardCvv,
                                    'CVV',
                                    keyboard: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(4),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Os dados do cartão são tokenizados diretamente na Pagar.me e não vão para o servidor.',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                    ],
                    _card(
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: loading ? null : _pay,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: roxo,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26)),
                          ),
                          child: Text(
                            loading
                                ? 'Processando...'
                                : (_method == 'pix'
                                    ? 'Gerar Pix'
                                    : 'Pagar com Cartão'),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodChip(String value, String label) {
    final selected = _method == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setMethod(value),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF3B246B) : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF3B246B),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    TextInputType keyboard = TextInputType.text,
    bool enabled = true,
    Widget? suffix,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: c,
      enabled: enabled,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        suffixIcon: suffix,
      ),
    );
  }
}

// Formatter para forçar uppercase em UF
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

// ✅ exceção interna para controlar o fluxo sem "printar erro feio"
class _PendingExistsException implements Exception {
  @override
  String toString() => '_PendingExistsException';
}
