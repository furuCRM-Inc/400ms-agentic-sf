# ⚡ The 400ms Agentic Salesforce

> Goodbye, 15-second waits. This demo resolves a $50,000 VIP crisis in 400 milliseconds — no screen-scraping, no token streaming.

---

## The Problem

Every enterprise AI agent demo you've seen has the same fatal flaw: **it's slow**.

The AI reads the screen. Writes a reply. Navigates a dropdown. Waits for the next token. By the time it's "done helping," your VIP customer has already posted on LinkedIn.

---

## Two Technologies. One Flash Agent.

### 1. Jev — System 1 Reflex AI

Traditional LLMs are "System 2": deep, slow, verbose. Jev is built for "System 1": pure reflex, no text generation, structured output in milliseconds.

A critical chat lands. Jev doesn't write an essay. In **50ms** it fires:

```json
{
  "urgency": "CRITICAL",
  "recommended_action": "APPROVE_MAX_REFUND",
  "route_to": "TIER_3_RETENTION",
  "confidence": 0.97,
  "threat_value": 50000,
  "sentiment_score": -0.94
}
```

### 2. WebMCP — Direct UI Control

Normally an agent scrapes the DOM, "sees" a button, and clicks it. Brittle, slow, and fragile after every UI change.

WebMCP flips this. The Salesforce LWC **registers itself** as a callable tool directly in the browser context:

```javascript
// Inside the Salesforce Lightning Web Component
document.modelContext.registerTool({
  name: "approve_refund",
  description: "Processes instant retention refund for verified VIP complaints",
  execute: async (args) => {
    return await ApexController.approveRefund(args);
  }
});
```

The agent doesn't look at the screen. It calls the function. Directly. Securely. In **350ms**.

---

## The Demo

**Scenario:** A VIP Enterprise customer sends an angry live chat:  
*"System down. Lost $50,000. Cancel my subscription and refund me NOW!"*

| Timestamp | Event |
|---|---|
| **0ms**   | Critical chat received — Jev evaluates sentiment, dollar threat, urgency |
| **50ms**  | Jev fires structured JSON decision: `APPROVE_MAX_REFUND` |
| **250ms** | WebMCP calls `approve_refund()` — Apex processes refund |
| **350ms** | WebMCP calls `route_to_vip_retention()` — case escalated to Tier-3 |
| **400ms** | ✅ Resolved. Customer receives personalised reassurance. |

The agent handled a critical enterprise escalation before the support rep finished reading the message.

---

## Architecture

```
VIP Chat Message
      │
      ▼ (0ms)
Jev System 1 Engine          ← 50ms structured JSON decision
      │                         no token streaming
      ▼ (50ms)
AgenticChatConsole (LWC)     ← reads Jev decision
      │
      ├─ WebMCP: approve_refund()          → VipRetentionController.approveRefund()
      │                                       (Apex — real Salesforce DML)
      └─ WebMCP: route_to_vip_retention()  → VipRetentionController.routeToVipRetention()
                                              (Apex — real Salesforce case routing)
      │
      ▼ (400ms)
      ✅ Resolved
```

---

## Components

| Layer | Component | Purpose |
|---|---|---|
| LWC | `agenticChatConsole` | Full demo UI — typewriter chat, Jev panel, WebMCP tool cards, timeline |
| Apex | `VipRetentionController` | `approveRefund()`, `routeToVipRetention()`, `generateReassuranceMessage()` |
| Protocol | WebMCP `document.modelContext` | Native browser tool registration — no DOM scraping |
| AI | Jev System 1 | Structured reflex decisions — no LLM token generation |

---

## Quick Start

### 1. Deploy

```bash
sf project deploy start --source-dir force-app --target-org <alias>
```

### 2. Add the LWC to a Lightning App Page

Drag **Agentic Chat Console** onto any App Page via App Builder. Click **▶ Run Demo**.

### 3. Run Apex tests

```bash
sf apex run test --test-level RunLocalTests --target-org <alias> --result-format human --wait 10
```

| Class | Tests |
|---|---|
| `VipRetentionControllerTest` | 5 |

---

## WebMCP in Production

WebMCP is an emerging browser standard that lets UI components register themselves as callable tools. In a WebMCP-enabled browser:

1. LWC calls `document.modelContext.registerTool(...)` in `connectedCallback`
2. An AI agent (running in the browser or via extension) calls the tool by name
3. The tool executes the Apex method directly — no DOM traversal, no screenshot, no scraping

In environments without WebMCP support, the demo runs the same Apex calls via standard `@AuraEnabled` wiring — the component degrades gracefully.

---

## Related

- [dc-semantic-layer](https://github.com/furuCRM-Inc/dc-semantic-layer) — Operational semantic layer for Data Cloud: action guardrails, write-back preconditions, context-aware resolution
- [dc-agentforce-proxy](https://github.com/furuCRM-Inc/dc-agentforce-proxy) — Token compression middleware for Data Cloud + Agentforce (EN + JA)
