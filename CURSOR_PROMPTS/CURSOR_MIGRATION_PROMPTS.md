# 🎯 CURSOR MIGRATION PROMPTS - GUIA COMPLETO

## 📋 COMO USAR ESTE GUIA:

1. Abra o Cursor no seu projeto
2. Pressione `Cmd/Ctrl + L` para Chat ou `Cmd/Ctrl + Shift + I` para Composer
3. Copie o prompt desejado
4. Substitua [VARIÁVEIS] com seus valores
5. Cole no Cursor
6. Revise e aceite as mudanças

---

## 🎨 SETUP INICIAL (FAZER UMA VEZ)

### **Prompt 1: Criar arquivo de contexto**

```
Crie um arquivo .cursorrules na raiz do projeto com estas regras para migração:

CONTEXTO DO PROJETO:
- Nome: Renthus
- Plataforma: Flutter + Supabase
- Estado atual: setState com StatefulWidget
- Estado desejado: Riverpod 3.0 + ConsumerWidget
- Obrigatório: Manter 100% dos layouts originais

ESTRUTURA ANTIGA:
- Screens: lib/screens/
- Repositories: lib/repositories/
- Services: lib/services/
- Models: lib/models/

ESTRUTURA NOVA:
- Features: lib/features/[feature]/
  - domain/models/ (Freezed models)
  - data/repositories/ (Supabase calls)
  - data/providers/ (Riverpod providers)
  - presentation/pages/ (ConsumerWidget screens)

PROVIDERS DISPONÍVEIS:
- Auth: authStateProvider, authActionsProvider
- Jobs: jobsListProvider(city, status), jobByIdProvider(id), jobsStreamProvider(city), jobActionsProvider
- Chat: conversationsStreamProvider(userId), messagesStreamProvider(conversationId), chatActionsProvider, unreadMessagesCountProvider(userId)
- Notifications: notificationsStreamProvider(userId), notificationActionsProvider, unreadNotificationsCountProvider(userId)
- Profile: userProfileNotifierProvider

REGRAS DE MIGRAÇÃO:
1. NUNCA alterar UI/layout/widgets visuais
2. Trocar StatefulWidget → ConsumerWidget ou ConsumerStatefulWidget
3. Remover setState() → usar ref.watch()
4. Usar AsyncValue.when() para loading/error/data
5. Imports: SEMPRE usar package:renthus/... (nunca relativos)
6. Manter nomes de variáveis e métodos quando possível
7. Adicionar comentários explicando mudanças importantes
8. Preservar toda lógica de negócio

EXEMPLO REFERÊNCIA:
lib/features/profile/presentation/pages/profile_screen.dart

PADRÃO DE IMPORTS:
```dart
// Core
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Providers
import 'package:renthus/features/[feature]/data/providers/[feature]_providers.dart';

// Models (se necessário)
import 'package:renthus/features/[feature]/domain/models/[model]_model.dart';
```

PADRÃO ConsumerWidget:
```dart
class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(someProvider);
    
    return dataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Erro: $error')),
      data: (data) => // SEU WIDGET ORIGINAL AQUI
    );
  }
}
```

PADRÃO ConsumerStatefulWidget (quando precisa de controllers):
```dart
class MyScreen extends ConsumerStatefulWidget {
  const MyScreen({super.key});
  
  @override
  ConsumerState<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends ConsumerState<MyScreen> {
  final _controller = TextEditingController();
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(someProvider);
    // ... resto do código
  }
}
```
```

---

## 📱 PROMPTS POR TIPO DE TELA

### **🔐 TELA DE LOGIN**

```
Migre @screens/login_screen.dart para Riverpod seguindo as regras do .cursorrules:

OBJETIVO:
Criar lib/features/auth/presentation/pages/login_screen.dart

PROVIDERS A USAR:
- authActionsProvider.notifier para login
- authStateProvider para estados de loading/error

MANTER:
- Todo o layout visual (TextFields, Buttons, logos, cores)
- Validações de formulário
- Navegação após login

ADICIONAR:
- AsyncValue.when() para states
- Error handling visual
- Loading indicator durante login

REMOVER:
- setState
- AuthService direto
- Variáveis de estado manual (_loading, _error)

REFERÊNCIA:
Use @features/profile/presentation/pages/profile_screen.dart como exemplo de padrão

RESULTADO ESPERADO:
1. Arquivo novo criado
2. Imports corrigidos
3. Layout idêntico
4. Código mais limpo
5. Lista de mudanças feitas
```

