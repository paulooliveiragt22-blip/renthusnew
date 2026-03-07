# RENTHUS — Contexto de Regras + Estado Real do Banco
> Gerado a partir de: `schema_DB.md` + `DIAGNOSTICO_BANCO.md` (2026-03-07)
> **Leia este arquivo ANTES de qualquer alteração no banco, RLS, functions ou triggers.**
> Banco: `dqfejuakbtcxhymrxoqs`

---

## 🚨 PROBLEMAS CONFIRMADOS NO BANCO ATUAL

> Estado real verificado por query direta. Não são suposições.

| # | Problema | Tabela | Severidade |
|---|---|---|---|
| P1 | `trg_notify_job_status` e `trg_notify_job_status_change` chamam a **mesma função** `notify_job_status_change` → **2 notificações duplicadas** a cada mudança de status | `jobs` | 🔴 ALTO |
| P2 | `apply_payment_paid_effects` (AFTER INSERT+UPDATE) e `trg_apply_payment_paid_effects` (AFTER UPDATE) chamam a **mesma função** → no UPDATE do payment, `apply_payment_paid_effects` executa **2 vezes** | `payments` | 🔴 ALTO |
| P3 | RLS de `job_addresses` **não filtra por status do job** — `job_addresses_select_participants` libera endereço completo para o prestador em qualquer status, incluindo `completed` e `cancelled_*` | `job_addresses` | 🟡 MÉDIO |
| P4 | 3 triggers distintos colocam job em `dispute` no mesmo INSERT em `disputes` (`trg_disputes_after_insert`, `trg_open_job_dispute`, `tr_set_job_status_dispute_on_open_dispute`) | `disputes` | 🟡 MÉDIO |
| P5 | `trg_calc_payment_split` e `trg_payments_apply_split` calculam split simultaneamente (funções diferentes: `calc_payment_split` vs `payments_apply_split`) | `payments` | 🟡 MÉDIO |
| P6 | 4 funções de notificação de chat existem mas **nenhum trigger as usa** (`notify_chat_message`, `notify_client_chat_message`, `notify_new_chat_message`, `notify_new_message`) → push de chat pode estar silencioso | `messages` | 🟡 A VERIFICAR |
| P7 | 2 BEFORE INSERT em `disputes` validam a mesma regra (`trg_disputes_before_insert` + `trg_validate_dispute_insert`) | `disputes` | 🟢 BAIXO |
| P8 | Funções orphans sem trigger: `ensure_job_allows_chat()`, `ensure_job_chat_allowed(uuid)`, `trg_messages_before_insert()` | — | 🟢 BAIXO |

---

## ✅ O QUE ESTÁ FUNCIONANDO CORRETAMENTE

- **Chat**: `trg_messages_check_job_status` → `ensure_job_chat_allowed()` valida cada INSERT em `messages`
- **Conversas**: `trg_jobs_update_conversation_status` fecha conversa ao terminar/cancelar job
- **Candidatura**: `tr_limit_job_candidates` limita a 4 candidatos por job
- **Histórico**: `trg_job_status_history` registra toda mudança de status
- **Pagamento → Job accepted**: `apply_payment_paid_effects` seta job como `accepted` ao confirmar pagamento
- **RLS conversations**: 4 policies corretas, sem lacunas
- **RLS messages**: 4 policies corretas, sem lacunas críticas

---

## 🗂️ MAPA DE TABELAS

### ✅ Tabelas ativas (sistema Jobs)

