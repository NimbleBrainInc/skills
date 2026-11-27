# Python: a server on nimblebrain-server-sdk

The default path. The server is a [FastMCP](https://gofastmcp.com) 4 server built on [`nimblebrain-server-sdk`](https://pypi.org/project/nimblebrain-server-sdk/), which gives it what an MCP host reads: tool annotations, one error contract, server-published skills, a Server Card, and test helpers that connect the way a host does. Nothing in it ties the server to NimbleBrain; any MCP host can connect to the result.

Guides, kept current with each release: [quickstart](https://docs.nimblebrain.ai/server-sdk/quickstart/), [tools and annotations](https://docs.nimblebrain.ai/server-sdk/tools/), [errors](https://docs.nimblebrain.ai/server-sdk/errors/), [skills](https://docs.nimblebrain.ai/server-sdk/skills/), [Server Card](https://docs.nimblebrain.ai/server-sdk/server-card/), [testing](https://docs.nimblebrain.ai/server-sdk/testing/), [compatibility](https://docs.nimblebrain.ai/server-sdk/compatibility/). When this page and a guide disagree, the guide wins.

## Versions

Python 3.13 or later, FastMCP 4.0 or later, `nimblebrain-server-sdk` 0.7 or later (`add_server_card` needs 0.8.0). The SDK is `0.x`: a minor release may change the Python API, so pin a minor range (`>=0.8,<0.9` for the card) and move it on purpose. Tooling is `uv`, `ruff` and `ty`; commit `uv.lock` and install with `--locked` everywhere (`deploy.md`).

## Start a repository

Start from a new repository, and read a maintained server for how each part is done. Two
public ones cover the range:

- [**`NimbleBrainInc/todosforagents`**](https://github.com/NimbleBrainInc/todosforagents):
  a server with a store, keyset paging, a board UI, prompts, a local runtime, and golden
  records of its surface.
- [**`NimbleBrainInc/mcp-careers`**](https://github.com/NimbleBrainInc/mcp-careers): a small
  stateless server shipped as a container, with a person-confirmed write, Redis limits, and
  the CI and release pipeline in `deploy.md`.

Copy patterns, not a whole repository: a copied server brings its domain with it.

```bash
uv init --package mcp-<service> && cd mcp-<service>
uv add "fastmcp>=4.2,<5" "nimblebrain-server-sdk>=0.8.1,<0.9" pydantic uvicorn
uv add --dev pytest pytest-asyncio ruff ty
```

Set `asyncio_mode = "auto"` under `[tool.pytest.ini_options]`. Then build it in this layout:

```
src/mcp_<service>/
├── __init__.py      # __version__ = importlib.metadata.version("mcp-<service>")
├── server.py        # FastMCP server, tools, resources, entrypoints
├── config.py        # every setting, read from the environment in one place
├── api_client.py    # async client for the upstream; raises a typed error with the HTTP status
└── skills/<service>/SKILL.md   # the server-published skill
tests/
├── golden/          # the recorded surface, one file per protocol era
└── test_*.py        # on both protocol eras
server.json          # restates the Server Card, plus where it is deployed (deploy.md)
Dockerfile           # when it ships as a container (deploy.md)
```

Read the version from the installed package, so `pyproject.toml` is its one source.

Logs go to stderr with the `logging` module. Never log to the client (`ctx.info`, `ctx.error`): MCP's logging capability is deprecated in the `2026-07-28` revision, and a failure the caller must see is a raised `ServiceError`.

## The server

Name the server in reverse-DNS form and give it its own version. The Server Card requires the name form, and without `version=` FastMCP reports its own version as the server's.

```python
from fastmcp import FastMCP
from nimblebrain_server_sdk import add_error_contract, add_skills

from mcp_acme import __version__

mcp = FastMCP("com.acme/tickets", version=__version__, instructions="...")
add_error_contract(mcp)
add_skills(mcp, [SKILLS_DIR / "tickets"])
```

Keep `instructions` to what every conversation needs; detail goes in the skill.

## Annotate every tool

```python
from nimblebrain_server_sdk import ADDS, CHANGES, READS

@mcp.tool(annotations=READS)    # reads and changes nothing
@mcp.tool(annotations=ADDS)     # writes without losing anything already there
@mcp.tool(annotations=CHANGES)  # overwrites, removes, sends, or acts on what is there
```

Every tool gets one. An unannotated tool reads to a client as a destructive write. The annotation describes; it enforces nothing.

## Give every tool a title, a typed result and its hints

```python
from typing import Literal
from pydantic import BaseModel, Field

class SubmitResult(BaseModel):
    status: Literal["awaiting_confirmation"]
    confirm_url: str = Field(description="Give this to the person.")

@mcp.tool(
    title="Send an application",                       # for people; `name` is for the model
    annotations=ADDS.model_copy(update={"idempotent_hint": False, "open_world_hint": False}),
)
async def acme_submit(...) -> SubmitResult: ...
```

- **`title`** is what a host shows a person. The model reasons about `name`.
- **A Pydantic return type** becomes the tool's `outputSchema`, and FastMCP also returns the
  JSON as text for clients that ignore structured content. A bare `dict` advertises nothing.
- **`idempotent_hint` and `open_world_hint`** are worth setting when you know them: a read
  is usually idempotent, and a tool that only touches its own store is closed-world.
- **Every parameter is `Annotated[..., Field(description=...)]`**, with a default for each
  optional one.

## Fail with the error contract

A tool reports a failure by raising `ServiceError` with a code from the closed set; `add_error_contract(mcp)`, called once, returns it as an `isError: true` result with structured content `{"error": {"code", "retryable", "message"}}`.

```python
from nimblebrain_server_sdk.errors import ErrorCode, ServiceError

@mcp.tool(annotations=READS)
async def get_ticket(ticket_id: str) -> dict[str, Any]:
    """..."""
    if not ticket_id.strip():
        raise ServiceError(ErrorCode.BAD_INPUT, "`ticket_id` is empty.")
    try:
        return await client.get_ticket(ticket_id)
    except AcmeAPIError as e:
        raise ServiceError.from_upstream(e.status, detail=e.message) from e
```

- `from_upstream(status)` classifies an upstream HTTP status (401, 403, 404, 409, 402 quota, 429, timeouts, other 5xx and 4xx) into the right code.
- `message` reaches the host and the model: generic and actionable. `detail` is logged, never sent: the upstream's own text goes there.
- Never return a dict that describes an error. It has no `isError`, so the host and the model score it as a success.
- Never raise `ValueError` for a caller's mistake; that is `BAD_INPUT`.
- Start the message with its code (`"bad_input: …"`). The code also rides in structured content, but some clients show the model only the text, and a skill that tells the agent what to do per code needs the agent to see it.
- Name the rule that failed and what to do next, not every rule the field has: `` `resume_url` must start with https:// `` beats a list of all four checks.
- A resource read has no error result to carry the envelope: catch the `ServiceError` and raise FastMCP's `ResourceError(e.message)`.

The codes and their retry semantics are on the [errors guide](https://docs.nimblebrain.ai/server-sdk/errors/).

## Bound listings, and give each row a uri

A listing row carries an unbounded field as a preview or not at all, plus a `uri` the whole record is read from, and that `uri` resolves to a resource template.

```python
from nimblebrain_server_sdk import PREVIEW_CHARS, listing_row

return [
    listing_row({**t, "uri": f"acme://tickets/{t['id']}"}, preview={"body": PREVIEW_CHARS})
    for t in tickets
]

@mcp.resource("acme://tickets/{ticket_id}", name="ticket", mime_type="application/json")
async def ticket_resource(ticket_id: str) -> str: ...
```

`new_prefixed_id("tk")` mints opaque, sortable record ids when the server owns its records.

## Publish a skill

A skill is how the server tells an agent when and how to use its tools, in more words than a description should carry. It is a directory holding a `SKILL.md` whose frontmatter has a `name` (equal to the directory's name) and a `description`, plus any reference files.

```python
add_skills(mcp, [Path(__file__).parent / "skills" / "tickets"])
```

`add_skills` declares the MCP Skills extension (`io.modelcontextprotocol/skills`), answers `skills/list` and `skills/get` with each file's digest and size, and serves every file at `skill://<name>/<file>`; the entry point is `skill://<name>/SKILL.md`. It checks each skill when the server is imported. Do not register `skill://` resources by hand: a host verifies each file against the listed digest, and a hand-registered resource at the same URI fails at startup.

Write the skill as a table of when to use each tool, which output feeds which input, and a workflow or two.

## Test on both protocol eras

A host connects on `2026-07-28` (`server/discover`) or `2025-11-25` (`initialize`), so every test that crosses the wire runs on both:

```python
import pytest
from fastmcp import Client
from nimblebrain_server_sdk.testing import Mode, assert_bounded_rows, served_skills

from mcp_acme.server import mcp

@pytest.mark.parametrize("mode", ["auto", "legacy"])
async def test_the_skill_is_served(mode: Mode) -> None:
    assert set(await served_skills(mcp, mode)) == {"skill://tickets/SKILL.md"}

@pytest.mark.parametrize("mode", ["auto", "legacy"])
async def test_an_empty_id_is_bad_input(mode: Mode) -> None:
    async with Client(mcp, mode=mode) as client:
        result = await client.call_tool("get_ticket", {"ticket_id": " "}, raise_on_error=False)
    assert result.is_error
    assert result.structured_content["error"]["code"] == "bad_input"
```

`assert_bounded_rows(rows, unbounded=("body",))` checks a listing; seed the unbounded field longer than its limit first. Set `asyncio_mode = "auto"` under `[tool.pytest.ini_options]`. Mock the upstream API in unit tests; keep tests against the real API in a separate directory that needs the key.

## Record the surface in golden files

A unit test checks behaviour; it does not notice that a description changed, a parameter
lost its `description`, or an annotation flipped. Record what a host sees, once per
protocol era, and fail on any difference:

```python
@pytest.mark.parametrize("mode", ["auto", "legacy"])
async def test_the_surface_matches_the_golden_record(mode: Mode) -> None:
    async with Client(mcp, mode=mode) as client:
        record = {"tools": sorted((t.model_dump(mode="json", by_alias=True, exclude_none=True)
                                   for t in await client.list_tools()), key=lambda t: t["name"]),
                  "instructions": mcp.instructions}   # plus resources (with a digest of each), prompts, the Server Card
    path = GOLDEN / f"{mode}.json"
    actual = json.dumps(record, indent=2, sort_keys=True) + "\n"
    if os.getenv("UPDATE_GOLDEN") == "1":
        path.write_text(actual)
    assert actual == path.read_text(), "surface changed: review, then UPDATE_GOLDEN=1"
```

An intended change regenerates the files in the same PR, so the reviewer sees the surface
diff. Leave the version out of the record, or every release rewrites it.

## Serve over streamable HTTP

Expose an ASGI app (`app = mcp.http_app()`, at `/mcp`), and a stdio entrypoint if anyone runs it locally. For a host that connects by URL:

```bash
ACME_API_KEY=... uv run uvicorn mcp_acme.server:app --host 127.0.0.1 --port 8000
```

The server is then at `http://127.0.0.1:8000/mcp`. Binding `0.0.0.0` also exposes the server to the network; use it only when you mean that (the Linux case in `SKILL.md`).

## Serve a Server Card

An MCP Server Card ([SEP-2127](https://github.com/modelcontextprotocol/modelcontextprotocol/pull/2127)) names and describes the server to a host before it connects. With SDK 0.8.0 or later:

```python
from nimblebrain_server_sdk import add_server_card

add_server_card(mcp, title="Acme Tickets", description="Search, read and update Acme support tickets.")
```

- It is served at `<mcp-url>/server-card` (`http://127.0.0.1:8000/mcp/server-card`), over streamable HTTP only, public and read-only.
- `name`, `version`, `websiteUrl` and `icons` come from the `FastMCP(...)` constructor, so the card cannot contradict the live connection. `title` and `description` are 1 to 100 characters, for a person choosing the server; the `instructions` are for the model.
- An app's server passes `placements=[...]` to put its `ui://` views in a host's navigation; see the [Server Card guide](https://docs.nimblebrain.ai/server-sdk/server-card/).
- It refuses at import a name that is not reverse-DNS, an empty or over-long title or description, and a version range.

Check it: `curl -s http://127.0.0.1:8000/mcp/server-card`.

On an older SDK pin, skip the card: the server still connects, named by its `serverInfo`.

The same values, plus the deployed URL, go in the repository's `server.json` (`references/deploy.md`); keep the two in agreement.

## An app's server half

An app is the same server plus a `ui://` resource that FastMCP 4 serves with `fastmcp.apps.AppConfig`, and tools bound to it. No extra package is needed on the server. Build the interface with the `synapse` skill; it covers the resource, the CSP, and binding tools to the view. Write tools so they work for the agent with no interface: the view is a second caller of the same tools.
