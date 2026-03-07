# Diagnóstico do Banco — Renthus

> Dados coletados via query direta ao DB remoto (`dqfejuakbtcxhymrxoqs`).
> Data: 2026-03-07
> `enabled:O` = trigger ativo normalmente (origin mode).

---

## 🔁 TRIGGERS ATIVOS

### `jobs` — 6 triggers

| Trigger | Timing/Evento | Função |
|---|---|---|
| `trg_set_updated_at_jobs` | BEFORE UPDATE | `set_updated_at` |
| `tr_log_job_cancellations` | AFTER UPDATE | `fn_log_job_cancellations` |
| `trg_job_status_history` | AFTER UPDATE | `log_job_status_change` |
| `trg_jobs_update_conversation_status` | AFTER UPDATE | `trg_jobs_update_conversation_status` |
| `trg_notify_job_status` | AFTER UPDATE | `notify_job_status_change` |
| `trg_notify_job_status_change` | AFTER UPDATE | `notify_job_status_change` |

> ⚠️ **CRÍTICO:** `trg_notify_job_status` e `trg_notify_job_status_change` chamam a **mesma função** `notify_job_status_change`. Toda mudança de status gera **2 notificações duplicadas** para cliente e prestador.

---

### `messages` — 7 triggers

| Trigger | Timing/Evento | Função |
|---|---|---|
| `trg_messages_check_job_status` | BEFORE INSERT | `ensure_job_chat_allowed` |
| `trg_messages_before_insert_validate` | BEFORE INSERT | `fn_messages_before_insert_validate` |
| `trg_messages_no_update` | BEFORE UPDATE | `fn_messages_prevent_update_delete` |
| `trg_messages_no_delete` | BEFORE DELETE | `fn_messages_prevent_update_delete` |
| `trg_audit_message_sent` | AFTER INSERT | `fn_audit_log_message_sent` |
| `trg_dispute_mark_contacted` | AFTER INSERT | `fn_dispute_mark_contacted` |
| `trg_messages_audit` | AFTER INSERT | `trg_messages_audit` |

> ⚠️ **ATENÇÃO:** As funções `notify_chat_message`, `notify_client_chat_message`, `notify_new_chat_message` e `notify_new_message` **existem mas nenhum trigger as chama**. Push de chat pode não estar sendo disparado via trigger — verificar se a RPC `send_message` insere diretamente em `notifications`.

---

### `disputes` — 9 triggers

| Trigger | Timing/Evento | Função |
|---|---|---|
| `trg_disputes_before_insert` | BEFORE INSERT | `trg_disputes_before_insert` |
| `trg_validate_dispute_insert` | BEFORE INSERT | `trg_validate_dispute_insert` |
| `trg_disputes_limit_provider_update` | BEFORE UPDATE | `trg_disputes_limit_provider_update` |
| `trg_disputes_after_insert` | AFTER INSERT | `trg_disputes_after_insert` |
| `trg_open_job_dispute` | AFTER INSERT | `trg_open_job_dispute` |
| `tr_set_job_status_dispute_on_open_dispute` | AFTER INSERT UPDATE | `set_job_status_dispute_on_open_dispute` |
| `trg_notify_dispute_opened` | AFTER INSERT | `notify_dispute_opened` |
| `trg_disputes_after_update` | AFTER UPDATE | `trg_disputes_after_update` |
| `trg_close_job_dispute` | AFTER UPDATE | `trg_close_job_dispute` |

> ⚠️ **CRÍTICO (confirmado):** No INSERT em `disputes`, três triggers mudam o job para `dispute`:
> - `trg_disputes_after_insert` → `trg_disputes_after_insert`
> - `trg_open_job_dispute` → `trg_open_job_dispute`
> - `tr_set_job_status_dispute_on_open_dispute` → `set_job_status_dispute_on_open_dispute`
>
> Dois BEFORE INSERT validam a mesma regra (`trg_disputes_before_insert` + `trg_validate_dispute_insert`).

---

### `job_candidates` — 4 triggers

| Trigger | Timing/Evento | Função |
|---|---|---|
| `tr_limit_job_candidates` | BEFORE INSERT | `fn_limit_job_candidates` |
| `trg_notify_client_new_candidate` | AFTER INSERT | `notify_client_new_candidate` |
| `trg_notify_job_candidates_limit` | AFTER INSERT | `notify_job_candidates_limit` |
| `trg_notify_new_candidate` | AFTER INSERT | `notify_new_candidate` |