---

### **📝 TELA DE CADASTRO**

```
Migre @screens/[SIGNUP_FILE].dart para Riverpod:

OBJETIVO:
Criar lib/features/auth/presentation/pages/[signup]_page.dart

PROVIDERS:
- authActionsProvider.notifier.signup()
- Manter validações de formulário

ATENÇÃO ESPECIAL:
- Multi-step form: manter estado dos steps
- Upload de foto: usar authActionsProvider para upload
- Validações: manter todas (CPF, telefone, etc)

LAYOUT:
- Manter exatamente igual
- Mesmos steps
- Mesmos botões e navegação

MOSTRE:
1. Código antes/depois
2. Mudanças nos imports
3. Como ficou o gerenciamento de steps
```

---

### **📋 LISTA DE SERVIÇOS (Jobs)**

```
Migre @screens/client_home_page.dart para Riverpod:

OBJETIVO:
Criar lib/features/jobs/presentation/pages/jobs_list_page.dart

PROVIDERS:
- jobsListProvider(city: 'Sorriso', status: null) para lista
- jobsStreamProvider(city: 'Sorriso') se precisar real-time

MANTER:
- Grid ou ListView de jobs
- Cards de job
- Filtros (cidade, categoria)
- Pull-to-refresh
- Shimmer loading (se tiver)

PADRÃO:
```dart
final jobsAsync = ref.watch(jobsListProvider(city: 'Sorriso'));

return jobsAsync.when(
  loading: () => ShimmerLoading(),
  error: (e, s) => ErrorWidget(
    error: e,
    onRetry: () => ref.invalidate(jobsListProvider),
  ),
  data: (jobs) => jobs.isEmpty 
    ? EmptyState(message: 'Nenhum serviço disponível')
    : ListView.builder(
        itemCount: jobs.length,
        itemBuilder: (context, i) => JobCard(job: jobs[i]),
      ),
);
```

FILTROS:
Se tiver filtro de cidade, use:
```dart
final selectedCity = useState('Sorriso');
final jobsAsync = ref.watch(jobsListProvider(city: selectedCity.value));
```
```

---

### **📄 DETALHES DE SERVIÇO**

```
Migre @screens/job_details_page.dart para Riverpod:

OBJETIVO:
Criar lib/features/jobs/presentation/pages/job_details_page.dart

PROVIDERS:
- jobByIdProvider(jobId) para buscar job
- jobActionsProvider.notifier.update() para aceitar/cancelar

RECEBE:
- jobId como parâmetro (String)

MANTER:
- Todo layout de detalhes
- Botões de ação (aceitar, cancelar, chat)
- Informações do cliente
- Mapa/localização

AÇÕES:
```dart
Future<void> acceptJob() async {
  final actions = ref.read(jobActionsProvider.notifier);
  await actions.update(jobId, {'status': 'accepted'});
  
  if (mounted) {
    Navigator.pop(context);
  }
}
```

NAVEGAÇÃO PARA CHAT:
```dart
final conversation = await ref.read(
  conversationByJobProvider(jobId).future
);
Navigator.push(...);
```
```

---

### **💬 LISTA DE CONVERSAS (Chat)**

```
Migre @screens/client_chats_page.dart para Riverpod:

OBJETIVO:
Criar lib/features/chat/presentation/pages/conversations_page.dart

PROVIDERS:
- conversationsStreamProvider(userId) para real-time
- unreadMessagesCountProvider(userId) para badge

IMPORTANTE:
- Usar STREAM (não Future) para real-time
- Badge com unread count
- Avatar da outra pessoa
- Última mensagem
- Horário relativo

PADRÃO:
```dart
final user = ref.watch(currentUserProvider);
final conversationsAsync = ref.watch(conversationsStreamProvider(user!.id));

return conversationsAsync.when(
  loading: () => LoadingWidget(),
  error: (e, s) => ErrorWidget(error: e),
  data: (conversations) => ListView.builder(
    itemCount: conversations.length,
    itemBuilder: (context, i) {
      final conv = conversations[i];
      return ListTile(
        leading: CircleAvatar(
          backgroundImage: conv.getOtherPersonPhoto(user.id) != null
            ? NetworkImage(conv.getOtherPersonPhoto(user.id)!)
            : null,
        ),
        title: Text(conv.getOtherPersonName(user.id)),
        subtitle: Text(conv.lastMessage ?? ''),
        trailing: conv.hasUnread 
          ? Badge(label: Text('${conv.unreadCount}'))
          : Text(conv.lastMessageTimeFormatted),
        onTap: () => Navigator.push(...),
      );
    },
  ),
);
```
```

