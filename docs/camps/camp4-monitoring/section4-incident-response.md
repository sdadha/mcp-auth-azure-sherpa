---
hide:
  - toc
---

# Section 4: Incident Response

*Test the complete observability system*

← [Dashboards & Alerts](section3-dashboards-alerts.md)

---

## Why Practice Incident Response?

Building a monitoring system is one thing. Actually using it under pressure is another.

Security teams practice incident response for the same reason firefighters practice drills: when the real thing happens, you don't want to be figuring things out for the first time.

In this section, you'll:

1. **Simulate a realistic attack** - Multiple attack vectors, realistic payloads
2. **Watch your dashboard light up** - See the "actionable" part in action
3. **Investigate using correlation IDs** - Trace the attack across services
4. **Verify alerts trigger** - Confirm your automated notifications work

## The Power of Correlation IDs

When investigating an incident, the most valuable tool is the **correlation ID**. Here's why:

A single user action might touch multiple services:
```
Client Request → APIM → Security Function → MCP Server → Database
```

Each service logs independently. Without correlation, you'd have:

- APIM log: "Request from 203.0.113.42"
- Function log: "Injection blocked: sql_injection"  
- MCP Server log: "Request failed"

Which function log matches which APIM request? 🤷

With correlation IDs, every service logs the same ID:
```
APIM:     correlation_id=abc-123, CallerIP=203.0.113.42
Function: correlation_id=abc-123, event_type=INJECTION_BLOCKED  
MCP:      correlation_id=abc-123, status=blocked
```

Now you can instantly reconstruct the full story:

```kusto
let id = "abc-123";
ApiManagementGatewayLogs | where CorrelationId == id
| union (
    AppTraces 
    | where Properties has "correlation_id"
    | extend CustomDims = parse_json(replace_string(replace_string(
        tostring(Properties.custom_dimensions), "'", "\""), "None", "null"))
    | where tostring(CustomDims.correlation_id) == id
)
| order by TimeGenerated
```

## 4.1 Simulate Multi-Vector Attack

??? warning "Attack Simulation"

    Run the attack simulation:

    ```bash
    ./scripts/section4/4.1-simulate-attack.sh
    ```

    **Attack phases:**

    1. **Reconnaissance** - Probe for available tools
    2. **SQL Injection** - Multiple payload variations
    3. **Path Traversal** - Try to access system files
    4. **Shell Injection** - Command execution attempts
    5. **Prompt Injection** - AI jailbreak attempts

    **What to observe:**

    - Dashboard shows spike in attack volume
    - "High Attack Volume" alert triggers
    - Email notification (if configured)

    **Full log correlation query:**

    The script outputs a correlation ID. Use it to trace the attack across ALL services:

    ```kusto
    // Correlate attack across APIM and Function logs
    let timeRange = ago(1h);
    AppTraces
    | where TimeGenerated > timeRange
    | where Properties has "event_type"
    | extend CustomDims = parse_json(replace_string(replace_string(
        tostring(Properties.custom_dimensions), "'", "\""), "None", "null"))
    | extend CorrelationId = tostring(CustomDims.correlation_id)
    | join kind=leftouter (
        ApiManagementGatewayLogs
        | where TimeGenerated > timeRange
        | where ApiId contains "mcp" or ApiId contains "sherpa"
        | project CorrelationId, CallerIpAddress, ResponseCode
    ) on CorrelationId
    | project TimeGenerated, CorrelationId, 
        EventType=tostring(CustomDims.event_type),
        InjectionType=tostring(CustomDims.injection_type),
        CallerIpAddress, ResponseCode
    | order by TimeGenerated desc
    | take 50
    ```

---

## Cleanup

```bash
# Remove all Azure resources
azd down --force --purge

# Clean up Entra ID apps (optional - ignore errors if already deleted)
az ad app delete --id $(azd env get-value MCP_APP_CLIENT_ID)
az ad app delete --id $(azd env get-value APIM_CLIENT_APP_ID)
```

---

## Congratulations!

You've completed Camp 4: Monitoring & Telemetry and reached **Observation Peak**! One more climb to go. The Summit awaits!

### Your Journey: Hidden → Visible → Actionable

Think back to where you started:

| Before | After |
|--------|-------|
| APIM routed traffic silently | Every request logged with caller IP, timing, correlation |
| No AI-based attack detection | Layer 1 (Prompt Shields) blocks prompt injection at the edge |
| Function logged basic warnings | Layer 2 structured events for SQL/path/shell with custom dimensions |
| No way to see attack patterns | Real-time dashboard showing all attack categories |
| Manual log checking | Automated alerts notify you of threats |

You've transformed your MCP infrastructure from a "black box" into a fully observable system.

### What You've Accomplished

:material-check: **Enabled APIM diagnostics** with GatewayLogs, GatewayLlmLogs, and WebSocketConnectionLogs  
:material-check: **Implemented structured logging** with correlation IDs and custom dimensions  
:material-check: **Built a security dashboard** using Azure Workbooks  
:material-check: **Configured alert rules** for attack detection  
:material-check: **Learned KQL** for security investigations  
:material-check: **Practiced incident response** with cross-service log correlation

### The Hidden → Visible → Actionable Pattern

This pattern applies beyond just monitoring:

- **Hidden problems** → Use diagnostics, logging, tracing to make them **visible**
- **Visible data** → Use dashboards, alerts, automation to make it **actionable**

Whenever you deploy something new, ask yourself: "If this breaks at 3 AM, how will I know? How will I investigate?"

### Skills You've Gained

| Skill | What You Can Now Do |
|-------|---------------------|
| **Azure Monitor** | Configure diagnostic settings, use Log Analytics |
| **KQL** | Write queries to investigate security events |
| **Structured Logging** | Design log events that are queryable at scale |
| **Dashboarding** | Build Workbooks for security visualization |
| **Alerting** | Create rules that notify on security thresholds |
| **Incident Response** | Trace requests across services using correlation IDs |

---

## Almost at the Summit!

You've completed all four skill-building camps:

| Camp | What You Secured |
|------|------------------|
| **Base Camp** | Understanding MCP vulnerabilities |
| **Camp 1: Identity** | OAuth 2.0 + Entra ID authentication |
| **Camp 2: Gateway** | APIM protection + rate limiting |
| **Camp 3: I/O Security** | Input validation + output sanitization |
| **Camp 4: Monitoring** | Full observability + alerting |

Your MCP servers are now **authenticated**, **protected**, **validated**, and **observable**.

!!! tip "What's Next: The Summit"
    You've learned all the individual security skills. Now it's time to put them all together!
    
    The **Summit** is where you'll deploy the complete secure MCP infrastructure and test it with realistic red team / blue team exercises.

**One more climb to go!**

---

← [Dashboards & Alerts](section3-dashboards-alerts.md) | [The Summit →](../summit.md)
