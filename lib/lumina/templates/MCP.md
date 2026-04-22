# MCP Development Guide

Guia completo para desenvolvimento de **servidores Model Context Protocol (MCP)** utilizando **TypeScript**.

Este documento define padrões arquiteturais, regras de implementação e boas práticas para garantir que servidores MCP sejam:

* seguros
* previsíveis
* compatíveis com IA
* fáceis de manter
* escaláveis

---

# Objetivo deste documento

Este documento existe para orientar **IA e desenvolvedores humanos** na implementação consistente de servidores MCP.

Ele define:

* padrões de arquitetura
* padrões de código
* padrões de segurança
* padrões de ferramentas
* padrões de testes

Toda implementação deve seguir estas diretrizes.

---

# Conceitos do MCP

Servidores MCP expõem três tipos principais de interfaces.

| Interface | Função              |
| --------- | ------------------- |
| Tools     | executam ações      |
| Resources | expõem dados        |
| Prompts   | templates de prompt |

Comunicação ocorre via **JSON-RPC** sobre **STDIO**.

---

# Regras Críticas do Protocolo

## STDIO Isolation

O protocolo MCP usa **stdout para JSON-RPC**.

Nunca escreva logs em stdout.

❌ Proibido

```
console.log()
```

✔ Permitido

```
console.error()
```

---

## Inicialização rápida

O método `initialize` deve responder rapidamente.

Evite na inicialização:

* chamadas de rede
* leitura massiva de arquivos
* operações CPU intensivas

---

## Statelessness

Tools devem ser **stateless sempre que possível**.

Evite:

* estado global mutável
* sessões
* caches internos sem controle

---

# Arquitetura Recomendada

Estrutura de projeto padrão:

```
src/
  index.ts

  server/
    createServer.ts
    transport.ts

  tools/
    registry.ts
    middleware.ts
    search-files.ts
    generate-report.ts

  resources/
    logs.ts
    config.ts

  prompts/
    system.ts

  schemas/
    toolSchemas.ts

  services/
    fileService.ts
    apiService.ts

  utils/
    logger.ts
    errors.ts
```

Separação clara entre:

* definição MCP
* lógica de negócio
* infraestrutura

---

# Dependências Essenciais

Dependências mínimas:

```
npm install @modelcontextprotocol/sdk zod
```

Dependências recomendadas:

```
npm install pino
npm install bottleneck
```

Dev dependencies:

```
npm install -D typescript eslint @types/node vitest
```

---

# Estrutura Básica do Servidor

Exemplo mínimo:

```ts
import { Server } from "@modelcontextprotocol/sdk/server/index.js"
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js"

const server = new Server({
  name: "example-mcp-server",
  version: "1.0.0"
})

const transport = new StdioServerTransport()

await server.connect(transport)
```

---

# Tool Registry Pattern

Para projetos maiores, registrar tools diretamente no `index.ts` se torna difícil de manter.

Use **Tool Registry Pattern**.

Exemplo:

```ts
export function registerTools(server) {
  registerSearchTool(server)
  registerReportTool(server)
}
```

---

# Convenção de nomes de Tools

Formato obrigatório:

```
verbo-substantivo
```

Exemplos:

```
search-files
generate-report
read-log
create-user
```

Evitar:

```
tool1
handler
doStuff
```

---

# Estrutura de Tool

Template padrão:

```ts
server.tool(
  "tool-name",
  {
    description: "Detailed explanation of what the tool does",
    inputSchema: {...}
  },
  async (args) => {

    try {

      const result = await service(args)

      return {
        content: [
          { type: "text", text: "Operation successful" },
          { type: "json", data: result }
        ]
      }

    } catch (error) {

      console.error("[tool-name]", error)

      throw new McpError(
        ErrorCode.InternalError,
        "Tool execution failed"
      )

    }

  }
)
```

---

# Schema de Entrada

Todos os schemas devem seguir **JSON Schema v7**.

Exemplo:

