# MCPs – configuração e troubleshooting

## Servidores configurados em `.cursor/mcp.json`

| Servidor | Tipo | Dependência | Problema comum |
|----------|------|-------------|----------------|
| **Supabase** | URL | OAuth no browser | Não aparece / não conecta |
| **GitHub** | npx | Node.js + `GITHUB_TOKEN` | Token vazio = falha |
| **fs-project** | npx | Node.js + path | npx não no PATH |
| **sequential-thinking** | npx | Node.js | npx não no PATH |
| **context7** | URL | Serviço externo | Rede / disponibilidade |

---

## Supabase – por que não aparece e como corrigir

### Situação

O servidor **Supabase** está definido em `.cursor/mcp.json`:

```json
"supabase": {
  "url": "https://mcp.supabase.com/mcp?project_ref=dqfejuakbtcxhymrxoqs"
}
```

Mas, ao usar as ferramentas MCP no Cursor, o servidor **não aparece** na lista de servidores disponíveis (enquanto context7, fs-project, etc. aparecem).

## Causas prováveis

1. **Autenticação OAuth não feita**  
   O MCP do Supabase usa OAuth 2.1. Na primeira conexão, o Cursor deve abrir o navegador para você fazer login no Supabase e autorizar o cliente MCP. Se isso não aconteceu ou foi cancelado, o servidor não é registrado e não entra na lista.

2. **Servidor falhou ao conectar e foi desativado**  
   Se a primeira conexão à URL do MCP falhar (rede, timeout, erro no endpoint), o Cursor pode deixar o servidor em estado de erro e não mostrá-lo como disponível.

3. **Reinício do Cursor após mudar o mcp.json**  
   Às vezes o Cursor só recarrega os servidores MCP após um restart. Se o Supabase foi adicionado depois de outros, pode ser necessário reiniciar para ele ser carregado.

## O que fazer (em ordem)

### 1. Conferir em Cursor

- Abra **Settings** (Ctrl+,) → **Tools & MCP** (ou **Cursor Settings** → **MCP**).
- Veja se **Supabase** (ou algo como “project-0-renthus_new-supabase”) aparece na lista.
  - Se aparecer com **erro** ou **desconectado**: anote a mensagem; normalmente é falha de rede ou de autenticação.
  - Se **não aparecer**: o Cursor não está carregando esse servidor (veja passos abaixo).

### 2. Forçar nova instalação e OAuth (recomendado)

- Use o link oficial do Supabase para adicionar o MCP no Cursor:  
  [Supabase MCP – Add to Cursor](https://supabase.com/docs/guides/getting-started/mcp)  
  (botão “Add to Cursor” ou link do tipo `cursor://anysphere.cursor-deeplink/mcp/install?name=supabase&config=...`).
- Isso deve:
  - Abrir o Cursor (se não estiver aberto).
  - Pedir para você fazer login no Supabase no navegador e autorizar o cliente.
- Depois de autorizar, em **Settings → Tools & MCP** o Supabase deve passar a aparecer e ficar “Connected”.

### 3. Manter o `project_ref` no mcp.json

- O `project_ref=dqfejuakbtcxhymrxoqs` no `.cursor/mcp.json` restringe o MCP a esse projeto e é o esperado.
- Não remova esse parâmetro se quiser que as ferramentas MCP atuem só nesse projeto.

### 4. Reiniciar o Cursor

- Feche o Cursor por completo e abra de novo.
- Confira de novo em **Settings → Tools & MCP** se o Supabase aparece e está conectado.

### 5. Se ainda não funcionar (autenticação manual / PAT)

- Se você estiver em ambiente sem browser (ex.: CI) ou o OAuth não funcionar, a documentação do Supabase permite usar **Personal Access Token (PAT)**.
- Em [Supabase Dashboard → Account → Access Tokens](https://supabase.com/dashboard/account/tokens), crie um token.
- No `.cursor/mcp.json` você pode tentar (se o Cursor suportar headers para esse tipo de servidor):

```json
"supabase": {
  "url": "https://mcp.supabase.com/mcp?project_ref=dqfejuakbtcxhymrxoqs",
  "headers": {
    "Authorization": "Bearer SEU_PAT_AQUI"
  }
}
```

- **Atenção:** não commite o PAT no repositório; use variável de ambiente no lugar de `SEU_PAT_AQUI` se possível.

## Resumo Supabase

- O MCP do Supabase **está configurado** no `mcp.json`, mas **não está ativo** na sessão atual do Cursor.
- A causa mais provável é **não ter concluído o login OAuth** na primeira conexão.
- Solução mais direta: usar o link **“Add to Cursor”** na documentação do Supabase, concluir o OAuth no navegador e, se preciso, **reiniciar o Cursor** e conferir em **Settings → Tools & MCP**.

## GitHub

O MCP do GitHub usa `GITHUB_TOKEN`. Configure a variável de ambiente antes de abrir o Cursor: PowerShell `$env:GITHUB_TOKEN = "ghp_..."` ou Painel de Controle → Variáveis de Ambiente. Reinicie o Cursor.

## fs-project e sequential-thinking

Precisam de Node.js (`npx` no PATH). Instale em nodejs.org e reinicie o Cursor. Se não funcionar, abra o Cursor pelo terminal: `cursor .`
