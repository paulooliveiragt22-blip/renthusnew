# Auditoria Completa: Regras de Verificação do Prestador

**Data:** 2025-02-18  
**Escopo:** Tabela `providers`, views, triggers, RPCs, Edge Functions, código Flutter  
**Tipo:** SOMENTE ANÁLISE — Nenhuma alteração foi feita no banco ou código

---

## 1. Estrutura Atual — Colunas de Verificação

| Coluna | Tipo | Default | Nullable | Descrição |
|--------|------|---------|----------|-----------|
| `verified` | boolean | false | YES | Flag legada de verificação |
| `is_verified` | boolean | false | NO | Flag "está verificado" |
| `documents_verified` | boolean | false | NO | Flag documentos verificados |
| `verification_status` | text | 'pending' | YES | **Status principal**: pending, documents_submitted, documents_approved, active, rejected |
| `pagarme_recipient_id` | text | null | YES | ID do recipient na Pagar.me (obrigatório para receber pagamentos) |
| `pagarme_recipient_status` | text | null | YES | Status do recipient na Pagar.me |
| `has_configured_services` | boolean | false | YES | Prestador selecionou service_types |
| `verified_at` | timestamptz | null | YES | Data/hora da verificação |
| `verified_by` | uuid | null | YES | Quem verificou (admin) |
| `status` | varchar | 'pending' | YES | Status da conta: approved, pending, blocked |

---

## 2. Estado dos Dados

| verification_status | Quantidade | pagarme_recipient_id | Observação |
|--------------------|------------|----------------------|------------|
| pending | 3 | null | Ainda não enviaram documentos |
| documents_approved | 1 | preenchido | Paulo admin: tem recipient mas status não é 'active' — **não vê jobs** |

**Inconsistência encontrada:** O provider `paulo admin` (id 31e559b1-12e7-4951-b830-6806459fc912) tem:
- `verification_status` = 'documents_approved'
- `documents_verified` = true
- `pagarme_recipient_id` = 're_cmjhufl4bmu3z0l9t49ajorbk'
- `verified` = false, `is_verified` = false
- `verified_at` = null

Ou seja: recipient criado, mas `verification_status` não foi atualizado para 'active'. A Edge Function `create-pagarme-recipient` deveria ter setado `verification_status = 'active'`. Possíveis causas: função não foi chamada após approval, ou houve erro no update.

---

## 3. Mapa de Dependências

### 3.1 `verification_status`

| Onde | Uso |
|------|-----|
| **v_provider_jobs_public** | Gate obrigatório: `WHERE verification_status = 'active'` — prestador só vê jobs se `active` |
| **v_provider_me** | Exposto na view |
| **provider_home_page.dart** | Banner de verificação, popup |
| **provider_main_page.dart** | Verificação de status |
| **job_details_page.dart** | Exibição do status |
| **admin_verifications_tab.dart** | Filtro e update (documents_approved, rejected) |
| **create-pagarme-recipient** | Valida entrada (documents_approved ou documents_submitted); seta 'active' no update |
| **submit_provider_verification_documents** | Seta 'documents_submitted' |
| **trg_sync_verification_booleans** | Sincroniza booleans quando verification_status muda |

### 3.2 `verified`, `is_verified`, `documents_verified`

| Onde | Uso |
|------|-----|
| **v_provider_me** | Todos expostos |
| **v_public_providers** | `(is_verified OR documents_verified) AS is_verified` |
| **provider_home_page.dart** | Badge: `isVerified = is_verified \|\| documents_verified \|\| verified` |
| **provider_repository.dart** | `isVerified()` lê apenas `is_verified` |
| **job_providers.dart** | Select de providerMe: is_verified, documents_verified, verified |
| **protect_provider_sensitive_fields** | Bloqueia alteração direta (apenas service_role/Dashboard/app.authorized_change) |
| **trg_sync_verification_booleans** | Atualiza conforme verification_status |

### 3.3 `pagarme_recipient_id`, `pagarme_recipient_status`

| Onde | Uso |
|------|-----|
| **create-pagarme-recipient** | Preenche ambos após criar recipient na Pagar.me |
| **provider_repository.dart** | Select de dados bancários |
| **provider_bank_data_page.dart** | Exibe se já tem recipient |
| **protect_provider_sensitive_fields** | Bloqueia alteração de pagarme_recipient_id |

### 3.4 `has_configured_services`

