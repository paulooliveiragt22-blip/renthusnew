# 📅 GUIA DE MIGRAÇÃO COMPLETA - 3 SEMANAS

## 🎯 OBJETIVO:

Migrar **87 arquivos** para Riverpod antes do lançamento nas lojas.

---

## ✅ O QUE VOCÊ JÁ TEM:

```bash
✅ Riverpod instalado
✅ Freezed instalado
✅ Hive para cache
✅ Build_runner funcionando
✅ ProviderScope configurado
✅ Profile feature migrada (exemplo)
✅ Core providers funcionais
✅ Models: Conversation, Message, Notification
✅ Repositories: Chat, Job, Notification
✅ Providers: Chat, Job, Notification
```

---

## 📦 SEMANA 1: AUTH + JOBS + PROFILE (40h)

### **Dia 1-2: Setup e Auth (16h)**

#### **Copiar arquivos gerados:**
```powershell
# Execute o script gerador:
.\GENERATE_ALL_FILES.ps1

# Build:
dart run build_runner build --delete-conflicting-outputs --build-filter="lib/features/**"
```

#### **Migrar Login Screen (4h):**

**ANTES:** `lib/screens/login_screen.dart`
**DEPOIS:** `lib/features/auth/presentation/pages/login_screen.dart`

```dart
// ANTES:
class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  bool _loading = false;
  
  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      await _auth.login(email, password);
      Navigator.pushReplacement(...);
    } catch (e) {
      // error
    } finally {
      setState(() => _loading = false);
    }
  }
}

// DEPOIS:
class LoginScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Sem setState!
  // Sem AuthService direto!
  
  Future<void> _login() async {
    final authActions = ref.read(authActionsProvider.notifier);
    
    final success = await authActions.login(email, password);
    
    if (success && mounted) {
      Navigator.pushReplacement(...);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authActionsProvider);
    
    return authState.when(
      loading: () => CircularProgressIndicator(),
      error: (e, s) => Text('Erro: $e'),
      data: (_) => YourLoginForm(),
    );
  }
}
```

#### **Migrar Signup Screens (4h):**
- client_signup_step1_page.dart
- client_signup_step2_page.dart
- provider_signup_step1_page.dart

**Mesmo padrão do login!**

#### **Testar Auth (2h):**
```powershell
flutter run
# Testar:
# - Login
# - Signup
# - Logout
# - Session persistence
```

---

### **Dia 3-4: Jobs Feature (16h)**

#### **Migrar Jobs List (4h):**

**ANTES:** `lib/screens/client_home_page.dart`

```dart
class ClientHomePage extends StatefulWidget {
  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  List<Job> _jobs = [];
  bool _loading = true;
  
  @override
  void initState() {
    super.initState();
    _loadJobs();
  }
  
  Future<void> _loadJobs() async {
    setState(() => _loading = true);
    final data = await supabase.from('jobs').select();
    setState(() {
      _jobs = data.map((e) => Job.fromMap(e)).toList();
      _loading = false;
    });
  }
}
```

**DEPOIS:**

```dart
class ClientHomePage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsListProvider(city: 'Sorriso'));
    
    return jobsAsync.when(
      loading: () => LoadingWidget(),
      error: (e, s) => ErrorWidget(error: e, onRetry: () {
        ref.invalidate(jobsListProvider);
      }),
      data: (jobs) => ListView.builder(
        itemCount: jobs.length,
        itemBuilder: (context, i) => JobCard(job: jobs[i]),
      ),
    );
  }
}
```

**Ganhos:**
- ✅ Sem setState
- ✅ Cache automático
- ✅ Reload automático quando criar job
- ✅ Loading/error states limpos

#### **Migrar Job Details (4h):**
- client_job_details_page.dart
- job_details_page.dart

#### **Migrar Create Job (4h):**
- create_job_bottom_sheet.dart

#### **Testar Jobs (4h):**
```powershell
flutter run
# Testar:
# - Listar jobs
# - Ver detalhes
# - Criar job
# - Filtrar por cidade
# - Cache funcionando
```

---

### **Dia 5: Profile + Dashboard (8h)**

#### **Profile já está migrado! ✅**

#### **Migrar Dashboards (6h):**
- client_main_page.dart
- provider_main_page.dart

**Padrão:**
```dart
class ProviderMainPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final unreadMessages = ref.watch(unreadMessagesCountProvider(user!.id));
    final unreadNotifications = ref.watch(unreadNotificationsCountProvider(user.id));
    
    return Scaffold(
      // Seus widgets com badges de unread!
    );
  }
}
```

#### **Testar (2h)**

---

## 📦 SEMANA 2: CHAT + NOTIFICATIONS (40h)

### **Dia 1-2: Chat List (16h)**

#### **Migrar Conversations List (8h):**

**ANTES:** `lib/screens/client_chats_page.dart`

```dart
class ClientChatsPage extends StatefulWidget {
  @override
  State<ClientChatsPage> createState() => _ClientChatsPageState();
}

class _ClientChatsPageState extends State<ClientChatsPage> {
  List<Map<String, dynamic>> _conversations = [];
  
  @override
  void initState() {
    super.initState();
    _loadConversations();
  }
  
  Future<void> _loadConversations() async {
    final data = await supabase.from('conversations').select();
    setState(() => _conversations = data);
  }
}
```

**DEPOIS:**

