# MCP Server Code Patterns

## Python Server Patterns

### Directory Structure

```
<server-name>/
├── .github/workflows/
│   ├── build-bundle.yml
│   ├── ci.yml
│   └── scan.yml
├── src/mcp_<name>/
│   ├── __init__.py
│   ├── api_models.py
│   ├── api_client.py
│   ├── server.py
│   └── SKILL.md         ← embedded skill resource
├── tests/
│   ├── __init__.py
│   ├── conftest.py          ← shared fixtures (mcp_server, mock_client)
│   ├── test_api_client.py   ← API client unit tests (mocked HTTP)
│   ├── test_api_models.py
│   └── test_server.py       ← MCP server tests via FastMCP Client
├── tests-integration/
│   ├── __init__.py
│   ├── conftest.py          ← env checks, real API client fixture
│   ├── test_core_tools.py   ← real API calls with tier-skip helpers
│   └── test_skill_llm.py    ← LLM smoke tests (tool selection)
├── .gitignore
├── .mcpbignore
├── .env.example
├── CLAUDE.md
├── Makefile
├── manifest.json
├── mpak.json
├── pyproject.toml
├── pytest.ini
└── README.md
```

### .gitignore (Python)

```
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
build/
dist/
*.egg-info/
.Python

# Virtual environments
.env
.venv
env/
venv/
ENV/

# Testing
.pytest_cache/
.coverage
htmlcov/
.tox/

# Type checking
.mypy_cache/
.dmypy.json
.pytype/

# Linting
.ruff_cache/

# IDEs
.idea/
.vscode/
*.code-workspace

# OS
.DS_Store
Thumbs.db

# MCP/Claude
.claude/

# Package managers
uv.lock
.uv/
poetry.lock
Pipfile.lock

# Secrets
*.key
*.pem
credentials.json
.secrets/

# Local development
test_quick.py

# MCPB bundles
bundle/
deps/
*.mcpb

# Scanner reports
security-report.json
```

### pyproject.toml

```toml
[project]
name = "mcp-<name>"
version = "0.1.0"
description = "..."
requires-python = ">=3.13"
dependencies = [
    "aiohttp>=3.11.0",
    "fastmcp>=2.14.0",
    "pydantic>=2.0.0",
    "python-dotenv>=1.0.0",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/mcp_<name>"]

[tool.ruff]
target-version = "py313"
line-length = 100

[tool.ruff.lint]
select = ["E", "W", "F", "I", "B", "C4", "UP"]
ignore = ["E501", "B008"]

[dependency-groups]
dev = [
    "pytest>=8.4.0",
    "pytest-asyncio>=0.24.0",
    "ruff>=0.13.0",
    "ty>=0.0.17",
]
```

### server.py

```python
"""<Service> MCP Server - FastMCP Implementation."""

import logging
import os
import sys
from importlib.resources import files

from fastmcp import Context, FastMCP
from starlette.requests import Request
from starlette.responses import JSONResponse

from mcp_<name>.api_client import Client, APIError
from mcp_<name>.api_models import SomeModel

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    stream=sys.stderr,
)
logger = logging.getLogger("mcp_<name>")

SKILL_CONTENT = files("mcp_<name>").joinpath("SKILL.md").read_text()

mcp = FastMCP(
    "<Service>",
    instructions="Read the skill resource at skill://<name>/usage before using tools.",
)

_client: Client | None = None


@mcp.resource("skill://<name>/usage")
def get_skill() -> str:
    """Tool selection guide and workflow patterns for this server."""
    return SKILL_CONTENT


def get_client(ctx: Context | None = None) -> Client:
    global _client
    if _client is None:
        api_key = os.environ.get("<NAME>_API_KEY")
        if not api_key:
            msg = "<NAME>_API_KEY environment variable is required"
            if ctx:
                ctx.error(msg)
            raise ValueError(msg)
        _client = Client(api_key=api_key)
    return _client


@mcp.custom_route("/health", methods=["GET"])
async def health_check(request: Request) -> JSONResponse:
    return JSONResponse({"status": "healthy", "service": "mcp-<name>"})


@mcp.tool()
async def some_tool(arg: str, ctx: Context | None = None) -> SomeModel:
    """Tool description.

    Args:
        arg: Argument description
        ctx: MCP context

    Returns:
        Return description
    """
    client = get_client(ctx)
    try:
        return await client.some_method(arg)
    except APIError as e:
        if ctx:
            ctx.error(f"API error: {e.message}")
        raise


# ASGI app for HTTP deployment
app = mcp.http_app()

# Stdio entrypoint for Claude Desktop / mpak
if __name__ == "__main__":
    mcp.run()
```