| Onde | Uso |
|------|-----|
| **rpc_provider_set_services** | Seta true ao configurar serviços |
| **provider_service_types** | Relacionado — se tem registros, tem serviços |
| **Cadastro/onboarding** | Etapa de seleção de serviços |

---

## 4. Views que Referenciam Providers e Verificação

| View | Campos de verificação usados | Regra |
|------|------------------------------|-------|
| **v_provider_me** | documents_verified, is_verified, verified, verification_status | WHERE user_id = auth.uid() |
| **v_provider_jobs_public** | verification_status | **Gate:** `verification_status = 'active'` — único critério para ver jobs |
| **v_provider_jobs_candidate_pending** | — | Sem filtro de verificação |
| **v_provider_my_jobs** | — | Sem filtro de verificação (usa current_provider_id()) |
| **v_public_providers** | is_verified, documents_verified | `(is_verified OR documents_verified) AS is_verified`; WHERE status='approved' AND blocked_at IS NULL |
| **v_provider_public_profile** | — | Sem filtro de verificação; WHERE blocked_at IS NULL |

---

## 5. Triggers na Tabela Providers

| Trigger | Timing | Evento | Função | Efeito |
|---------|--------|--------|--------|--------|
| protect_provider_email_phone | BEFORE | UPDATE | protect_email_and_phone() | Bloqueia alteração de phone (providers não tem email) |
| protect_provider_immutable_fields | BEFORE | UPDATE | protect_immutable_fields() | Bloqueia alteração de full_name, cpf |
| protect_provider_sensitive | BEFORE | UPDATE | protect_provider_sensitive_fields() | Bloqueia verified, documents_verified, is_verified, pagarme_recipient_id (exceto service_role/Dashboard/app.authorized_change) |
| trg_prevent_dual_role_providers | BEFORE | INSERT | prevent_dual_role_by_id() | Evita mesmo user como client e provider |
| trg_set_updated_at_providers | BEFORE | UPDATE | set_updated_at() | Atualiza updated_at |
| **trg_sync_verification_booleans** | BEFORE | INSERT OR UPDATE OF verification_status | sync_verification_booleans() | Sincroniza verified, is_verified, documents_verified conforme verification_status |

**sync_verification_booleans (lógica):**
- `verification_status = 'active'` → verified=true, is_verified=true, documents_verified=true
- `verification_status = 'documents_approved'` → documents_verified=true, verified=false, is_verified=false
- Outros → verified=false, is_verified=false, documents_verified=false

---

## 6. RLS Policies — Tabela Providers

Nenhuma policy referencia diretamente verification_status, verified ou pagarme. As policies usam `user_id = auth.uid()` ou `is_admin()`.

| Policy | Cmd | Using |
|--------|-----|-------|
| Providers can select own profile | SELECT | id = auth.uid() ⚠️ (providers.id é PK, não user_id — possivelmente incorreto) |
| Providers can update own profile | UPDATE | id = auth.uid() |
| providers_owner_select | SELECT | id = auth.uid() |
| providers_owner_update | UPDATE | id = auth.uid() |
| providers_select_own | SELECT | user_id = auth.uid() OR is_admin() |
| providers_update_own | UPDATE | user_id = auth.uid() OR is_admin() |
| providers_admin_select_all | SELECT | is_admin() |
| providers_admin_update_all | UPDATE | is_admin() |
| providers_delete_admin | DELETE | is_admin() |
| providers_insert_* | INSERT | user_id = auth.uid() ou id = auth.uid() |

---

## 7. Indexes Relevantes

| Index | Colunas | Observação |
|-------|---------|------------|
| idx_providers_verification_status | verification_status | |
| idx_providers_pagarme_recipient_id | pagarme_recipient_id | |
| idx_providers_online_verified | is_online, is_verified | WHERE is_online AND status='approved' |
| idx_providers_pending_verification | created_at | WHERE verification_status IN ('documents_submitted','pending') |

---

## 8. Constraints e FKs

| Constraint | Tipo | Coluna |
|------------|------|--------|
| providers_pkey | PRIMARY KEY | id |
| providers_user_id_unique | UNIQUE | user_id |

---

## 9. Fluxo Atual (Passo a Passo)

### a) Prestador se cadastra

1. `provider_ensure_profile` ou `rpc_provider_set_services` cria registro em `providers`
2. Defaults: verification_status='pending', verified=false, is_verified=false, documents_verified=false
3. `trg_sync_verification_booleans` (INSERT) sincroniza booleans
4. `has_configured_services` = true quando seleciona service_types

### b) Admin aprova documentos

