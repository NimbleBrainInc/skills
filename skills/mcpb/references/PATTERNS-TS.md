# MCP Server Code Patterns (TypeScript)

## Directory Structure

```
<server-name>/
├── .github/workflows/
│   ├── build-bundle.yml
│   ├── ci.yml
│   └── scan.yml
├── src/
│   ├── index.ts              # Server entry point + tool registration
│   ├── config.ts             # Loads API key from env
│   ├── constants.ts          # SERVER_NAME + VERSION (managed by make sync)
│   ├── types.ts              # Zod schemas for API responses
│   ├── schemas.ts            # Zod schemas for tool inputs
│   ├── formatters.ts         # Strip noisy API fields before returning
│   ├── SKILL.md              # Embedded skill resource
│   ├── handlers/             # One file per tool
│   │   └── <tool>.ts
│   └── utils/
│       ├── apiClient.ts      # HTTP client wrapping third-party API
│       └── errorResponse.ts  # Converts errors → MCP CallToolResult
├── tests/
│   ├── server.test.ts
│   ├── client.test.ts
│   └── fixtures.ts
├── .gitignore
├── .mcpbignore
├── CLAUDE.md
├── LICENSE
├── Makefile
├── README.md
├── biome.json
├── manifest.json             # MCPB manifest (v0.4) — version source of truth
├── mpak.json
├── package.json
├── package-lock.json
├── server.json               # Registry metadata
├── tsconfig.json
└── vitest.config.ts
```

## .gitignore

```
# Node
node_modules/
build/
dist/
*.tgz

# Environment
.env
.env.*
!.env.example

# IDEs
.vscode/
.idea/
*.code-workspace

# OS
.DS_Store
Thumbs.db

# Claude
.claude/

# Testing
coverage/
.nyc_output/

# MCPB bundles
bundle/
deps/
*.mcpb

# Scanner reports
security-report.json
.scan-results.json

# Secrets
*.key
*.pem
credentials.json
.secrets/

# Temp files
tmp/
temp/
*.tmp
*.swp
```

## Implementation Order

1. `src/types.ts` — Zod schemas for API response shapes
2. `src/utils/apiClient.ts` — rename class, set BASE_URL, add methods; also update import in `errorResponse.ts`
3. `src/schemas.ts` — Zod input schema for each tool
4. `src/formatters.ts` — one formatter per resource type (pure functions)
5. `src/handlers/<tool>.ts` — one file per tool
6. `src/index.ts` — `server.registerTool()` for each tool
7. `src/config.ts` — rename env var
8. `src/constants.ts` — set SERVER_NAME only (version managed by `make sync`)
9. `manifest.json` + `server.json` — fill all TODO fields; run `make sync`
10. `tests/` — fixtures + tests
11. `src/SKILL.md` — embedded skill resource (tool selection, workflows)

## index.ts (Entry Point)

```typescript
#!/usr/bin/env node

import { readFileSync } from "fs";
import { join } from "path";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { loadConfig } from "./config.js";
import { VERSION, SERVER_NAME } from "./constants.js";
import { ApiClient } from "./utils/apiClient.js";

import { MyInputSchema } from "./schemas.js";
import { myHandler } from "./handlers/myHandler.js";

const SKILL_CONTENT = readFileSync(join(__dirname, "SKILL.md"), "utf-8");

const config = loadConfig();
const client = new ApiClient(config.apiKey);

const server = new McpServer({
  name: SERVER_NAME,
  version: VERSION,
  instructions: "Read the skill resource at skill://<name>/usage before using tools.",
});

// Skill resource
server.resource("skill-usage", "skill://<name>/usage", async (uri) => ({
  contents: [{ uri: uri.href, text: SKILL_CONTENT, mimeType: "text/markdown" }],
}));

// Tool registration
server.registerTool(
  "tool_name",
  {
    description: "What this tool does",
    inputSchema: MyInputSchema.shape,
    annotations: { readOnlyHint: true },
  },
  (args) => myHandler(client, args),
);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error(`${SERVER_NAME} MCP server v${VERSION} running on stdio`);
}

main().catch((e) => {
  console.error("Fatal error:", e);
  process.exit(1);
});
```

## config.ts

```typescript
export function loadConfig() {
  const apiKey = process.env.<NAME>_API_KEY;
  if (!apiKey) {
    console.error("<NAME>_API_KEY environment variable is required");
    process.exit(1);
  }
  return { apiKey };
}
```

## types.ts (API Response Schemas)

