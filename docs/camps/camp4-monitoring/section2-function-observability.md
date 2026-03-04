---
hide:
  - toc
---

# Section 2: Function Observability

*Switch from basic logging to structured telemetry*

← [Gateway Logging](section1-apim-logging.md)

---

APIM logs show HTTP traffic, but the security function's internal operations (what attacks were blocked, what PII was found) are still invisible. This section upgrades from basic logging to structured telemetry.

## Two-Layer Blocking Architecture

Attacks are blocked at **two different layers**, and understanding this is key to writing correct queries:

```
                          MCP Request
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    LAYER 1: APIM Policy                             │
│                                                                     │
│    Prompt Shields (Azure Content Safety)                            │
│    • Blocks prompt injection attacks                                │
│    • Structured logging via <trace> policy                          │
│    • Logs directly to AppTraces: Properties.event_type              │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ (if not blocked)
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    LAYER 2: Security Function                       │
│                                                                     │
│    Regex-based pattern detection                                    │
│    • Blocks SQL injection, path traversal, shell injection          │
│    • Structured logging via OpenTelemetry                           │
│    • Logs to AppTraces: Properties.custom_dimensions.event_type     │
└─────────────────────────────────────────────────────────────────────┘
```

| Attack Type | Blocked By | Log Location |
|-------------|-----------|--------------|
| **Prompt injection** | Layer 1 (APIM/Prompt Shields) | `Properties.event_type` |
| **SQL injection** | Layer 2 (Security Function) | `Properties.custom_dimensions.event_type` |
| **Path traversal** | Layer 2 (Security Function) | `Properties.custom_dimensions.event_type` |
| **Shell injection** | Layer 2 (Security Function) | `Properties.custom_dimensions.event_type` |

This two-layer design means KQL queries need to check **both** property locations to capture all attack types. The unified query pattern using `coalesce()` handles this automatically.

## The Problem: Basic Logging Is Invisible

Most developers start with basic logging:

```python
logging.warning(f"Injection blocked: {category}")
```

This produces a log line like:
```
2024-01-15 14:30:00 WARNING Injection blocked: sql_injection
```

Simple, readable, and utterly useless for security analysis at scale:

- **You can't query it** — Want to count SQL injections vs. shell injections? You'd need fragile regex parsing.
- **You can't correlate it** — Which APIM request triggered this log? No correlation ID to link them.
- **You can't aggregate it** — How many attacks per hour? Per tool? Per source IP? Each question requires custom text parsing.

The solution is **structured logging**: emitting events as key-value pairs (dimensions) rather than formatted strings. You'll see this in action in step 2.2.

## 2.1 See Basic Logging Limitations

??? abstract "Experience Unstructured Logs"

    Run the script to trigger security events:

    ```bash
    ./scripts/section2/2.1-exploit.sh
    ```

    **What you'll discover:**

    The script attempts to query `AppTraces` in Log Analytics, but with v1's basic `logging.warning()` calls, the table doesn't even exist! Basic Python logging writes to stdout/console—it doesn't automatically flow to Application Insights as structured, queryable data.

    This is the core problem: **security events are happening, but they're invisible to your monitoring tools.**

    :material-close: No `AppTraces` table to query  
    :material-close: No correlation IDs linking to APIM logs  
    :material-close: No way to build dashboards or alerts  
    :material-close: Logs exist only in function console output (if you know where to look)

## 2.2 Deploy Structured Logging