1. Admin em `admin_verifications_tab` chama `supabase.from('providers').update({ verification_status: 'documents_approved' })`
2. `trg_sync_verification_booleans` (UPDATE OF verification_status) dispara → documents_verified=true, verified=false, is_verified=false
3. `provider_verification_log` recebe registro
4. App chama Edge Function `create-pagarme-recipient` com provider_id

### c) Recipient criado no Pagar.me

1. Edge Function `create-pagarme-recipient` valida verification_status IN (documents_approved, documents_submitted)
2. Chama API Pagar.me, obtém recipient_id e status
3. UPDATE em providers: pagarme_recipient_id, pagarme_recipient_status, verification_status='active', verified_at=now()
4. `trg_sync_verification_booleans` dispara → verified=true, is_verified=true, documents_verified=true
5. `protect_provider_sensitive_fields` permite (service_role)
6. `provider_verification_log` recebe registro

### d) Prestador liberado para ver jobs

1. `v_provider_jobs_public` usa CTE: `SELECT p.id FROM providers p WHERE p.user_id = auth.uid() AND p.verification_status = 'active'`
2. Se verification_status != 'active', CTE retorna vazio → CROSS JOIN me retorna 0 linhas → prestador não vê jobs

---

## 10. Campos que são Gates Obrigatórios

| Gate | Onde | Condição |
|------|------|----------|
| **Ver jobs públicos** | v_provider_jobs_public | `verification_status = 'active'` |
| **Cliente pagar prestador** | Pagar.me / fluxo de pagamento | `pagarme_recipient_id` preenchido |
| **Aparecer em v_public_providers** | v_public_providers | status='approved' AND blocked_at IS NULL; is_verified OR documents_verified para badge |
| **Criar recipient** | create-pagarme-recipient | verification_status IN (documents_approved, documents_submitted) |

---

## 11. Edge Functions Relevantes

| Função | Arquivo | Papel |
|--------|---------|-------|
| create-pagarme-recipient | supabase/functions/create-pagarme-recipient/index.ts | Cria recipient na Pagar.me; atualiza pagarme_recipient_id, pagarme_recipient_status, verification_status='active', verified_at |

---

## 12. Tabelas Auxiliares

| Tabela | Colunas | Uso |
|--------|---------|-----|
| provider_verification_log | id, provider_id, old_status, new_status, reason, changed_by, created_at | Log de mudanças de verification_status |
| provider_service_types | id, provider_id, service_type_id, created_at | Serviços que o prestador executa; usado para has_configured_services e match com jobs |

---

## 13. Uso no Flutter

| Arquivo | Campos usados |
|---------|---------------|
| provider_home_page.dart | verification_status, is_verified, documents_verified, verified (badge); status (approved/pending/blocked) |
| provider_main_page.dart | verification_status |
| provider_repository.dart | is_verified (isVerified()), pagarme_recipient_id |
| provider_bank_data_page.dart | pagarme_recipient_id |
| job_providers.dart | provider_id, full_name, city, is_verified, documents_verified, verified, status, rating, verification_status |
| admin_verifications_tab.dart | verification_status (filtro e update) |
| job_details_page.dart | verification_status |

---

## 14. Inconsistências Encontradas

1. **Provider paulo admin:** tem `pagarme_recipient_id` mas `verification_status = 'documents_approved'` (não 'active'). Não vê jobs. A Edge Function deveria ter setado 'active'.
2. **RLS "Providers can select own profile":** usa `id = auth.uid()`, mas providers.id é o PK interno; auth.uid() é o user_id. Deveria ser `user_id = auth.uid()`.
3. **Três booleans vs verification_status:** verified, is_verified, documents_verified são derivados de verification_status via trigger. Fonte da verdade é verification_status; os booleans podem ser redundantes no longo prazo.
4. **protect_provider_sensitive_fields** não protege `verification_status` — qualquer UPDATE com permissão pode alterá-lo. Apenas verified, documents_verified, is_verified e pagarme_recipient_id são protegidos.

---

## 15. Resumo Executivo

- **Gate para ver jobs:** exclusivamente `verification_status = 'active'`
- **Gate para receber pagamentos:** `pagarme_recipient_id` preenchido
- **Fluxo esperado:** pending → documents_submitted → documents_approved → (Edge Function) → active
- **Sincronização:** trigger `trg_sync_verification_booleans` mantém verified, is_verified, documents_verified alinhados com verification_status
- **Inconsistência em produção:** 1 provider com recipient mas verification_status não atualizado para 'active'