> ⚠️ **ATENÇÃO:** 3 triggers de notificação no INSERT. Verificar se `notify_client_new_candidate`, `notify_new_candidate` e `notify_job_candidates_limit` criam notificações distintas ou se há sobreposição.

---

### `payments` — 10 triggers

| Trigger | Timing/Evento | Função |
|---|---|---|
| `trg_calc_payment_split` | BEFORE INSERT UPDATE | `calc_payment_split` |
| `trg_payments_apply_split` | BEFORE INSERT UPDATE | `payments_apply_split` |
| `trg_payments_validate_quote_belongs_to_job` | BEFORE INSERT UPDATE | `payments_validate_quote_belongs_to_job` |
| `trg_payments_block_amount_change_when_paid` | BEFORE UPDATE | `payments_block_amount_change_when_paid` |
| `trg_set_updated_at_payments` | BEFORE UPDATE | `set_updated_at` |
| `apply_payment_paid_effects` | AFTER INSERT UPDATE | `apply_payment_paid_effects` |
| `trg_apply_payment_paid_effects` | AFTER UPDATE | `apply_payment_paid_effects` |
| `trg_sync_job_payment_ins` | AFTER INSERT | `sync_job_payment_from_payments` |
| `trg_sync_job_payment_upd` | AFTER UPDATE | `sync_job_payment_from_payments` |
| `trg_sync_dispute_refund_from_payment` | AFTER UPDATE | `sync_dispute_refund_from_payment` |

> ⚠️ **CRÍTICO:** `apply_payment_paid_effects` (AFTER INSERT UPDATE) e `trg_apply_payment_paid_effects` (AFTER UPDATE) chamam a **mesma função**. No UPDATE do payment, `apply_payment_paid_effects` dispara **2 vezes** — o job pode tentar virar `accepted` duas vezes.
>
> ⚠️ **ATENÇÃO:** `trg_calc_payment_split` e `trg_payments_apply_split` ambos rodam BEFORE INSERT UPDATE e calculam o split — funções diferentes (`calc_payment_split` vs `payments_apply_split`). Verificar se são redundantes ou se uma sobrescreve a outra.

---

## 🔐 RLS STATUS

| Tabela | RLS Habilitada | RLS Forçada |
|---|---|---|
| `job_addresses` | ✅ SIM | ❌ NÃO |
| `conversations` | ✅ SIM | ❌ NÃO |
| `messages` | ✅ SIM | ❌ NÃO |

---

## 🔐 RLS POLICIES

### `conversations` — 4 policies

| Policy | Comando | Regra resumida |
|---|---|---|
| `conversations_admin_select_all` | SELECT | `is_admin()` |
| `conversations_insert_participants` | INSERT | `client_id = auth.uid()` OR provider via `providers.user_id` |
| `conversations_select_participants` | SELECT | `client_id = auth.uid()` OR provider via `providers.user_id` |
| `conversations_update_participants` | UPDATE | Mesma regra do select |

Sem lacunas. Não há policy de DELETE (intencional — conversations não devem ser deletadas).

---

### `job_addresses` — 3 policies

| Policy | Comando | Regra resumida |
|---|---|---|
| `job_addresses_insert_client` | INSERT | `job_id` pertence ao `auth.uid()` como cliente |
| `job_addresses_select_participants` | SELECT | job client OR `jobs.provider_id` via providers |
| `job_addresses_update_client` | UPDATE | Somente o cliente do job |

> A policy não filtra por status do job, mas na prática o risco é baixo: o app Flutter lê endereço do prestador exclusivamente via `v_provider_jobs_accepted`, que já aplica CASE por status (retorna NULL para rua/número/bairro em `completed`).
>
> **Regra de acesso vigente:** endereço completo visível em `accepted`, `on_the_way`, `in_progress`, `dispute`. Oculto em `completed` e `cancelled_*`.
>
> Não existe policy de DELETE (intencional).

---

### `messages` — 4 policies

