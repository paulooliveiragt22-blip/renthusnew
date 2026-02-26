import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Serviço para salvar/carregar rascunhos de pedidos incompletos.
/// Cada rascunho é salvo como JSON no SharedPreferences.
/// Key: "job_drafts" → List<Map<String, dynamic>>
class JobDraftService {
  static const _key = 'job_drafts';
  static const _maxDrafts = 5;

  final SharedPreferences _prefs;
  JobDraftService(this._prefs);

  /// Retorna lista de rascunhos salvos
  List<Map<String, dynamic>> getDrafts() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Salva um novo rascunho (máx 5, remove o mais antigo se exceder)
  Future<void> saveDraft(Map<String, dynamic> draft) async {
    final drafts = getDrafts();

    draft['draft_id'] = DateTime.now().millisecondsSinceEpoch.toString();
    draft['saved_at'] = DateTime.now().toIso8601String();

    drafts.insert(0, draft);

    final limited = drafts.take(_maxDrafts).toList();
    await _prefs.setString(_key, jsonEncode(limited));
  }

  /// Remove um rascunho por draft_id
  Future<void> removeDraft(String draftId) async {
    final drafts = getDrafts();
    drafts.removeWhere((d) => d['draft_id'] == draftId);
    await _prefs.setString(_key, jsonEncode(drafts));
  }

  /// Limpa todos os rascunhos
  Future<void> clearAll() async {
    await _prefs.remove(_key);
  }

  /// Verifica se tem rascunhos
  bool hasDrafts() => getDrafts().isNotEmpty;
}