```dart
class ClientChatsPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final conversationsAsync = ref.watch(
      conversationsStreamProvider(user!.id)
    );
    
    return conversationsAsync.when(
      loading: () => LoadingWidget(),
      error: (e, s) => ErrorWidget(error: e),
      data: (conversations) => ListView.builder(
        itemCount: conversations.length,
        itemBuilder: (context, i) {
          final conv = conversations[i];
          return ListTile(
            title: Text(conv.getOtherPersonName(user.id)),
            subtitle: Text(conv.lastMessage ?? ''),
            trailing: conv.hasUnread
                ? Badge(label: Text('${conv.unreadCount}'))
                : null,
          );
        },
      ),
    );
  }
}
```

**Ganhos:**
- ✅ Real-time automático!
- ✅ Unread count atualiza sozinho
- ✅ Sem polling manual

#### **Testar (8h)**

---

### **Dia 3-4: Chat Messages (16h)**

#### **Migrar Chat Page (12h):**

**ANTES:** `lib/screens/chat_page.dart`

**DEPOIS:**

```dart
class ChatPage extends ConsumerStatefulWidget {
  final String conversationId;
  
  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _messageCtrl = TextEditingController();
  
  Future<void> _sendMessage() async {
    final user = ref.read(currentUserProvider);
    final chatActions = ref.read(chatActionsProvider.notifier);
    
    await chatActions.sendMessage(
      conversationId: widget.conversationId,
      senderId: user!.id,
      content: _messageCtrl.text,
    );
    
    _messageCtrl.clear();
  }
  
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final messagesAsync = ref.watch(
      messagesStreamProvider(widget.conversationId)
    );
    
    return messagesAsync.when(
      loading: () => LoadingWidget(),
      error: (e, s) => ErrorWidget(error: e),
      data: (messages) => Column(
        children: [
          Expanded(
            child: ListView.builder(
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

**Ganhos:**
- ✅ Real-time messages!
- ✅ Typing indicators possíveis
- ✅ Read receipts fáceis

#### **Testar (4h)**

---

### **Dia 5: Notifications (8h)**

#### **Migrar Notifications Page (6h):**

```dart
class NotificationsPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final notificationsAsync = ref.watch(
      notificationsStreamProvider(user!.id)
    );
    
    return notificationsAsync.when(
      loading: () => LoadingWidget(),
      error: (e, s) => ErrorWidget(error: e),
      data: (notifications) => ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, i) {
          final notif = notifications[i];
          return NotificationTile(
            notification: notif,
            onTap: () async {
              await ref.read(notificationActionsProvider.notifier)
                  .markAsRead(notif.id, user.id);
              // Navigate
            },
          );
        },
      ),
    );
  }
}
```

#### **Testar (2h)**

---

## 📦 SEMANA 3: ADMIN + POLISH + TESTES (40h)

### **Dia 1-2: Admin Screens (16h)**

#### **Migrar Admin Dashboard (8h):**
- admin_home_page.dart
- admin_users_tab.dart
- admin_jobs_tab.dart

**Mesmo padrão! Use os providers existentes!**

#### **Testar (8h)**

---

### **Dia 3-4: Polish & UX (16h)**

#### **Adicionar Loading States bonitos (4h):**
```dart
// Criar LoadingWidget personalizado
class LoadingWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Carregando...'),
        ],
      ),
    );
  }
}
```

#### **Adicionar Error Widgets com Retry (4h):**
```dart
class ErrorWidget extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text('Erro: $error'),
          if (onRetry != null) ...[
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: Text('Tentar novamente'),
            ),
          ],
        ],
      ),
    );
  }
}
```

#### **Adicionar Empty States (4h):**
```dart
class EmptyWidget extends StatelessWidget {
  final String message;
  final IconData icon;
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }
}
```

#### **Performance Optimizations (4h):**
- Adicionar const constructors
- CachedNetworkImage em todas imagens
- Lazy loading

---

### **Dia 5: Testes Finais (8h)**

#### **Teste completo do app:**
```bash
[ ] Auth flow (login, signup, logout)
[ ] Jobs (list, create, details)
[ ] Chat (conversations, messages, real-time)
[ ] Notifications (list, mark as read)
[ ] Profile (edit, upload avatar)
[ ] Admin dashboard
[ ] Performance (scroll, transitions)
[ ] Offline (cache funcionando)
```

#### **Bug fixes:**
- Corrigir bugs encontrados
- Ajustes finais

---

## 📊 CHECKLIST GERAL:

```bash
SEMANA 1:
[ ] Login migrado
[ ] Signup migrado
[ ] Jobs list migrado
[ ] Job details migrado
[ ] Create job migrado
[ ] Profile migrado
[ ] Dashboard migrado
[ ] Testes semana 1

SEMANA 2:
[ ] Conversations list migrado
[ ] Chat page migrado
[ ] Real-time funcionando
[ ] Notifications migrado
[ ] Unread counts funcionando
[ ] Testes semana 2

SEMANA 3:
[ ] Admin screens migrados
[ ] Loading states polished
[ ] Error handling polished
[ ] Empty states polished
[ ] Performance otimizada
[ ] Testes finais completos
[ ] Bug fixes

LIMPEZA FINAL:
[ ] Deletar pasta repositories/ antiga
[ ] Deletar pasta services/ antiga
[ ] Limpar imports não usados
[ ] Documentar código
```

---

## 🎯 RESULTADO FINAL:

```
✅ 100% migrado para Riverpod
✅ Zero setState
✅ Cache inteligente
✅ Real-time funcionando
✅ Type safety total
✅ Código limpo e escalável
✅ Pronto para lançamento! 🚀
```

---

## 💡 DICAS:

1. **Migre 1 tela por vez**
2. **Teste cada tela antes de continuar**
3. **Use o Profile como referência**
4. **Não tenha pressa**
5. **Peça ajuda se travar**

---

**BOA SORTE! VOCÊ CONSEGUE! 💪**