---

### **💬 TELA DE CHAT (Mensagens)**

```
Migre @screens/chat_page.dart para Riverpod:

OBJETIVO:
Criar lib/features/chat/presentation/pages/chat_page.dart

PROVIDERS:
- messagesStreamProvider(conversationId) para real-time messages
- chatActionsProvider.notifier.sendMessage() para enviar
- chatActionsProvider.notifier.markAsRead() para marcar lido

PARÂMETROS:
- conversationId: String

MANTER:
- Input de mensagem (TextField)
- ListView de mensagens (reverse: true)
- Bubbles diferentes para sender/receiver
- Upload de imagem
- Timestamps

IMPORTANTE:
- Marcar como lido ao abrir: useEffect no initState
- Auto-scroll para última mensagem
- Keyboard handling

PADRÃO:
```dart
class ChatPage extends ConsumerStatefulWidget {
  final String conversationId;
  
  const ChatPage({super.key, required this.conversationId});
  
  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  
  @override
  void initState() {
    super.initState();
    // Marcar como lido
    Future.microtask(() {
      final user = ref.read(currentUserProvider);
      ref.read(chatActionsProvider.notifier).markAsRead(
        widget.conversationId,
        user!.id,
      );
    });
  }
  
  Future<void> _sendMessage() async {
    final user = ref.read(currentUserProvider);
    final actions = ref.read(chatActionsProvider.notifier);
    
    await actions.sendMessage(
      conversationId: widget.conversationId,
      senderId: user!.id,
      content: _messageCtrl.text,
    );
    
    _messageCtrl.clear();
    _scrollCtrl.animateTo(0, duration: Duration(milliseconds: 300), curve: Curves.easeOut);
  }
  
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final messagesAsync = ref.watch(messagesStreamProvider(widget.conversationId));
    
    return Scaffold(
      appBar: AppBar(title: Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => LoadingWidget(),
              error: (e, s) => ErrorWidget(error: e),
              data: (messages) => ListView.builder(
                controller: _scrollCtrl,
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final msg = messages[i];
                  return MessageBubble(
                    message: msg,
                    isMine: msg.isMine(user!.id),
                  );
                },
              ),
            ),
          ),
          MessageInput(
            controller: _messageCtrl,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}
```
```

---

### **🔔 NOTIFICAÇÕES**

```
Migre @screens/notifications_page.dart para Riverpod:

OBJETIVO:
Criar lib/features/notifications/presentation/pages/notifications_page.dart

PROVIDERS:
- notificationsStreamProvider(userId) para real-time
- notificationActionsProvider.notifier.markAsRead(id, userId)
- notificationActionsProvider.notifier.markAllAsRead(userId)

MANTER:
- Lista de notificações
- Badge de não lidas
- Botão "marcar todas como lidas"
- Ícones por tipo
- Horário relativo
- Navegação ao clicar

PADRÃO:
```dart
final user = ref.watch(currentUserProvider);
final notificationsAsync = ref.watch(notificationsStreamProvider(user!.id));

return Scaffold(
  appBar: AppBar(
    title: Text('Notificações'),
    actions: [
      IconButton(
        icon: Icon(Icons.done_all),
        onPressed: () {
          ref.read(notificationActionsProvider.notifier).markAllAsRead(user.id);
        },
      ),
    ],
  ),
  body: notificationsAsync.when(
    loading: () => LoadingWidget(),
    error: (e, s) => ErrorWidget(error: e),
    data: (notifications) => ListView.builder(
      itemCount: notifications.length,
      itemBuilder: (context, i) {
        final notif = notifications[i];
        return ListTile(
          leading: Text(notif.icon, style: TextStyle(fontSize: 24)),
          title: Text(notif.title),
          subtitle: Text(notif.body),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(notif.timeAgo, style: TextStyle(fontSize: 12)),
              if (!notif.isRead) Icon(Icons.circle, size: 8, color: Colors.blue),
            ],
          ),
          onTap: () async {
            await ref.read(notificationActionsProvider.notifier)
              .markAsRead(notif.id, user.id);
            // Navigate based on notif.type
          },
        );
      },
    ),
  ),
);
```
```

---

### **👤 PERFIL DO USUÁRIO**

