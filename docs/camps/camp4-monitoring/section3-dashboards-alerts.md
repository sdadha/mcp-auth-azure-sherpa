---
hide:
  - toc
---

# Section 3: Dashboards & Alerts

*Make security actionable*

← [Function Observability](section2-function-observability.md)

---

Visibility is great, but you can't watch logs 24/7. This section makes security *actionable* with dashboards and alerts.

## From Visible to Actionable

At this point, you've achieved visibility:

:material-check: APIM logs flow to Log Analytics  
:material-check: Security function emits structured events  
:material-check: You can query anything with KQL

But there's a problem: **nobody has time to run KQL queries all day**.

The final step in the "hidden → visible → actionable" journey is making security events *surface themselves*:

- **Dashboards** give you at-a-glance status without running queries
- **Alerts** notify you when something needs attention, even at 3 AM

## Azure Workbooks: Interactive Dashboards

**Azure Workbooks** are interactive reports built on top of Log Analytics. They combine:

- **Text** - Explanations and context
- **KQL Queries** - Live data from your logs
- **Visualizations** - Charts, graphs, grids
- **Parameters** - Interactive filters (time range, environment, etc.)

Unlike static dashboards, Workbooks query live data every time you view them. No ETL pipelines, no data staleness—just direct queries against your logs.

!!! tip "Workbook vs. Dashboard"
    Azure has both **Workbooks** and **Dashboards**. What's the difference?
    
    - **Workbooks**: Rich, document-like reports with interactivity. Best for analysis.
    - **Dashboards**: Pinned tiles from various sources. Best for at-a-glance monitoring.
    
    For security monitoring, Workbooks are usually the better choice because you need the analytical depth.

## Azure Monitor Alerts: Automated Notification

Alerts watch your logs and take action when conditions are met. They have three components:

1. **Condition**: A KQL query that returns results when something's wrong
2. **Action Group**: Who to notify and how (email, SMS, webhook, Logic App)
3. **Severity**: How urgent is this? (0-4, where 0 is critical)

For example, our "High Attack Volume" alert:

- **Condition**: More than 10 `INJECTION_BLOCKED` events in 5 minutes
- **Action**: Email the security team
- **Severity**: 2 (Warning)

Alerts run on a schedule (every 5 minutes by default) and fire when the query returns results.

## 3.1 Deploy the Dashboard

??? abstract "Create Security Workbook"

    Deploy the Azure Monitor Workbook:

    ```bash
    ./scripts/section3/3.1-deploy-workbook.sh
    ```

    **Access the dashboard:**

    1. Open the [Azure Portal](https://portal.azure.com)
    2. Navigate to your **Log Analytics workspace** (`log-camp4-xxxxx`)
    3. Click **Workbooks** in the left menu
    4. Select **MCP Security Dashboard** from the list

    !!! tip "If the dashboard appears empty"
        Do a hard refresh (`Cmd+Shift+R` or `Ctrl+Shift+R`) to reload the portal UI. The visualization components sometimes fail to load on first access.

    **Dashboard panels:**

    | Panel | Shows |
    |-------|-------|
    | Request Volume | MCP traffic over 24h |
    | Attacks by Type | Pie chart of injection categories |
    | Top Targeted Tools | Which MCP tools attackers probe |
    | Error Sources | IPs generating errors |
    | Recent Events | Live feed of security activity |

## 3.2 Create Alert Rules

Dashboards are great when you're looking at them. But security incidents don't wait for business hours. Alert rules watch your logs continuously and notify you when something needs attention.

### Understanding Action Groups

Before creating alerts, you need to understand **Action Groups**, which are Azure's way of defining *who* gets notified and *how*.

Think of an Action Group as your incident response contact list:

```
Action Group: "mcp-security-alerts"
├── Email: security-team@company.com
├── SMS: +1-867-5309 (on-call engineer)
├── Webhook: https://notify.company.com/alerts
└── Azure Function: auto-remediation-function
```

When an alert fires, it triggers everyone in the Action Group simultaneously.

!!! tip "Start Simple"
    For this workshop, we'll create an Action Group with just email notifications (or none at all). In production, you'd add SMS for critical alerts, webhooks for Slack/Teams, or even Azure Functions for automated remediation.

### Anatomy of an Alert Rule

An alert rule has three parts:

| Component | What It Does | Example |
|-----------|--------------|---------|
| **Condition** | KQL query that returns results when something's wrong | "More than 10 injection attacks in 5 minutes" |
| **Action Group** | Who to notify when condition is met | Email the security team |
| **Severity** | How urgent is this? (0-4) | 2 = Warning |

The alert service runs your KQL query on a schedule (every 5 minutes by default). If the query returns results, the alert "fires" and notifies your Action Group.

### Severity Levels Explained

| Severity | Name | When to Use | Example |
|----------|------|-------------|---------|
| 0 | Critical | Production down, data breach | Credential exposure detected |
| 1 | Error | Service degraded, security incident | Sustained attack volume |
| 2 | Warning | Needs attention soon | Spike in blocked attacks |
| 3 | Informational | For awareness | New attack pattern seen |
| 4 | Verbose | Debugging only | Rarely used for alerts |

!!! warning "Alert Fatigue is Real"
    The biggest mistake teams make is setting thresholds too low. If you get 50 alerts a day, you'll start ignoring them, and miss the real incidents. Start with conservative thresholds (fewer alerts) and tune down as you learn your baseline.

### The Alerts We're Creating

| Alert | Why This Matters |
|-------|------------------|
| **High Attack Volume** | A sudden spike in blocked attacks often indicates an active attack campaign. One or two blocked injections? Normal probing. Dozens in minutes? Someone's serious. |
| **Credential Exposure** | Any credential detection is critical, even if redacted, it means sensitive data reached your system. This should wake someone up at 3 AM. |

??? success "Set Up Automated Notifications"

    Create alert rules:

    ```bash
    ./scripts/section3/3.2-create-alerts.sh
    ```

    The script will prompt for an optional email address. You can skip this and view fired alerts in the Azure Portal instead.

    **What the script creates:**

    1. **Action Group** (`mcp-security-alerts`)
        - Short name: `MCPSecAlrt` (used in SMS notifications)
        - Email receiver (if you provided one)

    2. **Alert: High Attack Volume** (Severity 2 - Warning)
        - Triggers when >10 attacks detected in 5 minutes
        - Evaluation frequency: Every 5 minutes
        - Use case: Detect active attack campaigns

    3. **Alert: Credential Exposure** (Severity 1 - Error)
        - Triggers on ANY credential detection
        - Evaluation frequency: Every 5 minutes
        - Use case: Critical security event requiring immediate attention

    **Verify in Azure Portal:**

    1. Navigate to **Monitor** → **Alerts**
    2. Click **Alert rules** to see your configured rules
    3. After an attack simulation, check **Alerts** for fired alerts

    !!! tip "Testing Alerts"
        Alerts evaluate every 5 minutes, so there's a delay between generating events and seeing alerts fire. After running the attack simulation in Section 4, wait 5-10 minutes before checking for fired alerts.

---

Dashboards and alerts are live. Time to put the whole system to the test.

[Next: Incident Response →](section4-incident-response.md){ .md-button .md-button--primary }

---

← [Function Observability](section2-function-observability.md) | [Incident Response →](section4-incident-response.md)
