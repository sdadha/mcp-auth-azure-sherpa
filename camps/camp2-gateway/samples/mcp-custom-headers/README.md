# MCP Custom Headers Sample

Demonstrates how to pass custom headers from an MCP client to an MCP server.

## Use Cases

Custom headers enable passing context to your MCP server:

- **Correlation headers** (`x-correlation-id`) for distributed tracing
- **Tenant context** (`x-customer-id`, `x-tenant-id`) for multi-tenant scenarios
- **OAuth tokens** (`Authorization: Bearer <token>`) for authentication

## Architecture

```text
┌─────────────────────┐                  ┌─────────────────────┐
│   MCP Client        │   HTTP + Headers │   MCP Server        │
│                     │ ───────────────► │   (Sherpa)          │
│  Custom headers:    │                  │                     │
│  - Authorization    │                  │  Receives headers:  │
│  - x-customer-id    │                  │  - Auth validated   │
│  - x-tenant-id      │                  │  - Context used     │
│  - x-correlation-id │                  │  - Tracing enabled  │
└─────────────────────┘                  └─────────────────────┘
```

## Prerequisites

- Python 3.11+
- [uv](https://docs.astral.sh/uv/) package manager
- Azure CLI (`az login` for authentication)

## Setup

```bash
# Install base dependencies
uv sync

# Configure environment
cp .env.sample .env
# Edit .env with your MCP server URL and OAuth scope
```

## Configuration

Edit `.env` with your MCP server details:

```bash
MCP_SERVER_URL=https://your-mcp-server/mcp
MCP_OAUTH_SCOPE=api://your-app-client-id/.default
AZURE_TENANT_ID=your-tenant-id
```

**Note on OAuth scope:** The `.default` suffix requests all authorized scopes for the resource. The actual scope in the token (e.g., `user_impersonate`) comes from the app registration's exposed API configuration.

## Samples

This sample provides three different approaches to demonstrate custom headers with MCP, from simplest to most sophisticated:

| Sample | Best For | Dependencies |
|--------|----------|--------------|
| `test_live.py` | Quick testing, debugging | Base only |
| `direct_mcp_client.py` | Custom integrations, learning MCP protocol | Base only |
| `agent_framework_headers.py` | Production AI agents | + agent-framework |

### Implementation Comparison

| Aspect | `test_live.py` | `direct_mcp_client.py` |
|--------|----------------|------------------------|
| **Execution** | Synchronous | Async (`asyncio`) |
| **OAuth** | `az` CLI subprocess | `DefaultAzureCredential` SDK |
| **Structure** | Inline procedural | Reusable `MCPClient` class |
| **HTTP Client** | `httpx.post()` | `httpx.AsyncClient` |
| **Session Mgmt** | Manual | Auto (`_ensure_initialized()`) |
| **Output** | Verbose debugging | Clean results |

**Quick decision:** Use `test_live.py` when asking "Is my auth working?" or "What does the raw response look like?" Use `direct_mcp_client.py` when embedding MCP calls in your application.

### 1. Quick Test (`test_live.py`)

**Purpose:** Minimal script for quick testing and debugging. Shows the raw MCP protocol.

**Approach:** Uses `az` CLI for OAuth tokens and raw `httpx` for HTTP calls. Prints all request/response details.

```bash
uv run test_live.py
```

**When to use:** Quick verification that headers flow through correctly, debugging authentication issues, understanding the MCP wire protocol.

---

### 2. Direct Client (`direct_mcp_client.py`)

**Purpose:** Reusable `MCPClient` class demonstrating proper MCP session management.

**Approach:** Async Python client with clean API (`initialize()`, `list_tools()`, `call_tool()`). Handles SSE responses and session ID management.

```bash
uv run direct_mcp_client.py
```

**When to use:** Building custom MCP integrations, embedding MCP in your own applications, learning the MCP Streamable HTTP transport.

**Key features:**
- Reusable `MCPClient` class
- Automatic session initialization
- Proper SSE response parsing
- Correlation ID generation

---

### 3. Agent Framework (`agent_framework_headers.py`)

**Purpose:** Production-ready AI agent using [Microsoft Agent Framework](https://github.com/microsoft/agent-framework).

**Approach:** Uses `AzureOpenAIResponsesClient` with `client.get_mcp_tool()` to create MCP-backed tools for AI agents.

```bash
# Install agent-framework (pre-release)
uv pip install agent-framework --pre

# Run the sample
uv run agent_framework_headers.py
```

**Additional configuration required in `.env`:**
```bash
AZURE_AI_PROJECT_ENDPOINT=https://your-foundry.services.ai.azure.com/api/projects/your-project
AZURE_OPENAI_RESPONSES_DEPLOYMENT_NAME=gpt-4o
```

**When to use:** Building production AI agents, integrating MCP tools with Azure AI Foundry, leveraging the Agent Framework ecosystem.

**Key features:**
- LLM automatically discovers and calls MCP tools
- Full conversation context maintained
- Built-in observability and tracing

## Example Output

```
============================================================
MCP Custom Headers - Sherpa Server Demo
============================================================

✓ OAuth token acquired

📤 Custom headers being sent:
   x-customer-id: demo-customer
   x-tenant-id: demo-tenant
   x-correlation-id: test-12345

------------------------------------------------------------
Step 1: Initialize MCP Session
------------------------------------------------------------
✓ Connected to: Sherpa MCP Server
✓ Session ID: abc123...

------------------------------------------------------------
Step 2: List Tools
------------------------------------------------------------
📥 Response: Found 3 tools:
   • get_weather: Get current weather conditions...
   • check_trail_conditions: Check current conditions...
   • get_gear_recommendations: Get recommended gear list...

------------------------------------------------------------
Step 3: Call get_weather Tool
------------------------------------------------------------
📥 Response:
{
   "location": "Mount Rainier",
   "temp_f": 45,
   "conditions": "Clear"
}

============================================================
✓ Demo complete
============================================================
```

## Key Code Patterns

### Passing custom headers (httpx)

```python
headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json",
    "Accept": "application/json, text/event-stream",
    # Custom context headers
    "x-customer-id": "demo-customer",
    "x-tenant-id": "demo-tenant",
    "x-correlation-id": "test-12345"
}

response = httpx.post(mcp_url, headers=headers, json=payload)
```

### MCP session initialization

```python
# MCP requires session initialization first
init_payload = {
    "jsonrpc": "2.0",
    "method": "initialize",
    "id": 1,
    "params": {
        "protocolVersion": "2025-03-26",
        "capabilities": {},
        "clientInfo": {"name": "my-client", "version": "1.0.0"}
    }
}
response = httpx.post(mcp_url, headers=headers, json=init_payload)
session_id = response.headers.get("mcp-session-id")

# Include session ID in subsequent requests
headers["mcp-session-id"] = session_id
```

### Agent Framework with MCP tool

```python
from agent_framework import Agent
from agent_framework.azure import AzureOpenAIResponsesClient

client = AzureOpenAIResponsesClient(
    project_endpoint=os.environ["AZURE_AI_PROJECT_ENDPOINT"],
    deployment_name=os.environ["AZURE_OPENAI_RESPONSES_DEPLOYMENT_NAME"],
    credential=AzureCliCredential(),
)

mcp_tool = client.get_mcp_tool(
    name="sherpa",
    url=mcp_url,
    headers=custom_headers,  # Custom headers passed here
    approval_mode="never_require",
)

async with Agent(client=client, tools=mcp_tool) as agent:
    result = await agent.run("What is the weather?")
```

## Related Resources

- [MCP Protocol Specification](https://modelcontextprotocol.io/)
- [Microsoft Agent Framework](https://github.com/microsoft/agent-framework)
- [MCP Security Workshop](https://aka.ms/sherpa)