```
ESTE JÁ ESTÁ MIGRADO! ✅

Use como referência:
@features/profile/presentation/pages/profile_screen.dart

Se precisar migrar outra tela de perfil, copie o padrão deste arquivo.
```

---

### **📊 DASHBOARD/HOME**

```
Migre @screens/[provider/client]_main_page.dart para Riverpod:

OBJETIVO:
Criar lib/features/dashboard/presentation/pages/[role]_dashboard_page.dart

PROVIDERS:
- currentUserProvider para dados do usuário
- unreadMessagesCountProvider(userId) para badge chat
- unreadNotificationsCountProvider(userId) para badge notificações
- Outros providers conforme necessário

MANTER:
- Bottom navigation bar
- Badges de unread
- Drawer/menu lateral
- Widgets de estatísticas

PADRÃO:
```dart
final user = ref.watch(currentUserProvider);
final unreadMessages = ref.watch(unreadMessagesCountProvider(user!.id));
final unreadNotifs = ref.watch(unreadNotificationsCountProvider(user.id));

return Scaffold(
  appBar: AppBar(
    title: Text('Olá, ${user.name}'),
    actions: [
      Stack(
        children: [
          IconButton(
            icon: Icon(Icons.notifications),
            onPressed: () => Navigator.push(...),
          ),
          if (unreadNotifs.value != null && unreadNotifs.value! > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Badge(label: Text('${unreadNotifs.value}')),
            ),
        ],
      ),
    ],
  ),
  bottomNavigationBar: BottomNavigationBar(
    items: [
      BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      BottomNavigationBarItem(
        icon: Stack(
          children: [
            Icon(Icons.chat),
            if (unreadMessages.value != null && unreadMessages.value! > 0)
              Positioned(
                right: 0,
                child: Badge(label: Text('${unreadMessages.value}')),
              ),
          ],
        ),
        label: 'Chat',
      ),
    ],
  ),
);
```
```

---

## 🔧 PROMPTS UTILITÁRIOS

### **🔍 ANALISAR ARQUIVO ANTES DE MIGRAR**

```
Analise @screens/[ARQUIVO].dart e me diga:

1. É StatefulWidget ou StatelessWidget?
2. Quais dados busca do Supabase?
3. Usa setState em quantos lugares?
4. Tem controllers (TextField, ScrollController)?
5. Tem formulários?
6. Tem navegação para outras telas?
7. Tem upload de arquivos/imagens?
8. Qual provider devo usar?
9. Dificuldade estimada: fácil/média/difícil?
10. Tempo estimado de migração?

Com base nisso, sugira o melhor approach para migrar.
```

---

### **📦 CORRIGIR IMPORTS EM MASSA**

```
Encontre todos os arquivos em lib/ que importam [ARQUIVO_ANTIGO] e:

1. Liste todos os arquivos afetados
2. Mostre o import antigo e o novo para cada um
3. Atualize automaticamente todos os imports para:
   package:renthus/features/[feature]/presentation/pages/[arquivo].dart

EXEMPLO:
Antigo: import '../screens/login_screen.dart';
Novo: import 'package:renthus/features/auth/presentation/pages/login_screen.dart';

Execute a substituição e confirme quantos arquivos foram atualizados.
```

---

### **✅ REVISAR CÓDIGO MIGRADO**

```
Revise o arquivo migrado @features/[FEATURE]/presentation/pages/[ARQUIVO].dart:

CHECKLIST:
[ ] Layout permaneceu 100% igual ao original?
[ ] Todos os imports estão corretos (package:renthus/...)?
[ ] Usa ConsumerWidget ou ConsumerStatefulWidget?
[ ] Não tem setState?
[ ] Usa ref.watch() para dados?
[ ] Usa .when() para loading/error/data?
[ ] Providers corretos estão sendo usados?
[ ] Controllers (se houver) são disposed corretamente?
[ ] Navegação funciona igual?
[ ] Formulários validam igual?
[ ] Erros são tratados com UI?
[ ] Loading states são mostrados?
[ ] Empty states são mostrados?

Para cada item, responda ✅ ou ❌ e explique se ❌.
Se houver problemas, sugira correções.
```

---

### **🔄 COMPARAR ANTES E DEPOIS**