| Tabela | Papel |
|---|---|
| `jobs` | Entidade central — `status` controla tudo |
| `job_addresses` | Endereço do job (lat/lng + endereço completo) — **fonte única** |
| `job_candidates` | Prestadores candidatos |
| `job_quotes` | Propostas/orçamentos |
| `payments` | Pagamentos via Pagar.me — tabela principal |
| `job_payments` | Registro secundário de pagamentos |
| `job_photos` | Fotos do job (máx 3, só em `waiting_providers`) |
| `job_actions` | Log de ações |
| `job_status_history` | Histórico de mudanças de status |
| `job_tracking` | Localização em tempo real do prestador |
| `job_rejections` | Log de cancelamentos pós-accepted |
| `disputes` | Disputas abertas após `completed` |
| `dispute_photos` | Fotos de evidência (máx 5/lado, 10 total) |
| `conversations` | Chat (1 por job+provider) |
| `messages` | Mensagens do chat |
| `clients` | Perfil do cliente |
| `providers` | Perfil do prestador |
| `provider_wallets` | Carteira do prestador |
| `provider_service_types` | Serviços que o prestador oferece |
| `notifications` | Notificações in-app |
| `user_devices` | Tokens FCM para push |
| `service_categories` / `service_types` | Catálogo de serviços |
| `audit_logs` | Log geral |
| `admin_users` / `user_roles` | Controle de acesso |

### ⚠️ Tabelas legadas — não usar

| Tabela | Motivo |
|---|---|
| `bookings` | Sistema antigo — substituído por `jobs` |
| `reviews` | Referencia `bookings` — sem equivalente ativo |
| `wallets` | Substituído por `provider_wallets` |
| `profiles` | Sincronizado via trigger — não editar diretamente |

---

## 📋 CICLO DE VIDA DO JOB

### Status válidos (CHECK constraint real)

```
waiting_providers
    → accepted          (somente via webhook Pagar.me)
        → on_the_way    (prestador)
            → in_progress   (prestador)
                → completed     (prestador)
                    → dispute   (cliente, após completed)
                ↘ cancelled_by_client / cancelled_by_provider
            ↘ cancelled_by_client / cancelled_by_provider
        ↘ cancelled_by_client / cancelled_by_provider
    ↘ cancelled_by_client / cancelled_by_provider
```

> ⚠️ **Bug ativo:** `cancel_job_as_client` e `admin_force_cancel_job` usam `status='cancelled'` genérico que **não existe no CHECK**. Corrigir para `cancelled_by_client` ou `cancelled_by_provider`.

### Transições válidas (definidas em `provider_update_job_status`)

| De | Para | Quem |
|---|---|---|
| `waiting_providers` | `accepted` | **Somente** trigger `apply_payment_paid_effects` |
| `accepted` | `on_the_way` | Prestador |
| `accepted` | `cancelled_by_*` | Prestador ou cliente |
| `on_the_way` | `in_progress` | Prestador |
| `on_the_way` | `cancelled_by_*` | Prestador ou cliente |
| `in_progress` | `completed` | Prestador |
| `in_progress` | `cancelled_by_*` | Prestador ou cliente |
| `completed` | `dispute` | Trigger após insert em `disputes` |

---

## 🔐 REGRAS DE ACESSO POR STATUS

### 1. ENDEREÇO (`job_addresses`)

**Decisão arquitetural: usar SOMENTE `job_addresses`.**
As colunas `address_street`, `address_number` etc. em `jobs` são legado. A function `create_job` já popula apenas `job_addresses`.

#### Estado atual da RLS (PROBLEMA P3)

A policy `job_addresses_select_participants` atual:
```sql
-- Libera para qualquer prestador atribuído ao job, SEM checar status
jobs.provider_id IN (SELECT providers.id WHERE providers.user_id = auth.uid())
```
**Isso está ERRADO** — o prestador vê o endereço completo mesmo após `completed` ou `cancelled`.

#### Regra de acesso (definitiva)

| O que o prestador vê | Status do job |
|---|---|
| `lat` + `lng` arredondados (candidato) | `waiting_providers` |
| Endereço completo (rua, número, bairro, cidade) | `accepted`, `on_the_way`, `in_progress`, `dispute` |
| Nada | `completed`, `cancelled_by_client`, `cancelled_by_provider` |

> **Justificativa para `dispute`:** o prestador pode precisar voltar ao local para resolver a disputa.

#### View atual (já implementada) — `v_provider_jobs_accepted`

