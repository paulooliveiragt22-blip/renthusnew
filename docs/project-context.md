# Renthus Service — Project Context (Source of Truth)

## 1. Visão do Produto
O Renthus Service é um marketplace de serviços locais, inspirado em modelos como GetNinjas, com foco inicial em **prestadores de serviço**.

Objetivo do MVP:
- Conectar clientes a prestadores de forma simples
- Reduzir fricção para o prestador conseguir trabalho
- Validar monetização rapidamente em uma única cidade

---

## 2. Escopo do MVP

### Incluído
- Lançamento em **uma cidade**
- Filtro de prestadores por **cidade**
- Autenticação via **Supabase Auth**
- Segurança com **Row Level Security (RLS)**
- Fluxo de pedidos (jobs) e candidaturas
- Área do prestador como foco inicial
- Status bem definidos para jobs

### Fora do MVP
- Multicidades
- Matching avançado
- Chat complexo em tempo real
- Pagamentos in-app completos
- Sistema de reputação avançado

---

## 3. Stack Técnica

### Frontend
- Flutter

### Backend
- Supabase
  - Auth
  - Postgres
  - RLS
  - Realtime (planejado/testes)

Ambiente local configurado no Windows.

---

## 4. Modelagem de Dados (Supabase)

Tabelas principais:
- `clients`
- `providers`
- `service_types`
- `jobs`
- `job_candidates`

Fluxo base:
1. Cliente cria um job
2. Prestadores visualizam jobs disponíveis
3. Prestador se candidata
4. Cliente escolhe um prestador
5. Job avança no status

---

## 5. Status de Job (referência)
- `open`
- `pending`
- `assigned`
- `in_progress`
- `completed`
- `cancelled`

---

## 6. Regras de Negócio Importantes
- Um job tem apenas **um prestador ativo**
- Prestadores podem se candidatar a vários jobs
- Clientes veem apenas seus próprios jobs
- Prestadores veem apenas jobs disponíveis
- RLS garante isolamento de dados

---

## 7. Estratégia de Monetização (inicial)
Hipóteses:
- Plano premium para prestadores
- Destaque de perfil
- Limite de candidaturas no plano gratuito
- Possível cobrança por lead no futuro

Foco em receita cedo, mesmo com poucos usuários.

---

## 8. Estratégia de Lançamento
- Cidade piloto única
- Aquisição inicial focada em prestadores
- Feedback manual e rápido
- Iteração contínua

---

## 9. Diretrizes de Produto
Priorizar sempre:
1. Receita no curto prazo
2. Redução de churn de prestadores
3. Simplicidade técnica
4. Facilidade de manutenção

---

## 10. Contexto Compacto (para colar em chats)
App: Renthus Service
Stack: Flutter + Supabase
Modelo: Marketplace de serviços locais
MVP: uma cidade, foco em prestadores
Tabelas: clients, providers, service_types, jobs, job_candidates
Fluxo: cliente cria job → prestadores se candidatam → cliente escolhe
Auth + RLS ativos
Prioridade: receita cedo, simplicidade, baixo churn