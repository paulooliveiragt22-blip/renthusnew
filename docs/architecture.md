Flutter App
|
|— Supabase Auth
|— Supabase Database (Postgres)
|— Supabase RLS (Security)
|— Supabase Realtime (eventos e notificações)


---

## Frontend (Flutter)

### Organização sugerida


lib/
├── models/
├── services/
│ ├── auth_service.dart
│ ├── job_service.dart
│ └── provider_service.dart
├── screens/
│ ├── provider/
│ ├── jobs/
│ └── auth/
├── widgets/
└── main.dart


### Responsabilidades
- Renderização de UI
- Validação básica de dados
- Consumo direto do Supabase
- Estado simples (sem complexidade no MVP)

---

## Backend (Supabase)

### Componentes usados
- **Auth**: login e cadastro
- **Database**: Postgres
- **RLS**: controle de acesso por usuário
- **Realtime**: notificações e atualizações futuras

### Princípio chave
> Toda regra crítica de acesso vive no backend (RLS), não no app.

---

## Modelagem de Dados (resumo)

- `clients`
- `providers`
- `service_types`
- `jobs`
- `job_candidates`

Relacionamentos:
- `jobs.client_id → clients.id`
- `job_candidates.job_id → jobs.id`
- `job_candidates.provider_id → providers.id`

---

## Segurança (RLS)
- Usuários só acessam seus próprios dados
- Prestadores veem apenas jobs disponíveis
- Clientes veem apenas seus próprios jobs
- Nenhuma lógica sensível fica apenas no frontend

---

## Estratégia de Escala (futuro)
- Suporte a múltiplas cidades
- Otimização de queries
- Indexação por cidade e status
- Possível cache externo

---

## Decisões Arquiteturais Importantes
- Flutter por produtividade e multiplataforma
- Supabase por velocidade de setup e RLS
- MVP sem microserviços
- Sem backend próprio no início

---

## Regra de Ouro
> Se a arquitetura ficar complexa demais para o MVP, está errada.