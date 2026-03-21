# Repository Analysis & Improvement Suggestions

## Visão geral
- Aplicativo Flutter com Supabase como backend principal, incluindo autenticação e sincronização de tokens do Firebase Cloud Messaging (FCM).
- Inicialização do Supabase e do Firebase ocorre em `lib/main.dart`, e o app inicia com `RoleSelectionPage` fixando o locale em `pt-BR`.
- Integrações principais: sincronização de dispositivos FCM (`FcmDeviceSync`), roteamento global via `AppNavigator` e navegação baseada em cargo com `UserRoleHolder`.

## Pontos fortes atuais
- Configuração de push notifications já integrada com listeners para eventos de foreground, background e abertura inicial.
- Fluxo de busca de serviços implementado com paginação, filtros e debounce no texto de busca.
- Organização por domínios (screens, repositories, services) já visível na estrutura de pastas.

## Riscos e oportunidades de melhoria

### 1) Gestão de configuração e segredos
- A URL e a `anonKey` do Supabase estão hardcoded diretamente em `main.dart` e duplicadas em `env.dart`, expondo credenciais e dificultando alternância de ambientes.
- Recomenda-se mover chaves para variáveis de ambiente e centralizar leitura/configuração em um único ponto (p.ex. `lib/env.dart`), carregando valores por flavor ou por `.env` ignorado pelo Git.

### 2) Push notifications e sincronização de dispositivos
- O app registra tokens em dois fluxos distintos: `FcmDeviceSync` no `main.dart` e `_saveDeviceToken` dentro de `PushNotificationService`, ambos realizando `upsert` na tabela `user_devices`.
- Essa duplicidade pode gerar gravações redundantes e caminhos de código diferentes para a mesma responsabilidade.
- Sugestão: consolidar a sincronização de tokens em um único serviço, incluindo limpeza no logout e tratamento de erros/logs estruturados.

### 3) Persistência e gestão do papel do usuário
- `UserRoleHolder` guarda o papel apenas em memória; `PushNavigationHandler` depende desse valor ao interpretar notificações.
- Após reiniciar o app, o papel anterior se perde e notificações podem navegar para a área errada.
- Sugere-se persistir o papel (p.ex. `SharedPreferences`) e expor um stream para reatividade ao longo do app.

### 4) Camada de dados da busca de serviços
- `SearchServicesScreen` está no diretório de services, mas é uma tela completa que chama Supabase diretamente e manipula `Map<String, dynamic>`.
- Falta um repositório/DTO tipado para os itens de catálogo e um controlador dedicado para paginação/estado (p.ex. `ChangeNotifier` ou bloc), o que reduz testabilidade.
- Reorganizar a tela para `lib/screens` e mover o acesso a dados para um repositório permitiria testes unitários e melhores mensagens de erro.

### 5) Testes automatizados desatualizados
- O único teste (`test/widget_test.dart`) ainda referencia `MyApp` no pacote `renthus_new`, que não existe mais, indicando que a suíte está quebrada/obsoleta.
- Criar smoke tests mínimos que inicializem `RenthusApp` e cubram fluxos críticos (login, listagem de serviços) ajudaria a proteger regressões.

## Próximos passos sugeridos (prioridade)
1. **Configuração segura**: extrair URL/anonKey para variáveis de ambiente e remover chaves do código fonte.
2. **Consolidar FCM**: unificar o fluxo de registro/refresh de tokens e implementar limpeza de `user_devices` no logout.
3. **Persistir papel**: armazenar e observar o papel atual do usuário para navegação consistente, inclusive em notificações.
4. **Refatorar busca**: mover `SearchServicesScreen` para `screens`, criar modelo/repositório para o catálogo e separar lógica de estado da UI.
5. **Atualizar testes**: substituir o teste boilerplate por cenários reais do app e integrá-los ao pipeline de CI.
