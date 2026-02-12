# 🚀 GUIA RÁPIDO - USAR CURSOR PARA MIGRAÇÃO

## 📦 O QUE VOCÊ TEM AQUI:

```
CURSOR_PROMPTS/
├── .cursorrules                        ⭐⭐⭐ (Copie para raiz do projeto!)
├── CURSOR_MIGRATION_PROMPTS.md         ⭐⭐⭐ (Todos os prompts prontos)
└── README.md                           (Este arquivo)
```

---

## ⚡ SETUP RÁPIDO (5 minutos):

### **1. Copiar .cursorrules**

```powershell
# No PowerShell, na raiz do projeto:
Copy-Item "CURSOR_PROMPTS\.cursorrules" ".cursorrules" -Force
```

**O que isso faz?**
- Configura o Cursor com todas as regras de migração
- Cursor vai entender automaticamente o padrão
- Vai sugerir migrações corretas

---

### **2. Abrir projeto no Cursor**

```bash
# No terminal:
cd D:\renthus_new\renthus_new
cursor .
```

**Se não tiver Cursor instalado:**
- Download: https://cursor.sh
- É grátis!
- Baseado no VS Code

---

### **3. Testar configuração**

No Cursor, pressione `Cmd/Ctrl + L` (abrir chat) e digite:

```
Olá! Estou pronto para migrar meu projeto para Riverpod.
Você leu o arquivo .cursorrules?
Liste os providers disponíveis que posso usar.
```

**Se Cursor responder com a lista de providers, está configurado! ✅**

---

## 🎯 COMO USAR OS PROMPTS:

### **Opção 1: Copiar e colar (mais fácil)**

1. Abra `CURSOR_MIGRATION_PROMPTS.md`
2. Encontre o prompt que precisa (ex: "TELA DE LOGIN")
3. Copie o prompt
4. Cole no Cursor Chat (`Cmd/Ctrl + L`)
5. Aguarde a resposta
6. Revise o código
7. Aceite ou peça ajustes

---

### **Opção 2: Usar Composer (múltiplos arquivos)**

1. Pressione `Cmd/Ctrl + Shift + I`
2. Cole o prompt do tipo "WORKFLOW"
3. Cursor vai editar múltiplos arquivos de uma vez
4. Revise todas as mudanças
5. Aceite

---

## 📋 WORKFLOW RECOMENDADO:

### **DIA 1: Preparação**

```
1. [✅] Copiar .cursorrules
2. [✅] Abrir projeto no Cursor
3. [✅] Testar configuração
4. [ ] Ler CURSOR_MIGRATION_PROMPTS.md
5. [ ] Escolher primeira tela para migrar
```

---

### **DIA 2-3: Primeira tela (Login)**

#### **Passo 1: Analisar**

No Cursor Chat:
```
Analise @screens/login_screen.dart e me diga:
1. É StatefulWidget ou StatelessWidget?
2. Quais dados busca?
3. Usa setState em quantos lugares?
4. Qual provider devo usar?
5. Dificuldade estimada?
```

#### **Passo 2: Migrar**

Cole o prompt "TELA DE LOGIN" do arquivo de prompts.

#### **Passo 3: Revisar**

```
Revise o arquivo migrado @features/auth/presentation/pages/login_screen.dart seguindo o checklist do .cursorrules
```

#### **Passo 4: Testar**

```bash
flutter run
```

#### **Passo 5: Corrigir imports**

Se outras telas usavam login_screen:
```
Encontre todos os arquivos que importam screens/login_screen.dart e atualize para o novo caminho.
```

---

### **DIA 4-5: Segunda tela (Jobs List)**

Repita o processo com o prompt "LISTA DE SERVIÇOS".

---

### **DIA 6-7: Terceira tela (Chat)**

Use o prompt "LISTA DE CONVERSAS".

---

## 💡 ATALHOS DO CURSOR:

```
Cmd/Ctrl + L         → Abrir Chat
Cmd/Ctrl + Shift + I → Composer (multi-file)
Cmd/Ctrl + K         → Quick actions
Cmd/Ctrl + Shift + F → Buscar em todos arquivos
Cmd/Ctrl + P         → Abrir arquivo rápido
```

---

## 🎯 PROMPTS MAIS USADOS:

### **1. Migrar uma tela:**
```
Migre @screens/[ARQUIVO].dart para Riverpod seguindo .cursorrules.
Crie em lib/features/[FEATURE]/presentation/pages/
Use [PROVIDER_NAME]
Mantenha layout 100% igual.
```