A view já implementa essa regra corretamente via CASE:
```sql
CASE WHEN j.status = 'completed' THEN NULL ELSE a.street   END AS street,
CASE WHEN j.status = 'completed' THEN NULL ELSE a.number   END AS number,
CASE WHEN j.status = 'completed' THEN NULL ELSE a.district END AS district,
CASE WHEN j.status = 'completed' THEN NULL ELSE a.zipcode  END AS zipcode,
CASE WHEN j.status = 'completed' THEN NULL ELSE a.lat      END AS lat,
CASE WHEN j.status = 'completed' THEN NULL ELSE a.lng      END AS lng,
-- city e state sempre visíveis
```
WHERE inclui: `accepted`, `on_the_way`, `in_progress`, `completed`, `dispute`

> O Flutter lê endereço do prestador **exclusivamente via `v_provider_jobs_accepted`** — não acessa `job_addresses` diretamente.

#### Se quiser criar view adicional para candidatos

```sql
CREATE OR REPLACE VIEW public.job_address_for_provider AS
SELECT
  ja.job_id,
  CASE WHEN j.status IN ('accepted','on_the_way','in_progress','dispute')
    THEN ja.street  ELSE NULL END AS street,
  CASE WHEN j.status IN ('accepted','on_the_way','in_progress','dispute')
    THEN ja.number  ELSE NULL END AS number,
  CASE WHEN j.status IN ('accepted','on_the_way','in_progress','dispute')
    THEN ja.district ELSE NULL END AS district,
  ja.city,
  ja.state,
  CASE WHEN j.status IN ('accepted','on_the_way','in_progress','dispute')
    THEN ja.zipcode ELSE NULL END AS zipcode,
  ja.lat,
  ja.lng,
  j.status AS job_status
FROM public.job_addresses ja
JOIN public.jobs j ON j.id = ja.job_id
JOIN public.job_candidates jc ON jc.job_id = ja.job_id
WHERE jc.provider_id = (
  SELECT id FROM public.providers WHERE user_id = auth.uid() LIMIT 1
);

-- 3. Nova policy: cliente sempre vê, prestador vê lat/lng como candidato
-- (o mascaramento de campos é feito pela view, não pela policy)
CREATE POLICY job_addresses_select_client
ON public.job_addresses FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.jobs j
    WHERE j.id = job_addresses.job_id
    AND j.client_id = auth.uid()
  )
);

CREATE POLICY job_addresses_select_provider_candidate
ON public.job_addresses FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.job_candidates jc
    JOIN public.providers p ON p.id = jc.provider_id
    WHERE jc.job_id = job_addresses.job_id
    AND p.user_id = auth.uid()
  )
);
```

> ⚠️ **Antes de aplicar:** verificar se o Flutter lê `job_addresses` diretamente ou via alguma função RPC. Se for RPC, a correção pode ser feita na função ao invés da policy.

---

### 2. CHAT (`conversations` + `messages`)

#### Estado atual — FUNCIONANDO

- `trg_messages_check_job_status` → `ensure_job_chat_allowed()` valida cada INSERT
- `trg_jobs_update_conversation_status` fecha conversa ao terminar/cancelar
- `set_job_status_dispute_on_open_dispute` reabre como `'dispute'`

#### Regra de acesso (implementada e ativa)

| Chat | Status do job |
|---|---|
| ✅ Liberado | `accepted`, `on_the_way`, `in_progress`, `dispute` |
| ❌ Bloqueado | `completed`, `cancelled_by_client`, `cancelled_by_provider`, `refunded` |

#### Problema P6 — Push de chat pode estar silencioso

As 4 funções de notificação de chat existem mas **nenhum trigger as usa**:
- `notify_chat_message`
- `notify_client_chat_message`
- `notify_new_chat_message`
- `notify_new_message`

**Verificar:** a RPC `send_message` insere diretamente em `notifications`? Se sim, push está funcionando via outra rota. Se não, usuários não recebem push de mensagens.