### api_client.py

```python
import os
from typing import Any
import aiohttp
from aiohttp import ClientError

from .api_models import SomeModel, SomeListResponse


class APIError(Exception):
    def __init__(self, status: int, message: str, details: dict[str, Any] | None = None) -> None:
        self.status = status
        self.message = message
        self.details = details
        super().__init__(f"API Error {status}: {message}")


class Client:
    BASE_URL = "https://api.example.com/v1"

    def __init__(self, api_key: str | None = None, timeout: float = 30.0) -> None:
        self.api_key = api_key or os.environ.get("API_KEY")
        if not self.api_key:
            raise ValueError("API_KEY is required")
        self.timeout = timeout
        self._session: aiohttp.ClientSession | None = None

    async def _ensure_session(self) -> None:
        if not self._session:
            headers = {
                "Authorization": f"Bearer {self.api_key}",
                "Accept": "application/json",
                "Content-Type": "application/json",
            }
            self._session = aiohttp.ClientSession(
                headers=headers,
                timeout=aiohttp.ClientTimeout(total=self.timeout)
            )

    async def close(self) -> None:
        if self._session:
            await self._session.close()
            self._session = None

    async def _request(
        self,
        method: str,
        path: str,
        params: dict[str, Any] | None = None,
        json_data: Any | None = None,
    ) -> dict[str, Any]:
        await self._ensure_session()
        url = f"{self.BASE_URL}{path}"

        if params:
            params = {k: v for k, v in params.items() if v is not None}

        try:
            if not self._session:
                raise RuntimeError("Session not initialized")

            kwargs: dict[str, Any] = {}
            if json_data is not None:
                kwargs["json"] = json_data
            if params:
                kwargs["params"] = params

            async with self._session.request(method, url, **kwargs) as response:
                result = await response.json()

                if response.status >= 400:
                    error_msg = result.get("message", "Unknown error")
                    raise APIError(response.status, error_msg, result)

                return result
        except ClientError as e:
            raise APIError(500, f"Network error: {str(e)}") from e

    async def list_items(self, limit: int = 20) -> list[SomeModel]:
        data = await self._request("GET", "/items", params={"limit": limit})
        response = SomeListResponse(**data)
        return response.data.items
```

### api_models.py

```python
from enum import Enum
from typing import Any
from pydantic import BaseModel, Field


class SomeEnum(str, Enum):
    VALUE_A = "value_a"
    VALUE_B = "value_b"


class Pagination(BaseModel):
    model_config = {"populate_by_name": True}
    next_link: str | None = Field(default=None, alias="nextLink")


class SomeModel(BaseModel):
    id: str = Field(..., description="ID")
    name: str | None = Field(None, description="Name")
    created_at: str | None = Field(None, alias="createdAt")
    custom_fields: dict[str, Any] = Field(default_factory=dict, alias="customFieldValues")


class SomeListResponse(BaseModel):
    class Data(BaseModel):
        items: list[SomeModel] = Field(default_factory=list)
        pagination: Pagination = Field(default_factory=lambda: Pagination())
    data: Data
```

### .mcpbignore (Python)

```
.venv/
.git/
.github/
.pytest_cache/
__pycache__/
*.pyc
.ruff_cache/
.coverage
tests/
dist/
build/
*.egg-info/
*.mcpb
Makefile
pytest.ini
.env
.env.*
uv.lock
.vscode/
.idea/
CLAUDE.md
*.png
```

### CI Workflows (Python)

**ci.yml:**
```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v4
      - run: uv python install 3.13
      - run: uv sync --dev
      - run: uv run ruff format --check src/ tests/
      - run: uv run ruff check src/ tests/
      - run: uv run ty check src/

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v4
      - run: uv python install 3.13
      - run: uv sync --dev
      - run: uv run pytest tests/ -v
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
      - uses: actions/checkout@v4
      - name: Update manifest version
        run: |
          VERSION="${{ github.event.release.tag_name }}"
          VERSION="${VERSION#v}"
          jq --arg v "$VERSION" '.version = $v' manifest.json > manifest.tmp.json
          mv manifest.tmp.json manifest.json
      - uses: NimbleBrainInc/mcpb-pack@v2
        with:
          output: "{name}-{version}-${{ matrix.os }}-${{ matrix.arch }}.mcpb"
```

