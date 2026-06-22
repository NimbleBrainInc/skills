# MCP Server Code Patterns (Python)

## Directory Structure

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

## Implementation Order

1. **`api_models.py`** — Pydantic models for API responses. Use `Field(alias=...)` for camelCase mapping.
2. **`api_client.py`** — Async aiohttp client. Set BASE_URL, add one method per endpoint.
3. **`server.py`** — FastMCP server with `@mcp.tool()` decorators. Global client with lazy init. Dual transport (http_app + stdio).
4. **`manifest.json`** + **`server.json`** — Fill all placeholder fields. See `CONVENTIONS-PY.md` for the full schema.

## .gitignore

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

## pyproject.toml

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

## server.py

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

## api_client.py

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

## api_models.py

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

## .mcpbignore

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

## CI Workflows

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
      - uses: actions/checkout@v6
      - uses: astral-sh/setup-uv@v4
      - run: uv python install 3.13
      - run: uv sync --dev
      - run: uv run ruff format --check src/ tests/
      - run: uv run ruff check src/ tests/
      - run: uv run ty check src/

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
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
      - uses: actions/checkout@v6
      - name: Update manifest version
        run: |
          VERSION="${{ github.event.release.tag_name }}"
          VERSION="${VERSION#v}"
          jq --arg v "$VERSION" '.version = $v' manifest.json > manifest.tmp.json
          mv manifest.tmp.json manifest.json
      - uses: NimbleBrainInc/mcpb-pack@v3
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
      - uses: actions/checkout@v6
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

## `bundle` Target (Makefile)

```makefile
bundle: ## Build MCPB bundle locally
	rm -rf deps/
	uv pip install --target ./deps --only-binary :all: . 2>/dev/null || uv pip install --target ./deps .
	npx @anthropic-ai/mcpb pack .
	@echo "Bundle created. Run 'ls -la *.mcpb' to see it."
```

This vendors dependencies into `deps/` (same as the GitHub Action does), then packs. Contributors can validate bundles locally before releasing.

## Test Patterns

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

**Integration tests (`tests-integration/`)** — Requires real API key in `.env`. Run with `make test-integration`.

`tests-integration/conftest.py` — The template scaffolds this with an env var gate and client fixture. It loads `.env` automatically via `load_dotenv()`, so the contributor just needs to add their key to `.env` rather than exporting it.

`tests-integration/test_core_tools.py` — Derive tests from `api_client.py`. Do NOT leave this as a stub or TODO. Write one test class per logical group of methods.

**Pattern 1 — Read-only method:**
```python
class TestListProjects:
    @pytest.mark.asyncio
    async def test_list_projects(self, client):
        # Chain: get a workspace ID first, then list its projects
        workspaces = await client.list_workspaces()
        assert len(workspaces) > 0
        workspace_gid = workspaces[0]["gid"]

        result = await client.list_projects(workspace_gid)
        assert isinstance(result, dict)
        assert "data" in result
        print(f"Found {len(result['data'])} project(s)")
```

**Pattern 2 — Write method with cleanup:**
```python
class TestContactCRUD:
    @pytest.mark.asyncio
    async def test_contact_lifecycle(self, client):
        contact = None
        try:
            contact = await client.create_contact(
                email=f"test-{int(time.time())}@example.com",
                first_name="Integration",
                last_name="Test",
            )
            assert contact["id"]

            fetched = await client.get_contact(contact["id"])
            assert fetched["id"] == contact["id"]

            updated = await client.update_contact(
                contact["id"], first_name="Updated"
            )
            assert updated["id"] == contact["id"]
        finally:
            if contact:
                await client.delete_contact(contact["id"])
```

**Pattern 3 — Tier-gated method:**
```python
async def has_search_access(client, workspace_gid: str) -> bool:
    try:
        await client.search_tasks(workspace_gid, text="test", limit=1)
        return True
    except APIError as e:
        if e.status in (400, 402, 403):
            return False
        raise

class TestSearchTasks:
    @pytest.mark.asyncio
    async def test_search_tasks(self, client):
        workspaces = await client.list_workspaces()
        workspace_gid = workspaces[0]["gid"]

        if not await has_search_access(client, workspace_gid):
            pytest.skip("Task search requires premium plan")

        result = await client.search_tasks(workspace_gid, text="test", limit=5)
        assert isinstance(result, list)
```

**Key rules:**
- One test per method or per logical CRUD lifecycle is enough. Don't over-test — you're checking "does the API call work?", not exhaustive coverage.
- Don't test error cases here — unit tests already cover those with mocks.
- Always clean up write operations in `finally` blocks. If no delete method exists, mark resources as completed/archived.
- Use `print()` for visibility — integration tests often run interactively.
- Use timestamped names for created resources (e.g., `f"test-{int(time.time())}@example.com"`) to avoid collisions.

**LLM smoke tests (`tests-integration/test_skill_llm.py`)** — Requires `ANTHROPIC_API_KEY` in `.env`. Run with `make test-llm`.

Sends server context (instructions + skill + tools) to Claude Haiku, asserts correct tool selection. The template scaffolds `get_server_context()` and `get_anthropic_client()` — leave those as-is. Replace the commented-out test stub with real tests.

Write **3–5 tests**, one per key tool. Extract a `call_llm()` helper to avoid repeating the system prompt construction:

```python
async def call_llm(prompt: str) -> list:
    """Send a prompt to Claude Haiku with full server context, return tool calls."""
    ctx = await get_server_context()
    client = get_anthropic_client()
    system = (
        f"You are an assistant.\n\n"
        f"## Server Instructions\n{ctx['instructions']}\n\n"
        f"## Skill Resource\n{ctx['skill']}"
    )
    response = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=1024,
        system=system,
        messages=[{"role": "user", "content": prompt}],
        tools=[{"type": "custom", **t} for t in ctx["tools"]],
    )
    return [b for b in response.content if b.type == "tool_use"]

class TestSkillLLMInvocation:
    @pytest.mark.asyncio
    async def test_list_projects_selected(self):
        tool_calls = await call_llm("Show me all projects in workspace gid_123456")
        assert len(tool_calls) > 0, "LLM did not call any tool"
        assert tool_calls[0].name == "list_projects"

    @pytest.mark.asyncio
    async def test_create_task_selected(self):
        tool_calls = await call_llm("Create a task called Review Q3 report in workspace gid_123456")
        assert len(tool_calls) > 0, "LLM did not call any tool"
        assert tool_calls[0].name == "create_task"
```

**Key rule — include concrete values for required parameters:** If a tool requires parameters (IDs, coordinates, dates), include concrete values in the prompt — even fake ones. Without them, the LLM will correctly ask for clarification instead of calling the tool, and the test will fail with "LLM did not call any tool." Examples:
- "Show me projects in workspace gid_123456" (not "Show me my projects")
- "What's the weather at lat=51.5, lon=-0.13?" (not "What's the weather in London?")
- "Am I busy tomorrow afternoon?" (not "Am I busy Thursday?" — ambiguous date)

## Build & Test Commands

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

<!-- The "Tool Design Guidelines" and "API Analysis Checklist" sections below are language-agnostic and duplicated verbatim in PATTERNS-TS.md — keep the two in sync when editing either. -->

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