---

### 3. CANDIDATURA (`job_candidates`)

| Ação | Condição |
|---|---|
| Enviar proposta | Job em `waiting_providers`, máx 4 candidatos (`tr_limit_job_candidates`) |
| Aprovação | Via pagamento (webhook) — `apply_payment_paid_effects` |
| Rejeição dos demais | Automático pelo mesmo trigger |

**Status em `job_candidates`:**
- `status`: `pending` | `approved` | `rejected`
- `decision_status`: `pending` | `under_review` | `approved` | `rejected`
- `client_status`: texto livre (sem CHECK)

---

### 4. PAGAMENTO (`payments`)

#### Problema P2 — `apply_payment_paid_effects` executa 2x no UPDATE

Triggers ativos em `payments`:
- `apply_payment_paid_effects` — AFTER **INSERT + UPDATE**
- `trg_apply_payment_paid_effects` — AFTER **UPDATE**

No UPDATE do payment: a função executa 2 vezes. O job tenta virar `accepted` 2 vezes.
Funcionalmente pode não quebrar (idempotente), mas é risco e gera log duplicado.

**Correção:**
```sql
DROP TRIGGER IF EXISTS apply_payment_paid_effects ON public.payments;
-- Manter somente trg_apply_payment_paid_effects (AFTER UPDATE)
```

#### Problema P5 — Split calculado 2x

- `trg_calc_payment_split` → `calc_payment_split`
- `trg_payments_apply_split` → `payments_apply_split`

Ambos rodam BEFORE INSERT+UPDATE. O segundo sobrescreve o primeiro.
Verificar se as funções são idênticas antes de remover uma.

#### Fluxo correto do pagamento

1. App cria `payments` com `status='pending'`
2. Cliente paga via Pagar.me
3. Webhook → `payments.status = 'paid'`
4. Trigger `apply_payment_paid_effects` → `jobs.status = 'accepted'`, define `provider_id`, aprova/rejeita candidatos
5. Trigger `sync_job_payment_from_payments` → sincroniza `payment_status` + notificações

> ⚠️ **REGRA INVIOLÁVEL:** O status `accepted` do job SÓ deve ser setado por esses triggers. Nunca manualmente.

**Split:** 15% plataforma / 85% prestador (calculado automaticamente no BEFORE INSERT/UPDATE)

---

### 5. DISPUTA (`disputes`)

#### Problema P4 — 3 triggers mudam job para `dispute` no mesmo INSERT

Todos os 3 ativos:
- `trg_disputes_after_insert` → `trg_disputes_after_insert`
- `trg_open_job_dispute` → `trg_open_job_dispute`
- `tr_set_job_status_dispute_on_open_dispute` → `set_job_status_dispute_on_open_dispute`

Funcionalmente não quebra (UPDATE idempotente), mas gera 3 entries no log.

#### Regras de disputa

- Só pode abrir se job estiver `completed` (validado em 2 triggers — P7)
- Só o cliente pode abrir (`open_job_dispute` valida `client_id = auth.uid()`)
- Ao abrir: job → `dispute`, chat → `'dispute'`
- Prazo do prestador: 48h (`response_deadline_at`) — auto-refund se não responder
- Resoluções possíveis (admin via `resolve_dispute_for_job_full`):
  - `keep_payment` → job volta para `completed`
  - `refund_full` → job vai para `cancelled_after_dispute`, pagamento estornado
  - `refund_partial` → parte estornada

**Status em `disputes`:** `open` | `resolved` | `refunded`
**provider_status:** `pending` | `viewed` | `contacted` | `solved`

---

## 🔧 TRIGGERS ATIVOS — ESTADO REAL