```ts
{
  type: "object",
  properties: {
    query: {
      type: "string",
      description: "Search query"
    }
  },
  required: ["query"]
}
```

---

# Validação com Zod

Sempre valide argumentos com **Zod**.

Exemplo:

```ts
const schema = z.object({
  query: z.string(),
  limit: z.number().optional()
})
```

---

# Estrutura de Resposta MCP

Formato obrigatório:

```
{
  content: [...]
}
```

Exemplo:

```
{
  content: [
    { type: "text", text: "Summary" },
    { type: "json", data: {...} }
  ]
}
```

---

# Logging Estruturado

Use logs estruturados.

Exemplo recomendado:

```
[tool-name] operation started
[tool-name] operation completed
```

Nunca usar `console.log`.

Logs devem usar `console.error`.

---

# Tool Middleware

Para ferramentas complexas, use middleware.

Exemplos de middleware:

* validação
* rate limit
* logging
* métricas

Exemplo conceitual:

```
tool -> middleware -> handler
```

---

# Rate Limiting

Para tools que acessam APIs externas, implementar rate limit.

Exemplo com Bottleneck:

```
const limiter = new Bottleneck({
  maxConcurrent: 2,
  minTime: 200
})
```

---

# Segurança

Ferramentas devem ser seguras por padrão.

Evitar:

* execução de shell
* acesso irrestrito ao filesystem
* execução de código do usuário

Sempre validar inputs.

---

# Timeouts

Chamadas externas devem ter timeout.

Exemplo:

```
fetch(url, {
  signal: AbortSignal.timeout(5000)
})
```

---

# Resources

Resources são usados para expor dados.

Exemplos:

* logs
* arquivos
* datasets
* configurações

URI exemplo:

```
myserver://logs/app.log
```

---

# Prompts

Prompts são templates reutilizáveis.

Usos comuns:

* system prompts
* workflows
* templates de geração

---

# Anti-Patterns

Nunca faça:

❌ `console.log`
❌ bloquear event loop
❌ estado global mutável
❌ retornar string fora do formato MCP
❌ executar comandos do usuário

---

# Boas Práticas

✔ tools pequenas e focadas
✔ schemas completos
✔ validação consistente
✔ erros tratados
✔ respostas estruturadas

---

# Testes Automatizados

Tools devem ser testadas isoladamente.

Estrutura recomendada:

```
tests/
  tools/
    search-files.test.ts
```

Exemplo com Vitest:

```ts
test("search-files returns results", async () => {

  const result = await searchFiles({ query: "test" })

  expect(result.length).toBeGreaterThan(0)

})
```

---

# Checklist para Nova Tool

Antes de criar uma tool:

```
[ ] nome descritivo
[ ] descrição clara
[ ] JSON Schema definido
[ ] validação Zod
[ ] try/catch
[ ] logs
[ ] resposta MCP válida
```

---

# Checklist de Revisão de Código

Antes do commit:

```
[ ] nenhum console.log
[ ] handlers com try/catch
[ ] schemas definidos
[ ] sem estado global
[ ] respostas MCP válidas
```

---

# Diretrizes para IA

Ao gerar código para este projeto, IA deve:

1. usar TypeScript estrito
2. nunca usar console.log
3. validar argumentos
4. usar try/catch
5. retornar estrutura MCP
6. evitar estado global
7. escrever tools pequenas

---

# Versionamento

Todo servidor deve declarar:

```
name
version
```

Exemplo:

```
example-mcp-server
1.0.0
```

---

# Filosofia de Design

Um bom servidor MCP deve ser:

* simples
* previsível
* seguro
* bem tipado
* modular

Ferramentas devem ser **pequenas e composáveis**.

---

# Scaffolding Recomendado

Novo servidor MCP deve começar com:

```
npm init
npm install @modelcontextprotocol/sdk zod
npm install -D typescript
```

Estrutura inicial:

```
src/
  index.ts
  tools/
  resources/
  prompts/
```


