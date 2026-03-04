---
hide:
  - toc
---

# Section 1: Gateway Logging

*Explore pre-configured diagnostics and validate logs flow*

← [Camp 4 Overview](index.md)

---

APIM processes all your MCP traffic, and in this workshop, diagnostic settings are pre-configured via Bicep. This section explores what's been configured and validates that logs are flowing.

## The Logging Gap: Before & After

Understanding diagnostic settings helps when configuring other Azure resources. Here's what APIM looks like without diagnostic settings vs with them:

```
WITHOUT: No Diagnostic Settings                WITH: Diagnostics Enabled (Our Setup)
═══════════════════════════════════════        ═══════════════════════════════════════

   MCP Client                                     MCP Client
       │                                              │
       ▼                                              ▼
┌──────────────┐                                ┌──────────────┐
│    APIM      │                                │    APIM      │───────────────────┐
│   Gateway    │                                │   Gateway    │                   │
│              │                                │              │   Diagnostic      │
│  • Routes ✓  │                                │  • Routes ✓  │   Settings        │
│  • Policies ✓│                                │  • Policies ✓│                   │
│  • Logs?     │                                │  • Logs ✓    │                   ▼
└──────┬───────┘                                └──────┬───────┘        ┌─────────────────┐
       │                                               │                │  Log Analytics  │
       ▼                                               ▼                │                 │
┌─────────────┐                                ┌─────────────┐          │ • GatewayLogs   │
│   Backend   │                                │   Backend   │          │ • GatewayLlmLogs│
│   Services  │                                │   Services  │          └─────────────────┘
└─────────────┘                                └─────────────┘                │
                                                                              ▼
Traffic works fine,                            Traffic works AND           KQL Queries
but NO VISIBILITY                              you can QUERY everything    Dashboards
                                                                           Alerts
```

## Why Gateway Logging Matters

Azure API Management sits at the front door of your MCP infrastructure. Every request, legitimate or malicious, passes through it. In this workshop, **APIM diagnostic settings are pre-configured via Bicep**, so you can immediately query logs once `azd up` completes.

!!! success "Pre-Configured for Learning"
    Unlike a default APIM deployment where you'd have no visibility, this workshop configures diagnostic settings automatically during infrastructure deployment. This means:
    
    - :material-check: Gateway logs flow to Log Analytics immediately
    - :material-check: You can start querying traffic right away
    - :material-check: No manual configuration required

With diagnostic settings enabled, you have full visibility into:

- Who called your APIs (IP addresses)  
- What MCP tools were invoked  
- How long requests took  
- Which requests failed and why

!!! example "The Security Guard Analogy"
    It's like having a security guard who checks IDs **and** writes down every entry in a log book. The guard does their job, and there's a complete record anyone can review later.

## Understanding Diagnostic Settings

**Diagnostic Settings** are Azure's way of routing telemetry from a resource to a destination. For APIM, you configure:

- **Source**: Which log categories to capture (GatewayLogs, GatewayLlmLogs)
- **Destination**: Where to send them (Log Analytics workspace)

In this workshop, the Bicep infrastructure configures these automatically. Once deployed, APIM streams logs to your workspace without any manual steps.

## 1.1 Explore APIM Gateway Logging

??? abstract "Send Traffic and See Logs Flow"

    Run the script to send traffic through APIM and verify logging:

    ```bash
    ./scripts/section1/1.1-explore.sh
    ```

    **What this script does:**

    1. **Sends legitimate MCP requests** through APIM
    2. **Sends attack requests** (SQL injection, path traversal)
    3. **Verifies diagnostic settings** are configured
    4. **Shows sample KQL queries** you can run

    **What you'll see:**

    | Component | Status |
    |-----------|--------|
    | :material-check: APIM routes requests | Working |
    | :material-check: Security function blocks attacks | Working |
    | :material-check: Diagnostic settings configured | Pre-deployed via Bicep |
    | :material-check: Logs flowing to Log Analytics | Verified |

    !!! tip "Log Ingestion Delay"
        Azure Monitor has a 2-5 minute ingestion delay. The first logs from a new deployment may take 5-10 minutes to appear.

## 1.2 Verify Diagnostic Configuration

??? success "Understand What's Configured"

    Examine the diagnostic settings:

    ```bash
    ./scripts/section1/1.2-verify.sh
    ```

    **What this does:**

    Shows you the diagnostic settings deployed via Bicep, including enabled log categories and destination.

    **ApiManagementGatewayLogs (HTTP level):**

    | Field | Description |
    |-------|-------------|
    | `CallerIpAddress` | Client IP (for investigations) |
    | `ResponseCode` | HTTP response code |
    | `CorrelationId` | For cross-service tracing |
    | `Url`, `Method` | Request path and HTTP method |
    | `ApiId` | API identifier for filtering |

    **ApiManagementGatewayLlmLog (AI/LLM gateway):**

    | Field | Description |
    |-------|-------------|
    | `PromptTokens` | Input token count |
    | `CompletionTokens` | Output token count |
    | `ModelName` | LLM model used |
    | `CorrelationId` | For cross-service tracing |

    !!! tip "Verify in Azure Portal"
        You can also view diagnostic settings by navigating to your APIM resource:
        
        **APIM** → **Monitoring** → **Diagnostic settings** → **mcp-security-logs**
        
        You should see `GatewayLogs` and `GatewayLlmLogs` enabled, pointing to your Log Analytics workspace.

## 1.3 Validate Logs Appear

!!! warning "Wait for Log Ingestion"
    For new deployments, logs need 2-5 minutes to appear in Log Analytics. If you run this immediately after `azd up`, you may see "No HTTP logs found yet." Wait a few minutes and try again.

??? success "Query APIM Logs"

    Verify logs are flowing:

    ```bash
    ./scripts/section1/1.3-validate.sh
    ```

    **HTTP traffic query (ApiManagementGatewayLogs):**

    ```kusto
    ApiManagementGatewayLogs
    | where TimeGenerated > ago(1h)
    | where ApiId contains "mcp" or ApiId contains "sherpa"
    | project TimeGenerated, CallerIpAddress, Method, Url, ResponseCode, ApiId
    | order by TimeGenerated desc
    | limit 20
    ```

    !!! tip "New to KQL?"
        KQL reads left-to-right with `|` pipes, like Unix commands. See the [KQL Primer](reference.md#a-quick-kql-primer) for a full introduction.

    !!! tip "Filtering by ApiId vs Url"
        Using `ApiId contains "mcp"` is more reliable than `Url contains "/mcp/"` because ApiId is a structured field set during API import/configuration, while Url parsing can be fragile.

---

## Key Log Tables

This section uses these Azure Monitor log tables:

| Log Table | APIM Category | Key Fields |
|-----------|---------------|------------|
| **ApiManagementGatewayLogs** | GatewayLogs | `CallerIpAddress`, `ResponseCode`, `CorrelationId`, `Url`, `Method`, `ApiId` |
| **ApiManagementGatewayLlmLog** | GatewayLlmLogs | `PromptTokens`, `CompletionTokens`, `ModelName`, `CorrelationId` |

!!! info "Correlation IDs"
    The **CorrelationId** field appears across all log tables and is essential for incident response. It allows you to trace a single request from APIM through the security function and back, correlating HTTP logs and application traces.

---

Logs from API Management are now flowing. But the security function's internal operations (what attacks were blocked, what PII was found) are still invisible. Let's fix that.

[Next: Function Observability →](section2-function-observability.md){ .md-button .md-button--primary }

---

← [Overview & Deploy](index.md) | [Function Observability →](section2-function-observability.md)