| Policy | Comando | Regra resumida |
|---|---|---|
| `messages_admin_select_all` | SELECT | `is_admin()` |
| `messages_insert_participants` | INSERT | Participante da conversation |
| `messages_select_participants` | SELECT | Participante da conversation |
| `messages_update_participants` | UPDATE | Participante (via `providers.user_id`) |

Sem lacunas críticas.

---

## 🔧 FUNCTIONS: Chat e Endereço

| Função | Status |
|---|---|
| `ensure_job_allows_chat()` | ⚠️ Existe mas **nenhum trigger a chama** — orphan |
| `ensure_job_chat_allowed()` | ✅ Usada por `trg_messages_check_job_status` |
| `ensure_job_chat_allowed(p_conversation_id uuid)` | ⚠️ Versão com parâmetro — não usada por nenhum trigger |
| `fn_messages_before_insert_validate()` | ✅ Usada por `trg_messages_before_insert_validate` |
| `fn_messages_prevent_update_delete()` | ✅ Usada por `trg_messages_no_update` e `trg_messages_no_delete` |
| `fn_audit_log_message_sent()` | ✅ Usada por `trg_audit_message_sent` |
| `notify_chat_message()` | ⚠️ **Orphan — nenhum trigger a chama** |
| `notify_client_chat_message()` | ⚠️ **Orphan — nenhum trigger a chama** |
| `notify_new_chat_message()` | ⚠️ **Orphan — nenhum trigger a chama** |
| `notify_new_message()` | ⚠️ **Orphan — nenhum trigger a chama** |
| `trg_messages_before_insert()` | ⚠️ Function existe mas **nenhum trigger a usa** — orphan |
| `trg_messages_audit()` | ✅ Usada por `trg_messages_audit` |
| `send_message(p_conversation_id, p_sender_role, p_content, p_type, p_image_url)` | ✅ RPC ativa |
| `upsert_conversation_for_job(p_job_id, p_provider_id)` | ✅ RPC ativa |
| `rpc_provider_update_address(p_cep, p_address_street, ...)` | ✅ RPC ativa |

---

## 🚨 RESUMO DE PROBLEMAS

| # | Problema | Tabela | Severidade |
|---|---|---|---|
| 1 | `trg_notify_job_status` e `trg_notify_job_status_change` chamam a mesma função → notificações duplicadas a cada mudança de status | `jobs` | 🔴 ALTO |
| 2 | `apply_payment_paid_effects` e `trg_apply_payment_paid_effects` chamam a mesma função → `apply_payment_paid_effects` executa 2x no UPDATE | `payments` | 🔴 ALTO |
| 3 | 3 triggers distintos colocam o job em `dispute` no mesmo INSERT | `disputes` | 🟡 MÉDIO |
| 4 | `trg_calc_payment_split` e `trg_payments_apply_split` calculam split simultaneamente | `payments` | 🟡 MÉDIO |
| 5 | RLS de `job_addresses` não filtra por status, mas `v_provider_jobs_accepted` já aplica CASE correto — comportamento atual está alinhado com a regra de negócio | `job_addresses` | ✅ OK |
| 6 | 4 funções de notificação de chat existem mas nenhum trigger as usa — push de chat pode estar silencioso | `messages` | 🟡 A VERIFICAR |
| 7 | `ensure_job_allows_chat()`, `ensure_job_chat_allowed(uuid)` e `trg_messages_before_insert()` são funções orphans | — | 🟢 BAIXO |
| 8 | Dois BEFORE INSERT em `disputes` validam a mesma regra (duplicata inofensiva) | `disputes` | 🟢 BAIXO |

---

## ✅ Correções Recomendadas (quando decidir aplicar)

```sql
-- 1. Remover trigger duplicado de notificação de jobs
DROP TRIGGER IF EXISTS trg_notify_job_status_change ON public.jobs;

-- 2. Remover trigger duplicado de apply_payment_paid_effects (manter o sem prefixo trg_ ou vice-versa)
DROP TRIGGER IF EXISTS trg_apply_payment_paid_effects ON public.payments;

-- 5. Criar view job_address_for_provider com filtro de status (ver RENTHUS_JOB_RULES_CONTEXT.md)
-- A view deve expor endereço completo somente em: accepted, on_the_way, in_progress
```

> Antes de aplicar qualquer correção, releia `RENTHUS_JOB_RULES_CONTEXT.md`.