```
Compare @screens/[ARQUIVO_ANTIGO].dart com @features/[...]/[ARQUIVO_NOVO].dart:

MOSTRE:
1. Linhas de código: antes vs depois
2. Complexidade ciclomática estimada
3. Número de rebuilds (antes tinha setState em X lugares)
4. Diferenças visuais (deve ser zero!)
5. Novas funcionalidades adicionadas (loading/error states)
6. Imports: quantos mudaram
7. Performance esperada: melhor/igual/pior

FORMATO:
┌─────────────────────┬────────┬────────┐
│ Métrica             │ Antes  │ Depois │
├─────────────────────┼────────┼────────┤
│ Linhas de código    │ XXX    │ XXX    │
│ setState calls      │ XX     │ 0      │
│ Imports             │ XX     │ XX     │
│ ...                 │        │        │
└─────────────────────┴────────┴────────┘
```

---

### **🐛 ENCONTRAR BUGS POTENCIAIS**

```
Analise @features/[...]/[ARQUIVO].dart procurando bugs potenciais:

VERIFICAR:
1. Memory leaks (controllers não disposed)
2. Null safety issues
3. Async sem await
4. Navegação sem mounted check
5. Providers lendo sem watch no build
6. setState após dispose
7. Infinite loops
8. Race conditions

Para cada bug encontrado:
- Linha aproximada
- Descrição do problema
- Sugestão de correção
- Severidade: crítico/alto/médio/baixo
```

---

## 🎯 PROMPTS POR WORKFLOW

### **📋 WORKFLOW 1: MIGRAR FEATURE COMPLETA**

```
Vou migrar a feature [JOBS/CHAT/AUTH/NOTIFICATIONS] completa.

ETAPA 1 - PLANEJAMENTO:
Liste todos os arquivos relacionados a [FEATURE] em screens/ que precisam migrar.
Para cada arquivo, indique:
- Nome atual
- Nome novo (onde criar)
- Providers necessários
- Dependências de outros arquivos
- Ordem sugerida de migração

ETAPA 2 - MIGRAÇÃO:
Após minha confirmação, migre os arquivos na ordem sugerida, um por vez.


ETAPA 3 - REVISÃO:
Após todas as migrações, revise:
- Todos imports foram atualizados?
- Algum arquivo ainda referencia screens/?
- Há testes quebrados?
- Sugestões de melhorias?
```

---

### **📋 WORKFLOW 2: MIGRAÇÃO INCREMENTAL (DIA A DIA)**

```
SEGUNDA-FEIRA - Auth:
Migre hoje: login_screen.dart e signup_step1.dart
Amanhã continuamos com signup_step2.dart

TERÇA-FEIRA - Auth (continuação):
Migre: signup_step2.dart e phone_verification.dart

QUARTA-FEIRA - Jobs (início):
Migre: client_home_page.dart (lista de jobs)

... e assim por diante
```

---

### **📋 WORKFLOW 3: CORREÇÃO DE IMPORTS PÓS-MIGRAÇÃO**

```
Acabei de migrar [ARQUIVO]. Agora preciso:

1. Encontrar TODOS os arquivos que importam o arquivo antigo
2. Listar cada import que precisa mudar
3. Atualizar automaticamente todos
4. Verificar se quebrou algo
5. Rodar flutter analyze mentalmente
6. Me avisar se houver problemas

Execute e confirme quando terminar.
```

---

## 📊 PROMPTS DE ANÁLISE E MÉTRICAS

### **📈 PROGRESSO DA MIGRAÇÃO**

```
Analise o projeto e me diga:

ESTATÍSTICAS:
├── Total de arquivos .dart em screens/: ?
├── Total já migrados para features/: ?
├── Porcentagem concluída: ?
├── Arquivos ainda usando StatefulWidget: ?
├── Arquivos ainda usando setState: ?
├── Arquivos usando ConsumerWidget: ?
├── Imports relativos (..) restantes: ?
└── Imports absolutos (package:): ?

PRÓXIMOS PASSOS:
Liste os 5 arquivos mais importantes a migrar agora.

RISCOS:
Liste arquivos que podem quebrar a build se migrados agora.
```

---

### **🔍 ANÁLISE DE DEPENDÊNCIAS**

```
Para o arquivo @screens/[ARQUIVO].dart, analise:

DEPENDE DE:
- Quais outros arquivos ele importa?
- Quais desses já foram migrados?
- Quais ainda estão em screens/?

DEPENDENTES:
- Quais arquivos importam este?
- Se eu migrar este, quebrarei outros?

ORDEM SEGURA:
Baseado nas dependências, sugira a ordem segura de migração.
```

---

## 🚨 PROMPTS DE EMERGÊNCIA

### **🆘 APP NÃO COMPILA**