**scan.yml:**
```yaml
name: Security Scan
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v4
      - run: uv python install 3.13
      - run: uv sync
      - name: Build bundle
        run: npx @anthropic-ai/mcpb pack
      - name: Run MTF scanner
        run: uvx mpak-scanner scan *.mcpb --json > scan-results.json
      - name: Check for critical/high findings
        run: |
          python3 -c "
          import json, sys
          with open('scan-results.json') as f:
              results = json.load(f)
          findings = results.get('findings', [])
          critical_high = [f for f in findings if f.get('severity') in ('CRITICAL', 'HIGH')]
          if critical_high:
              print(f'FAIL: {len(critical_high)} critical/high findings')
              sys.exit(1)
          print(f'PASS: No critical/high findings ({len(findings)} total findings)')
          "
```

### Makefile `bundle` Target (Python)

```makefile
bundle: ## Build MCPB bundle locally
	rm -rf deps/
	uv pip install --target ./deps --only-binary :all: . 2>/dev/null || uv pip install --target ./deps .
	npx @anthropic-ai/mcpb pack .
	@echo "Bundle created. Run 'ls -la *.mcpb' to see it."
```

This vendors dependencies into `deps/` (same as the GitHub Action does), then packs. Contributors can validate bundles locally before releasing.

### Test Patterns (Python)

Three test layers, each with its own directory and concerns:

**Unit tests (`tests/`)** — No API key needed. Run with `make test`.

`tests/conftest.py` — Shared fixtures:
```python
import pytest
from unittest.mock import AsyncMock
from mcp_<name>.server import mcp

@pytest.fixture
def mcp_server():
    """The FastMCP server instance for Client-based tests."""
    return mcp

@pytest.fixture
def mock_client():
    """API client with all methods mocked."""
    client = AsyncMock()
    client.list_items = AsyncMock(return_value=[...])
    # ... one mock per client method
    return client
```

`tests/test_server.py` — Test tools via FastMCP Client (not by calling functions directly):
```python
from fastmcp import Client
from fastmcp.exceptions import ToolError

class TestSkillResource:
    @pytest.mark.asyncio
    async def test_initialize_returns_instructions(self, mcp_server):
        async with Client(mcp_server) as client:
            result = await client.initialize()
            assert "skill://<name>/usage" in result.instructions

    @pytest.mark.asyncio
    async def test_skill_resource_content(self, mcp_server):
        async with Client(mcp_server) as client:
            resources = await client.list_resources()
            uris = [str(r.uri) for r in resources]
            assert "skill://<name>/usage" in uris
            content = await client.read_resource("skill://<name>/usage")
            text = content[0].text if hasattr(content[0], "text") else str(content[0])
            assert "## Tools" in text

class TestMCPTools:
    @pytest.mark.asyncio
    async def test_tool_success(self, mcp_server, mock_client, monkeypatch):
        monkeypatch.setattr("mcp_<name>.server._client", mock_client)
        async with Client(mcp_server) as client:
            result = await client.call_tool("tool_name", {"arg": "value"})
            assert len(result) > 0

    @pytest.mark.asyncio
    async def test_tool_api_error(self, mcp_server, mock_client, monkeypatch):
        mock_client.some_method.side_effect = APIError(401, "Unauthorized")
        monkeypatch.setattr("mcp_<name>.server._client", mock_client)
        async with Client(mcp_server) as client:
            with pytest.raises(ToolError, match="401"):
                await client.call_tool("tool_name", {"arg": "value"})
```

**Key:** FastMCP wraps tool exceptions as `fastmcp.exceptions.ToolError`, not the original type. Always catch `ToolError` in tests.

**Integration tests (`tests-integration/`)** — Requires real API key. Run with `make test-integration`.

`tests-integration/conftest.py` — Gate on env var:
```python
def pytest_configure(config):
    if not os.environ.get("<NAME>_API_KEY"):
        pytest.exit("ERROR: <NAME>_API_KEY required for integration tests.")

@pytest_asyncio.fixture
async def client(api_key: str) -> Client:
    client = Client(api_key=api_key)
    yield client
    await client.close()
```