```typescript
import { z } from "zod";

export const MyResourceSchema = z.object({
  id: z.string(),
  name: z.string(),
  created_at: z.string(),
});
export type MyResource = z.infer<typeof MyResourceSchema>;

// Paginated response helper
export const paginatedSchema = <T extends z.ZodTypeAny>(item: T) =>
  z.object({
    collection: z.array(item),
    pagination: z.object({
      count: z.number(),
      next_page: z.string().nullable(),
      next_page_token: z.string().nullable(),
    }),
  });
```

## schemas.ts (Tool Input Schemas)

```typescript
import { z } from "zod";

export const GetItemSchema = z.object({
  item_id: z.string().describe("The unique ID of the item"),
});

export const ListItemsSchema = z.object({
  count: z.number().optional().describe("Maximum number of items to return"),
  page_token: z.string().optional().describe("Pagination token"),
});
```

## utils/apiClient.ts

```typescript
export class ApiError extends Error {
  constructor(
    public status: number,
    public statusText: string,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

const BASE_URL = "https://api.example.com";

export class ApiClient {
  private apiKey: string;

  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }

  protected async request(path: string, options?: RequestInit): Promise<unknown> {
    const url = path.startsWith("http") ? path : `${BASE_URL}${path}`;
    const res = await fetch(url, {
      ...options,
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        "Content-Type": "application/json",
        ...options?.headers,
      },
    });

    if (!res.ok) {
      const body = await res.text();
      throw new ApiError(res.status, res.statusText, `API error ${res.status}: ${body}`);
    }

    return res.json();
  }

  async getItem(id: string): Promise<MyResource> {
    const data = await this.request(`/items/${id}`);
    return MyResourceSchema.parse((data as { resource: unknown }).resource);
  }
}
```

## utils/errorResponse.ts

```typescript
import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import { ApiError } from "./apiClient.js";

export function errorResponse(e: unknown): CallToolResult {
  const msg = e instanceof ApiError ? e.message : String(e);
  return { content: [{ type: "text", text: `Error: ${msg}` }], isError: true };
}
```

## handlers/\<tool\>.ts

```typescript
import type { z } from "zod";
import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import { ApiClient } from "../utils/apiClient.js";
import { errorResponse } from "../utils/errorResponse.js";
import { formatMyResource } from "../formatters.js";
import type { MyInputSchema } from "../schemas.js";

export async function myHandler(
  client: ApiClient,
  args: z.infer<typeof MyInputSchema>,
): Promise<CallToolResult> {
  try {
    const result = await client.myMethod(args.some_field);
    return { content: [{ type: "text", text: JSON.stringify(formatMyResource(result), null, 2) }] };
  } catch (e) {
    return errorResponse(e);
  }
}
```

## formatters.ts

```typescript
import type { MyResource } from "./types.js";

export function formatMyResource(r: MyResource) {
  return {
    id: r.id,
    name: r.name,
    created_at: r.created_at,
    // omit large or irrelevant fields
  };
}
```

## Test Pattern

Tests use `InMemoryTransport` with a real `McpServer` + `Client` pair:

```typescript
import { describe, it, expect, vi, beforeAll, afterAll } from "vitest";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";

// Mock client — one vi.fn() per client method
const mocks = {
  myMethod: vi.fn(),
};
const mockClient = mocks as unknown as ApiClient;

function createTestServer(): McpServer {
  const server = new McpServer({ name: "test-server", version: "0.0.0" });
  server.registerTool(
    "tool_name",
    { description: "...", inputSchema: MyInputSchema.shape },
    (args): Promise<CallToolResult> => myHandler(mockClient, args),
  );
  return server;
}

describe("MCP server", () => {
  let client: Client;
  let server: McpServer;

  beforeAll(async () => {
    server = createTestServer();
    client = new Client({ name: "test-client", version: "0.0.0" });
    const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
    await Promise.all([
      client.connect(clientTransport),
      server.connect(serverTransport),
    ]);
  });

  afterAll(async () => {
    await client.close();
    await server.close();
  });

  function getText(result: Awaited<ReturnType<typeof client.callTool>>) {
    return (result.content as Array<{ type: string; text: string }>)[0].text;
  }

  it("returns formatted result", async () => {
    mocks.myMethod.mockResolvedValueOnce(mockMyResource);
    const result = await client.callTool({ name: "tool_name", arguments: { id: "123" } });
    const parsed = JSON.parse(getText(result));
    expect(parsed.id).toBe("123");
  });

  it("returns error for API failure", async () => {
    mocks.myMethod.mockRejectedValueOnce(new Error("fail"));
    const result = await client.callTool({ name: "tool_name", arguments: { id: "bad" } });
    expect(result.isError).toBe(true);
  });
});
```

