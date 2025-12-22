# Renthus Service

Marketplace de serviços locais (tipo GetNinjas), com foco inicial em prestadores.  
O MVP será lançado em **uma única cidade**, com filtro de prestadores por cidade.

## Objetivo do MVP
- Conectar **clientes → prestadores** de forma simples
- Ajudar prestadores a encontrarem pedidos rapidamente
- Validar aquisição, retenção e monetização com escopo enxuto

## Escopo do MVP
### Inclui
- Lançamento em **uma cidade**
- Cadastro/login via **Supabase Auth**
- Segurança com **RLS** (Row Level Security)
- Fluxo de pedidos (jobs) e candidaturas
- Área do prestador (telas principais)
  - `ProviderMainPage`
  - Financeiro
  - Pedidos
  - Detalhes do pedido (`booking_details_screen.dart`)
- Testes/planejamento de notificações via **Realtime**

### Fora do MVP (por enquanto)
- Multicidades
- Algoritmos avançados de matching/ranking
- Chat complexo em tempo real
- Pagamentos in-app completos
- Sistema de reputação avançado

## Stack
- **Flutter** (frontend)
- **Supabase** (backend)
  - Auth
  - Postgres
  - RLS + Policies
  - Realtime (planejado/testes)

## Modelagem de Dados (Supabase)
Principais tabelas:
- `clients`
- `providers`
- `service_types`
- `jobs`
- `job_candidates`

Fluxo básico:
1. Cliente cria um `job`
2. Prestadores visualizam jobs disponíveis
3. Prestador se candidata em `job_candidates`
4. Cliente seleciona um prestador
5. Job avança no status até conclusão/cancelamento

## Status de Job (referência)
- `open` (aberto)
- `pending` (avaliando candidatos)
- `assigned` (prestador escolhido)
- `in_progress`
- `completed`
- `cancelled`

## Ambiente de Desenvolvimento
- Desenvolvimento local configurado no **Windows**
- Supabase local (ambiente e políticas) já configurados

## Boas práticas e diretrizes
Priorizar sempre:
1. Receita no curto prazo
2. Redução de churn de prestadores
3. Simplicidade técnica (Flutter + Supabase)
4. Manutenibilidade e baixo retrabalho

## Próximos passos (curto prazo)
- Ajustar `booking_details_screen.dart`
- Implementar login/cadastro com Supabase Auth (se ainda não finalizado)
- Testar notificações Realtime
- Consolidar fluxo do prestador (Pedidos + Financeiro)
