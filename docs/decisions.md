# Renthus Service — Decisions Log

Este documento registra decisões importantes do projeto para evitar retrabalho e manter consistência.

> Regra: toda decisão que muda escopo, arquitetura, segurança (RLS) ou monetização deve entrar aqui.

---

## Template de decisão
- **Data:** YYYY-MM-DD
- **Área:** Produto | Arquitetura | Banco/RLS | UI/UX | Monetização | Infra
- **Decisão:**
- **Motivo:**
- **Impacto:**
- **Alternativas consideradas:**
- **Status:** Proposta | Aprovada | Revisar

---

## Decisões registradas

### 2025-12-16 — Produto
- **Área:** Produto
- **Decisão:** MVP será lançado em **uma única cidade**, com filtro inicial de prestadores por **cidade**.
- **Motivo:** Reduz complexidade operacional e técnica, acelera validação do produto.
- **Impacto:** Banco/queries e UI devem assumir cidade como filtro padrão; expansão para multicidades fica para fase posterior.
- **Alternativas consideradas:** Lançar multicidades desde o MVP (rejeitado por aumentar complexidade).
- **Status:** Aprovada

### 2025-11-16 — Arquitetura
- **Área:** Arquitetura / Banco/RLS
- **Decisão:** Stack oficial do MVP: **Flutter + Supabase**, com **RLS** e policies como camada principal de segurança.
- **Motivo:** Velocidade de entrega e segurança robusta sem backend próprio.
- **Impacto:** Regras críticas de acesso ficam no backend; frontend não deve “confiar” em validações locais.
- **Alternativas consideradas:** Backend próprio (rejeitado no MVP).
- **Status:** Aprovada

### 2025-11-16 — Produto / Fluxo
- **Área:** Produto
- **Decisão:** Fluxo base de marketplace: cliente cria `job` → prestadores se candidatam (`job_candidates`) → cliente escolhe.
- **Motivo:** Fluxo simples, padrão de mercado, fácil de validar.
- **Impacto:** UI do prestador e do cliente devem refletir bem os status e transições.
- **Alternativas consideradas:** Matching automático (adiado).
- **Status:** Aprovada

### 2025-12-22 — Monetização
- **Área:** Monetização / Pagamentos
- **Decisão:** Renthus cobra 15% por transação e repassa todas as taxas de pagamento ao prestador.
- **Motivo:** Garantir margem previsível, simplicidade operacional e sustentabilidade no MVP.
- **Impacto:** Cálculo financeiro deve separar taxa da plataforma e taxa do gateway.
- **Status:** Aprovada