```
O app não está compilando após migração. 

ERRO:
[COLE O ERRO AQUI]

ÚLTIMO ARQUIVO MIGRADO:
[NOME DO ARQUIVO]

Por favor:
1. Identifique a causa do erro
2. Sugira correção
3. Se for imports, liste todos que precisam mudar
4. Se for provider errado, indique o correto
5. Se for sintaxe, mostre o código correto
```

---

### **🔧 DESFAZER MIGRAÇÃO**

```
Preciso reverter a migração de [ARQUIVO].

Por favor:
1. Delete lib/features/[...]/[arquivo].dart
2. Restaure referências ao arquivo antigo em screens/
3. Corrija imports em arquivos que foram atualizados
4. Verifique se algo mais precisa ser revertido

Confirme quando terminar e liste o que foi revertido.
```

---

## ✅ CHECKLIST FINAL

### **🎯 PROMPT: VERIFICAR SE FEATURE ESTÁ COMPLETA**

```
Verifique se a feature [JOBS/CHAT/AUTH] foi completamente migrada:

ARQUIVOS:
[ ] Todos os arquivos de screens/[feature] foram migrados?
[ ] Nenhum arquivo em screens/ ainda referencia esta feature?

CÓDIGO:
[ ] Todos usando ConsumerWidget/ConsumerStatefulWidget?
[ ] Zero setState?
[ ] Todos imports são package:renthus/?
[ ] Providers corretos sendo usados?

FUNCIONALIDADE:
[ ] Navegação funciona?
[ ] Loading states funcionam?
[ ] Error handling funciona?
[ ] Real-time (se aplicável) funciona?

QUALIDADE:
[ ] Código limpo e organizado?
[ ] Comentários onde necessário?
[ ] Sem warnings no analyze?
[ ] Performance boa?

Responda cada item com ✅ ou ❌.
Se ❌, explique o problema e sugira correção.
```

---

## 📚 REFERÊNCIAS RÁPIDAS

### **IMPORTS COMUNS:**

```dart
// Sempre use package imports (NUNCA relativos):

// ❌ ERRADO:
import '../services/auth_service.dart';
import '../../models/user.dart';

// ✅ CORRETO:
import 'package:renthus/features/auth/data/providers/auth_providers.dart';
import 'package:renthus/models/user.dart';
```

### **PROVIDERS DISPONÍVEIS:**

```dart
// Auth
ref.watch(authStateProvider)
ref.watch(currentUserProvider)
ref.read(authActionsProvider.notifier).login(email, password)

// Jobs
ref.watch(jobsListProvider(city: 'Sorriso', status: 'open'))
ref.watch(jobByIdProvider('job-id'))
ref.watch(jobsStreamProvider(city: 'Sorriso'))
ref.read(jobActionsProvider.notifier).create(jobData)

// Chat
ref.watch(conversationsStreamProvider(userId))
ref.watch(messagesStreamProvider(conversationId))
ref.read(chatActionsProvider.notifier).sendMessage(...)

// Notifications
ref.watch(notificationsStreamProvider(userId))
ref.watch(unreadNotificationsCountProvider(userId))
ref.read(notificationActionsProvider.notifier).markAsRead(id, userId)
```

---

## 🎓 DICAS FINAIS

1. **Use @ mentions**: `@arquivo.dart` para referenciar arquivos
2. **Seja específico**: Quanto mais detalhes, melhor a resposta
3. **Peça exemplos**: "Mostre antes e depois"
4. **Revise sempre**: AI pode errar, sempre revise o código
5. **Teste após cada migração**: `flutter run` frequentemente
6. **Commit frequente**: Git commit após cada arquivo migrado
7. **Use Composer** (`Cmd/Ctrl + Shift + I`) para múltiplos arquivos

---

## 🚀 COMEÇAR AGORA

**PROMPT INICIAL:**

```
Olá! Vou migrar meu app Flutter de setState para Riverpod.

Contexto:
- Li o arquivo .cursorrules
- Tenho exemplo em @features/profile/presentation/pages/profile_screen.dart
- Providers estão em features/*/data/providers/

Primeira tarefa:
Analise meu projeto e liste as 10 telas mais importantes que devo migrar primeiro, em ordem de prioridade.

Para cada uma:
- Nome do arquivo atual
- Onde criar o novo
- Provider a usar
- Dificuldade (fácil/média/difícil)
- Tempo estimado

Depois aguardo sua confirmação para começar pela primeira.
```

---

**BOA MIGRAÇÃO! 🎉**