??? success "Switch to v2 with Custom Dimensions"

    Switch APIM to use the pre-deployed v2 function:

    ```bash
    ./scripts/section2/2.2-fix.sh
    ```

    !!! tip "No Redeployment Required!"
        Both function versions were deployed during initial `azd up`. This script simply updates APIM's named value `function-app-url` to point to v2. The switch is instant!

    **What changes:**

    ```python
    # v1 (basic): Hard to query
    logging.warning(f"Injection blocked: {category}")

    # v2 (structured): Rich, queryable events
    log_injection_blocked(
        injection_type=result.category,
        reason=result.reason,
        correlation_id=correlation_id,
        tool_name=tool_name
    )
    ```

    **Custom dimensions now available:**

    | Dimension | Example Value | Why It Matters |
    |-----------|---------------|----------------|
    | `event_type` | `INJECTION_BLOCKED` | Filter by event category |
    | `injection_type` | `sql_injection` | Know exactly what was blocked |
    | `correlation_id` | `abc-123-xyz` | Trace across APIM + Function |
    | `tool_name` | `search-trails` | Identify targeted tools |

    !!! info "What Are Custom Dimensions?"
        When you log with Azure Monitor/Application Insights, you can attach **custom dimensions**—arbitrary key-value pairs that become queryable fields. Think of them as adding columns to your log database that you can filter, group, and aggregate. See the [Reference](reference.md#custom-dimensions) for the full list.

    !!! info "How Correlation IDs Flow Through the System"
        When a request arrives at APIM, it's assigned a unique `RequestId` (accessible via `context.RequestId` in policies). This ID appears as `CorrelationId` in APIM's gateway logs.

        For end-to-end tracing, APIM must **explicitly pass** this ID to backend services. In our security function calls, the policy includes:

        ```xml
        <set-header name="x-correlation-id" exists-action="override">
            <value>@(context.RequestId.ToString())</value>
        </set-header>
        ```

        The security function extracts this header (or generates its own if missing) and includes it in every log event.

## 2.3 Validate Structured Logs

!!! warning "Wait for Log Ingestion"
    The test attacks from 2.2-fix.sh need 2-5 minutes to appear in Log Analytics. If you run this immediately after 2.2, you may see "No structured logs found yet." Wait a few minutes and try again.

??? success "Query Security Events"

    !!! note "Layer 2 Queries"
        These queries target Layer 2 (Security Function) logs specifically. For unified queries that handle both Layer 1 (APIM/Prompt Shields) and Layer 2 logs, see the [KQL Query Reference](reference.md#kql-query-reference).

    Verify structured events appear:

    ```bash
    ./scripts/section2/2.3-validate.sh
    ```

    **Count attacks by injection type:**

    ```kusto
    AppTraces
    | where Properties has "event_type"
    | extend CustomDims = parse_json(replace_string(replace_string(
        tostring(Properties.custom_dimensions), "'", "\""), "None", "null"))
    | extend EventType = tostring(CustomDims.event_type),
             InjectionType = tostring(CustomDims.injection_type)
    | where EventType == "INJECTION_BLOCKED"
    | summarize Count=count() by InjectionType
    | order by Count desc
    ```

    **Recent security events with details:**

    ```kusto
    AppTraces
    | where Properties has "event_type"
    | extend CustomDims = parse_json(replace_string(replace_string(
        tostring(Properties.custom_dimensions), "'", "\""), "None", "null"))
    | extend EventType = tostring(CustomDims.event_type),
             InjectionType = tostring(CustomDims.injection_type),
             ToolName = tostring(CustomDims.tool_name),
             CorrelationId = tostring(CustomDims.correlation_id)
    | where EventType == "INJECTION_BLOCKED"
    | project TimeGenerated, EventType, InjectionType, ToolName, CorrelationId
    | order by TimeGenerated desc
    | limit 20
    ```

    **Most targeted tools:**

    ```kusto
    AppTraces
    | where Properties has "event_type"
    | extend CustomDims = parse_json(replace_string(replace_string(
        tostring(Properties.custom_dimensions), "'", "\""), "None", "null"))
    | where tostring(CustomDims.event_type) == "INJECTION_BLOCKED"
    | extend ToolName = tostring(CustomDims.tool_name)
    | where isnotempty(ToolName)
    | summarize AttackCount=count() by ToolName
    | order by AttackCount desc
    ```

    **End-to-end correlation (auto-finds latest correlation ID):**

    This query finds the most recent blocked attack and traces it across both APIM and Function logs:

    ```kusto
    // Get the most recent correlation ID from a blocked attack
    let timeRange = ago(24h);  // Adjust as needed
    let recentAttack = AppTraces
    | where TimeGenerated > timeRange
    | where Properties has "event_type"
    | extend CustomDims = parse_json(replace_string(replace_string(
        tostring(Properties.custom_dimensions), "'", "\""), "None", "null"))
    | where tostring(CustomDims.event_type) == "INJECTION_BLOCKED"
    | extend CorrelationId = tostring(CustomDims.correlation_id)
    | top 1 by TimeGenerated desc
    | project CorrelationId;
    // Now trace that request across APIM and Function
    let correlationId = toscalar(recentAttack);
    union
        (ApiManagementGatewayLogs 
         | where TimeGenerated > timeRange
         | where CorrelationId == correlationId
         | project TimeGenerated, Source="APIM", CorrelationId,
                   Details=strcat("HTTP ", ResponseCode, " from ", CallerIpAddress)),
        (AppTraces 
         | where TimeGenerated > timeRange
         | where Properties has "correlation_id"
         | extend CustomDims = parse_json(replace_string(replace_string(
             tostring(Properties.custom_dimensions), "'", "\""), "None", "null"))
         | where tostring(CustomDims.correlation_id) == correlationId
         | project TimeGenerated, Source="Function", CorrelationId=tostring(CustomDims.correlation_id),
                   Details=strcat(tostring(CustomDims.event_type), ": ", tostring(CustomDims.injection_type)))
    | order by TimeGenerated asc
    ```

    **Manual correlation (paste your own ID):**

    ```kusto
    let correlationId = "YOUR-CORRELATION-ID";
    union
        (ApiManagementGatewayLogs | where CorrelationId == correlationId),
        (AppTraces 
         | where Properties has "correlation_id"
         | extend CustomDims = parse_json(replace_string(replace_string(
             tostring(Properties.custom_dimensions), "'", "\""), "None", "null"))
         | where tostring(CustomDims.correlation_id) == correlationId)
    | order by TimeGenerated
    ```

---

You now have structured, queryable security events flowing to Application Insights. Time to make them *actionable* with dashboards and alerts.

[Next: Dashboards & Alerts →](section3-dashboards-alerts.md){ .md-button .md-button--primary }

---

← [Gateway Logging](section1-apim-logging.md) | [Dashboards & Alerts →](section3-dashboards-alerts.md)
