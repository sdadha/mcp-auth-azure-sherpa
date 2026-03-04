---
hide:
  - toc
---

# Camp 4: Monitoring & Telemetry

*Reaching Observation Peak*

![Monitoring](../../images/sherpa-monitoring.png)

!!! info "Camp Details"
    **Tech Stack:** Log Analytics, Application Insights, Azure Monitor, Workbooks, API Management, Container Apps, Functions, MCP  
    **Primary Risks:** [MCP08](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp08-telemetry/) (Lack of Audit and Telemetry)

### Welcome to Observation Peak!

You've made it to Camp 4, the last skill-building camp before the Summit! Throughout your journey, you've built authentication (Camp 1), MCP gateways (Camp 2), and I/O security (Camp 3). Your MCP server is now protected by multiple layers of defense.

But here's a question: **How do you know it's working?**

If an attacker probed your system last night, would you know? If your security function blocked 100 injection attempts yesterday, could you prove it to an auditor? If there's a sudden spike in attacks right now, would you be alerted?

This is where **observability** comes in, and it's just as important as the security controls themselves.

!!! quote "The Key Insight"
    Security controls without observability are like locks without security cameras. You might stop the intruder, but you'll never know they tried to get in.

---

## What You'll Build

By the end of Camp 4, every request will be logged, visualized, and alertable. Here's the complete architecture:

```
┌─────────────────────────────────────────────────────────────────┐
│                         MCP Client                              │
└───────────────────────────────┬─────────────────────────────────┘
                                │ HTTPS Request
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                     API Management (APIM)                       │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │ LAYER 1: Prompt Shields (AI Content Safety)             │   │
│   │   • Scans for prompt injection attacks                  │   │
│   │   • Blocks jailbreak/manipulation attempts              │   │
│   │   • Logs via <trace> policy → AppTraces                 │   │
│   │     └── Properties.event_type (direct)                  │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│   • Receives all MCP traffic                                    │
│   • Applies policies (auth, rate limiting)                      │
│   • Generates CorrelationId for tracing                         │
│   • Routes clean requests to security function                  │
│                                                                 │
│   Diagnostic Settings → Log Analytics                           │
│   └── GatewayLogs (HTTP details)                                │
│   └── GatewayLlmLogs (LLM usage)                                │
│   └── WebSocketConnectionLogs (WebSocket events)                │
└───────────────────────────────┬─────────────────────────────────┘
                                │ (if not blocked by Layer 1)
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Security Function (Layer 2)                  │
│   • Receives forwarded request + CorrelationId                  │
│   • Regex checks for SQL, path traversal, shell injection       │
│   • Scans for PII/credentials in responses                      │
│   • Logs structured events with custom dimensions               │
│                                                                 │
│   Application Insights SDK → AppTraces table                    │
│   └── Properties.custom_dimensions.event_type                   │
│   └── Properties.custom_dimensions.injection_type               │
│   └── Properties.custom_dimensions.correlation_id               │
└─────────────────────────────────────────────────────────────────┘
```

<div class="grid cards" markdown>

- :material-math-log:{ .lg .middle } __Structured Logging__

    ---

    Transform generic log messages into rich, queryable events with custom dimensions like `event_type`, `category`, and `correlation_id`.

- :material-chart-line:{ .lg .middle } __Security Dashboard__

    ---

    Visualize attacks, PII redactions, and credential exposures in real-time with Azure Workbooks.

- :material-bell-alert:{ .lg .middle } __Smart Alerting__

    ---

    Get notified immediately when attack rates spike or credentials are exposed.

- :material-magnify:{ .lg .middle } __KQL Queries__

    ---

    Learn Kusto Query Language to analyze security events and create custom reports.

</div>

---

## Prerequisites

Before starting Camp 4, ensure you have:

:material-check: Azure subscription with Contributor access  
:material-check: Azure CLI installed and logged in (`az login`)  
:material-check: Azure Developer CLI installed (`azd auth login`)  
:material-check: Docker installed and running (for Container Apps deployment)  
:material-check: Completed Camp 3: I/O Security (recommended, but not required)

!!! note "Standalone Lab"
    While Camp 4 builds on concepts from earlier camps, it's designed to work standalone. The `azd up` command will deploy everything you need, including the security function from Camp 3.

:material-arrow-right: [Full prerequisites guide](../../prerequisites.md) with installation instructions for all tools.

---

## Getting Started

```bash
# Navigate to Camp 4
cd camps/camp4-monitoring

# Deploy infrastructure AND services (~15 minutes)
azd up
```

This deploys:

- **Security Function v1** - Basic logging (the "hidden" state) - **ACTIVE**
- **Security Function v2** - Structured logging with Azure Monitor - deployed but not active
- **Log Analytics Workspace** - Central log storage for querying
- **Application Insights** - Telemetry collection (shared by all services)
- **APIM Gateway** - API Management with diagnostic settings pre-configured
- **Container Apps** - MCP server and Trail API backends with OpenTelemetry

!!! note "Initial State"
    The deployment creates a ready-to-use observability foundation:
    
    - APIM diagnostic settings are configured (ApiManagementGatewayLogs flow immediately)
    - APIM's `function-app-url` named value points to v1 (basic logging)
    - v1 uses `logging.warning()` which writes to console, not Application Insights
    
    Both function versions are pre-deployed. The workshop scripts switch between them by updating APIM's named value—no redeployment needed!

Once deployment completes, you're ready to start the workshop.

---

## Workshop Roadmap

Camp 4 follows the **hidden → visible → actionable** pattern:

<div class="grid cards" markdown>

- :material-eye:{ .lg .middle } __APIM: Pre-Configured__

    ---

    APIM diagnostic settings are deployed via Bicep. Gateway logs flow to Log Analytics automatically. Section 1 explores and validates this configuration.

- :material-eye-off:{ .lg .middle } __Functions: Hidden__

    ---

    Security function v1 uses basic `logging.warning()`. Events occur but aren't queryable in Log Analytics. Section 2 fixes this.

- :material-bell-ring:{ .lg .middle } __Actionable__

    ---

    Create dashboards for monitoring and alerts that notify you when something needs attention. Turn visibility into automated response.

</div>

| Section | Focus | Page |
|---------|-------|------|
| **Gateway Logging** | Explore pre-configured diagnostics and validate logs flow | [Start →](section1-apim-logging.md) |
| **Function Observability** | Switch from v1 (basic) to v2 (structured logging) | [Start →](section2-function-observability.md) |
| **Dashboards & Alerts** | Make security actionable | [Start →](section3-dashboards-alerts.md) |
| **Incident Response** | Test the complete system | [Start →](section4-incident-response.md) |

Additional resources: [KQL Primer, Architecture Deep Dive, Troubleshooting →](reference.md)

---

## What You'll Learn

!!! tip "Learning Objectives"
    - **Enable** APIM diagnostic settings for gateway and AI gateway logs
    - **Implement** structured security logging in Azure Functions with correlation IDs
    - **Query** logs using KQL for security investigations with full log correlation
    - **Build** security monitoring dashboards using Azure Workbooks
    - **Create** alert rules for attack pattern detection
    - **Perform** incident response exercises with cross-service log tracing

Ready? Let's start by exploring what APIM is already logging.

[Start: Gateway Logging →](section1-apim-logging.md){ .md-button .md-button--primary }

---

← [Camp 3: I/O Security](../camp3-io-security.md) | [The Summit →](../summit.md)