### `jobs` (6 triggers)
| Trigger | Evento | Função |
|---|---|---|
| `trg_set_updated_at_jobs` | BEFORE UPDATE | `set_updated_at` |
| `tr_log_job_cancellations` | AFTER UPDATE | `fn_log_job_cancellations` |
| `trg_job_status_history` | AFTER UPDATE | `log_job_status_change` |
| `trg_jobs_update_conversation_status` | AFTER UPDATE | `trg_jobs_update_conversation_status` |
| `trg_notify_job_status` | AFTER UPDATE | `notify_job_status_change` ← **DUPLICADO** |
| `trg_notify_job_status_change` | AFTER UPDATE | `notify_job_status_change` ← **DUPLICADO** |

### `messages` (7 triggers)
| Trigger | Evento | Função |
|---|---|---|
| `trg_messages_check_job_status` | BEFORE INSERT | `ensure_job_chat_allowed` ✅ |
| `trg_messages_before_insert_validate` | BEFORE INSERT | `fn_messages_before_insert_validate` ✅ |
| `trg_messages_no_update` | BEFORE UPDATE | `fn_messages_prevent_update_delete` ✅ |
| `trg_messages_no_delete` | BEFORE DELETE | `fn_messages_prevent_update_delete` ✅ |
| `trg_audit_message_sent` | AFTER INSERT | `fn_audit_log_message_sent` ✅ |
| `trg_dispute_mark_contacted` | AFTER INSERT | `fn_dispute_mark_contacted` ✅ |
| `trg_messages_audit` | AFTER INSERT | `trg_messages_audit` (legacy, não faz nada) |

### `disputes` (9 triggers)
| Trigger | Evento | Função |
|---|---|---|
| `trg_disputes_before_insert` | BEFORE INSERT | validação ← **DUPLICADO com próximo** |
| `trg_validate_dispute_insert` | BEFORE INSERT | validação ← **DUPLICADO** |
| `trg_disputes_limit_provider_update` | BEFORE UPDATE | limita o que provider pode editar ✅ |
| `trg_disputes_after_insert` | AFTER INSERT | job → dispute ← **TRIPLICADO** |
| `trg_open_job_dispute` | AFTER INSERT | job → dispute ← **TRIPLICADO** |
| `tr_set_job_status_dispute_on_open_dispute` | AFTER INSERT+UPDATE | job → dispute ← **TRIPLICADO** |
| `trg_notify_dispute_opened` | AFTER INSERT | notificação ✅ |
| `trg_disputes_after_update` | AFTER UPDATE | job → completed ao resolver ← **DUPLICADO** |
| `trg_close_job_dispute` | AFTER UPDATE | job → completed ao resolver ← **DUPLICADO** |

### `job_candidates` (4 triggers)
| Trigger | Evento | Função |
|---|---|---|
| `tr_limit_job_candidates` | BEFORE INSERT | máx 4 ✅ |
| `trg_notify_client_new_candidate` | AFTER INSERT | notificação cliente ✅ |
| `trg_notify_new_candidate` | AFTER INSERT | notificação (verificar sobreposição) |
| `trg_notify_job_candidates_limit` | AFTER INSERT | notificação limite atingido ✅ |

### `payments` (10 triggers)
| Trigger | Evento | Função |
|---|---|---|
| `trg_calc_payment_split` | BEFORE INSERT+UPDATE | `calc_payment_split` ← **DUPLICADO** |
| `trg_payments_apply_split` | BEFORE INSERT+UPDATE | `payments_apply_split` ← **DUPLICADO** |
| `trg_payments_validate_quote_belongs_to_job` | BEFORE INSERT+UPDATE | validação ✅ |
| `trg_payments_block_amount_change_when_paid` | BEFORE UPDATE | proteção ✅ |
| `trg_set_updated_at_payments` | BEFORE UPDATE | `set_updated_at` ✅ |
| `apply_payment_paid_effects` | AFTER INSERT+UPDATE | ← **DUPLICADO com próximo** |
| `trg_apply_payment_paid_effects` | AFTER UPDATE | `apply_payment_paid_effects` ✅ |
| `trg_sync_job_payment_ins` | AFTER INSERT | `sync_job_payment_from_payments` ✅ |
| `trg_sync_job_payment_upd` | AFTER UPDATE | `sync_job_payment_from_payments` ✅ |
| `trg_sync_dispute_refund_from_payment` | AFTER UPDATE | ✅ |