`tests-integration/test_core_tools.py` — Tier-skip pattern for plan-gated endpoints:
```python
async def has_premium_access(client: Client) -> bool:
    """Check if the plan supports premium endpoints."""
    try:
        await client.premium_method(limit=1)
        return True
    except APIError as e:
        if e.status in (400, 401, 403):
            return False
        raise

class TestPremiumFeature:
    @pytest.mark.asyncio
    async def test_premium_endpoint(self, client):
        if not await has_premium_access(client):
            pytest.skip("Premium access not available on current plan")
        result = await client.premium_method(limit=5)
        assert isinstance(result, list)
```

**LLM smoke tests (`tests-integration/test_skill_llm.py`)** — Requires `ANTHROPIC_API_KEY`. Run with `make test-llm`.

Sends server context (instructions + skill + tools) to Claude Haiku, asserts correct tool selection:
```python
async def get_server_context() -> dict:
    async with Client(mcp) as client:
        init = await client.initialize()
        resources = await client.list_resources()
        skill_text = ""
        for r in resources:
            if "skill://" in str(r.uri):
                contents = await client.read_resource(str(r.uri))
                skill_text = contents[0].text
        tools_list = await client.list_tools()
        tools = [{"name": t.name, "description": t.description, "input_schema": t.inputSchema} for t in tools_list]
        return {"instructions": init.instructions, "skill": skill_text, "tools": tools}

class TestSkillLLMInvocation:
    @pytest.mark.asyncio
    async def test_query_selects_correct_tool(self):
        ctx = await get_server_context()
        client = get_anthropic_client()
        system = f"You are an assistant.\n\n## Instructions\n{ctx['instructions']}\n\n## Skill\n{ctx['skill']}"
        response = client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=1024,
            system=system,
            messages=[{"role": "user", "content": "Your test prompt here"}],
            tools=[{"type": "custom", **t} for t in ctx["tools"]],
        )
        tool_calls = [b for b in response.content if b.type == "tool_use"]
        assert len(tool_calls) > 0
        assert tool_calls[0].name == "expected_tool_name"
```

### Build & Test Commands (Python)

```bash
uv sync --dev                        # Install dependencies
uv run ruff format src/ tests/       # Format
uv run ruff check src/ tests/        # Lint
uv run ty check src/                 # Type check
uv run pytest tests/ -v              # Unit tests
make check                           # All of the above
make test-integration                # Integration tests (needs API key)
make test-llm                        # LLM smoke tests (needs API key + ANTHROPIC_API_KEY)
make bundle                          # Vendor deps + mcpb pack (local bundle)

# Test locally
<NAME>_API_KEY=xxx uv run python -m mcp_<name>.server

# Test with MCP Inspector
<NAME>_API_KEY=xxx npx @modelcontextprotocol/inspector uv run python -m mcp_<name>.server
```

---

## TypeScript Server Patterns

### Directory Structure

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

### .gitignore (TypeScript)

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

### Implementation Order

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

### index.ts (Entry Point)

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

### config.ts

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

### types.ts (API Response Schemas)

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

### schemas.ts (Tool Input Schemas)

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

### utils/apiClient.ts

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

### utils/errorResponse.ts

```typescript
import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import { ApiError } from "./apiClient.js";

export function errorResponse(e: unknown): CallToolResult {
  const msg = e instanceof ApiError ? e.message : String(e);
  return { content: [{ type: "text", text: `Error: ${msg}` }], isError: true };
}
```

### handlers/<tool>.ts

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

### formatters.ts

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

### Test Pattern

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

### .mcpbignore (TypeScript)

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

### CI Workflows (TypeScript)

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
          node-version: "24"
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
          node-version: "24"
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
          node-version: "24"
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
          node-version: "24"
          cache: "npm"
      - run: npm ci && npm run build
      - run: npm prune --omit=dev
      - uses: NimbleBrainInc/mcpb-pack@v2
        with:
          output: "{name}-{version}-${{ matrix.os }}-${{ matrix.arch }}.mcpb"
```

### Build & Test Commands (TypeScript)

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

## Tool Design Guidelines (Both Languages)

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