## .mcpbignore

```
.git/
.github/
.vscode/
.idea/
.claude/
tests/
e2e/
scripts/
src/
*.mcpb
.env
.env.*
!.env.example
Makefile
tsconfig.json
vitest.config.ts
biome.json
pyproject.toml
CLAUDE.md
README.md
*.png
*.security-report.json
!package-lock.json
!build/SKILL.md
```

> **Note:** The `*.md` and `src/` exclusions would prevent the embedded SKILL.md from being bundled. The `!build/SKILL.md` negation overrides both. The Makefile `build` target must include `cp src/SKILL.md build/SKILL.md` so the file is available at the expected path.

## CI Workflows

**ci.yml:**
```yaml
name: CI
on:
  pull_request:
    branches: [main]

jobs:
  version-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - name: Check version consistency
        run: |
          VERSION=$(jq -r '.version' manifest.json)
          PKG=$(jq -r '.version' package.json)
          SRV=$(jq -r '.version' server.json)
          SRV_PKG=$(jq -r '.packages[0].version' server.json)
          CONSTANTS=$(sed -n 's/export const VERSION = "\(.*\)";/\1/p' src/constants.ts)
          FAIL=0
          [ "$PKG" != "$VERSION" ] && echo "MISMATCH: package.json" && FAIL=1
          [ "$SRV" != "$VERSION" ] && echo "MISMATCH: server.json" && FAIL=1
          [ "$SRV_PKG" != "$VERSION" ] && echo "MISMATCH: server.json packages" && FAIL=1
          [ "$CONSTANTS" != "$VERSION" ] && echo "MISMATCH: constants.ts" && FAIL=1
          exit $FAIL

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6
        with:
          node-version: "22"
          cache: "npm"
      - run: npm ci
      - run: npm run format:check
      - run: npm run lint
      - run: npm run typecheck

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6
        with:
          node-version: "22"
          cache: "npm"
      - run: npm ci
      - run: npm run build
      - run: npm run test

  bundle:
    runs-on: ubuntu-latest
    needs: [version-check, lint, test]
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6
        with:
          node-version: "22"
          cache: "npm"
      - run: npm ci && npm run build
      - run: npm prune --omit=dev
      - run: npx @anthropic-ai/mcpb pack && ls -la *.mcpb
```

**build-bundle.yml:**
```yaml
name: Build MCPB Bundle
on:
  release:
    types: [published]

permissions:
  contents: write
  id-token: write

jobs:
  build:
    strategy:
      matrix:
        include:
          - os: linux
            arch: amd64
            runner: ubuntu-latest
          - os: linux
            arch: arm64
            runner: ubuntu-24.04-arm
          - os: darwin
            arch: arm64
            runner: macos-latest
    runs-on: ${{ matrix.runner }}
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6
        with:
          node-version: "22"
          cache: "npm"
      - run: npm ci && npm run build
      - run: npm prune --omit=dev
      - uses: NimbleBrainInc/mcpb-pack@v3
        with:
          output: "{name}-{version}-${{ matrix.os }}-${{ matrix.arch }}.mcpb"
```

## Build & Test Commands

```bash
npm install                          # Install dependencies
npm run format:check                 # Check formatting (Biome)
npm run lint                         # Lint (Biome)
npm run typecheck                    # Type check (tsc --noEmit)
npm run test                         # Test (Vitest)
make check                           # All of the above

npm run build                        # Compile TypeScript → build/
make bundle                          # Build + prune + mcpb pack

# Test locally
<NAME>_API_KEY=xxx node build/index.js --stdio

# Test with MCP Inspector
<NAME>_API_KEY=xxx npx @modelcontextprotocol/inspector node build/index.js --stdio
```

---

## Tool Design Guidelines

1. **One tool per operation**: `list_items`, `get_item`, `create_item`, etc.
2. **Clear descriptions**: What the tool does, its arguments, its return value
3. **Sensible defaults**: Pagination limits, optional filters
4. **Error handling**: Catch API errors, return structured error messages
5. **Search tools**: Add convenience wrappers if API supports filtering

## API Analysis Checklist

When analyzing an API to build an MCP server:

1. **Authentication**: Bearer token, API key, OAuth?
2. **Base URL**: What's the API base URL?
3. **Resources**: What entities exist?
4. **Operations**: CRUD operations available?
5. **Pagination**: Cursor-based, offset-based?
6. **Filtering**: What filter parameters are supported?
7. **Response format**: JSON structure, nested objects?
8. **Rate limits**: Any limits to be aware of?
9. **OpenAPI spec**: Is one available?