### **2. Corrigir imports:**
```
Encontre todos arquivos que importam [ARQUIVO_ANTIGO] e atualize para package:renthus/features/...
```

### **3. Revisar código:**
```
Revise @features/[...]/[ARQUIVO].dart seguindo checklist do .cursorrules
```

### **4. Comparar antes/depois:**
```
Compare @screens/[ANTIGO].dart com @features/[...]/[NOVO].dart
Mostre diferenças em tabela.
```

---

## 🔧 TROUBLESHOOTING:

### **Cursor não lê .cursorrules:**

```
No Chat, digite:
"Você leu o arquivo .cursorrules na raiz do projeto? Se não, leia agora e confirme."
```

### **Cursor sugere código errado:**

```
"Você está seguindo as regras do .cursorrules?
Especificamente: [CITE A REGRA]
Por favor, corrija seguindo essa regra."
```

### **Quer mudar abordagem:**

```
"Ignore a sugestão anterior.
Faça de novo seguindo este padrão:
[COLE EXEMPLO DO profile_screen.dart]"
```

---

## 📊 ESTIMATIVA DE TEMPO COM CURSOR:

```
Sem Cursor:
├── Por tela: 1-2 horas
├── 30 telas: ~45 horas
└── 3 semanas full-time

Com Cursor:
├── Por tela: 30-40 min
├── 30 telas: ~20 horas
└── 1.5 semanas full-time

Economia: ~25 horas! 🎉
```

---

## ✅ CHECKLIST DE USO:

```bash
Setup:
[✅] .cursorrules copiado
[✅] Cursor aberto
[✅] Testado que funciona
[ ] Lido CURSOR_MIGRATION_PROMPTS.md

Por tela:
[ ] Analisar arquivo
[ ] Copiar prompt apropriado
[ ] Cursor gera código
[ ] Revisar código
[ ] Testar no app
[ ] Corrigir imports
[ ] Commit
[ ] Próxima tela!
```

---

## 🎓 DICAS PRO:

1. **Use @ para mencionar arquivos:**
   ```
   Compare @screens/login.dart com @features/profile/.../profile_screen.dart
   ```

2. **Peça tabelas e listas:**
   ```
   Liste em tabela: antes vs depois
   ```

3. **Seja específico:**
   ```
   Não: "Migre este arquivo"
   Sim: "Migre @screens/login.dart para Riverpod usando authActionsProvider"
   ```

4. **Revise SEMPRE:**
   - Cursor é inteligente mas pode errar
   - Sempre revise o código antes de aceitar
   - Teste no app

5. **Commit frequente:**
   ```bash
   git add .
   git commit -m "Migrar login para Riverpod"
   ```

6. **Use Composer para features completas:**
   - Mais rápido
   - Edita múltiplos arquivos
   - Mantém consistência

---

## 📚 RECURSOS:

```
CURSOR_MIGRATION_PROMPTS.md  → Todos os prompts prontos
.cursorrules                 → Configuração automática
WEEK_BY_WEEK_GUIDE.md        → Cronograma completo
profile_screen.dart          → Exemplo de referência
```

---

## 🚀 COMEÇAR AGORA:

```powershell
# 1. Copiar .cursorrules
Copy-Item "CURSOR_PROMPTS\.cursorrules" ".cursorrules" -Force

# 2. Abrir Cursor
cursor .

# 3. No Cursor Chat (Cmd/Ctrl + L), cole:
```

```
Olá! Li o .cursorrules e estou pronto para migrar.

Primeira tarefa:
Analise @screens/ e liste as 10 telas mais importantes para migrar primeiro.

Para cada:
- Nome do arquivo
- Onde criar (features/...)
- Provider a usar
- Dificuldade (1-5)
- Tempo estimado

Depois aguardo confirmação para começar.
```

---

## 🎉 PRONTO!

**Você tem:**
- ✅ Configuração automática (.cursorrules)
- ✅ Prompts prontos para todas situações
- ✅ Exemplos de uso
- ✅ Workflow definido

**Agora é só:**
1. Copiar .cursorrules
2. Abrir Cursor
3. Usar os prompts
4. Revisar código
5. Testar
6. Repetir!

**BOA MIGRAÇÃO! 🚀**

---

## 💬 DÚVIDAS?

Se travar em alguma tela, use o prompt "ANALISAR ARQUIVO" primeiro!

Se Cursor sugerir algo errado, cite a regra do .cursorrules!

Se precisar de ajuda, me chame! 💪