---

## 🔐 RLS — ESTADO REAL

| Tabela | RLS Ativa | Estado |
|---|---|---|
| `job_addresses` | ✅ SIM | ⚠️ Policy de SELECT não filtra por status (P3) |
| `conversations` | ✅ SIM | ✅ Correto |
| `messages` | ✅ SIM | ✅ Correto |

---

## 🛠️ CORREÇÕES SEGURAS (quando decidir aplicar)

### Grupo A — Sem risco, apenas remove duplicatas

```sql
-- A1. Remove trigger duplicado de notificação de jobs (P1)
-- Manter trg_notify_job_status_change, remover o outro
DROP TRIGGER IF EXISTS trg_notify_job_status ON public.jobs;

-- A2. Remove trigger duplicado de apply_payment_paid_effects (P2)
-- Manter trg_apply_payment_paid_effects (AFTER UPDATE), remover o sem prefixo
DROP TRIGGER IF EXISTS apply_payment_paid_effects ON public.payments;
```

### Grupo B — Requer teste antes

```sql
-- B1. Endereço por status (P3)
-- ANTES: verificar se o Flutter lê job_addresses diretamente ou via RPC
-- Se for via RPC: corrigir na função, não na policy
-- Se for direto: aplicar a view + novas policies (ver seção ENDEREÇO acima)

-- B2. Split duplicado (P5)
-- ANTES: confirmar se calc_payment_split e payments_apply_split são idênticas
-- Se sim: DROP TRIGGER IF EXISTS trg_calc_payment_split ON public.payments;
```

### Grupo C — Investigar antes de qualquer ação

```sql
-- C1. Push de chat silencioso (P6)
-- Verificar na RPC send_message se ela insere em notifications diretamente
-- Se sim: push funciona, as funções orphans são só legado seguro
-- Se não: precisar criar trigger ou ativar uma das funções existentes
```

---

## ✅ CHECKLIST ANTES DE QUALQUER ALTERAÇÃO

```sql
-- Estado atual dos triggers
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- RLS e policies
SELECT tablename, policyname, cmd, qual
FROM pg_policies WHERE schemaname = 'public'
ORDER BY tablename;

-- RLS habilitada
SELECT relname, relrowsecurity FROM pg_class
WHERE relname IN ('jobs','job_addresses','conversations','messages',
                  'job_candidates','payments','disputes');
```

---

## 📌 REGRAS INVIOLÁVEIS

1. **Endereço completo → em `accepted`, `on_the_way`, `in_progress`, `dispute`**
2. **Chat → aberto em `accepted`, `on_the_way`, `in_progress`, `dispute` / fechado nos demais**
3. **Status `accepted` → EXCLUSIVAMENTE via webhook Pagar.me (trigger `apply_payment_paid_effects`)**
4. **Candidatura → somente em `waiting_providers`, limite de 4**
5. **Disputa → somente após `completed`, somente pelo cliente**
6. **Endereço → usar SEMPRE `job_addresses`, nunca as colunas em `jobs`**
7. **Não referenciar `bookings`, `wallets`, `reviews` (legados)**
8. **Antes de adicionar trigger → checar se já existe um fazendo a mesma coisa**
9. **Antes de adicionar RLS policy → checar conflito (policies são aditivas com OR)**
10. **Nunca usar `status='cancelled'` genérico → usar `cancelled_by_client` ou `cancelled_by_provider`**
11. **Antes de remover trigger → confirmar que nenhuma outra rota depende dele**

---

*Salvar como `RENTHUS_JOB_RULES_CONTEXT.md` na raiz do projeto.*
*Adicionar no `CLAUDE.md` do projeto:*
*`"Antes de alterar banco/RLS/triggers/functions, leia RENTHUS_JOB_RULES_CONTEXT.md"`*
