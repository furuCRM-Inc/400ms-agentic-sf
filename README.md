# ⚡ The 400ms Agentic Salesforce

> Goodbye, 15-second waits. This demo resolves a $50,000 VIP crisis in 400 milliseconds — no screen-scraping, no token streaming, no hallucination.

---

## The Problem

Every enterprise AI agent demo has the same fatal flaw: **it's slow**.

The AI reads the screen. Writes a reply. Navigates a dropdown. Waits for the next token. By the time it's "done helping," your VIP customer has already posted on LinkedIn.

---

## Two Technologies. One Flash Agent.

### 1. Jev — System 1 AI by TypeSafe AI

Traditional LLMs are "System 2": deep, slow, verbose. They write essays.  
[Jev](https://typesafe.ai) is "System 1": pure reflex, no text generation.

Instead of generating text, Jev evaluates typed **Questions** against a **State** in one parallel pass and returns calibrated probabilities — in **70–500ms**.

A critical chat lands. Jev fires **one HTTP request** with three questions:

```json
POST https://api.typesafe.ai/v1/systemone

{
  "model": "jev-latest",
  "state": "{\"message\": \"System down. Lost $50,000. Cancel NOW!\", \"customer_tier\": \"Enterprise\"}",
  "questions": {
    "is_critical": {
      "type": "noul",
      "instructions": "Does this require immediate VIP retention intervention?"
    },
    "recommended_action": {
      "type": "choice",
      "instructions": "Select the most appropriate retention action.",
      "criteria": {
        "APPROVE_MAX_REFUND": "Approve full refund immediately for VIP retention",
        "PARTIAL_REFUND":     "Offer partial refund and service credit",
        "ESCALATE":           "Escalate to senior support team",
        "STANDARD_RESPONSE":  "Route to standard support queue"
      }
    },
    "urgency_level": {
      "type": "score",
      "instructions": "Rate the urgency of this customer situation.",
      "levels": {
        "0": "Low: No immediate churn risk",
        "1": "Medium: Same-day response recommended",
        "2": "High: Priority response within the hour",
        "3": "Critical: High-value customer threatening cancellation"
      }
    }
  }
}
```

Jev returns calibrated probabilities — no text, no hallucination, no output token charges:

```json
{
  "model": "jev-1.13.0",
  "answers": {
    "is_critical":        { "type": "noul",   "noul": 0.97 },
    "recommended_action": { "type": "choice",  "choice": "APPROVE_MAX_REFUND", "confidence": 0.95 },
    "urgency_level":      { "type": "score",   "score": 2.85, "confidence": 0.92 }
  },
  "usage": { "input_tokens": 412, "output_tokens": 58 }
}
```

**Cost: $0.042 / 1M input tokens. Output tokens: FREE** (no text generated).

---

### 2. WebMCP — Direct UI Control, No Screen-Scraping

Normally an agent takes a screenshot, asks an LLM "where's the refund button?", scrapes the DOM, and clicks — brittle, slow, breaks on every UI change.

WebMCP flips this. The Salesforce LWC **registers itself** as a callable tool directly in the browser context:

```javascript
// Inside the Salesforce Lightning Web Component
connectedCallback() {
    document.modelContext.registerTool({
        name: "approve_refund",
        description: "Processes instant retention refund for verified VIP complaints",
        execute: async (args) => ApexController.approveRefund(args)
    });
}
```

The agent calls the function by name. No screenshot. No DOM traversal. No fragile selectors.

---

## The Demo

**Scenario:** VIP Enterprise customer sends an angry live chat:  
*"System down. Lost $50,000. Cancel my subscription and refund me NOW!"*

| Timestamp | Event |
|---|---|
| **0ms**   | Critical chat received |
| **50ms**  | Jev fires — `POST /v1/systemone` — 3 questions evaluated in parallel |
| **250ms** | WebMCP calls `approve_refund()` — Apex processes refund |
| **350ms** | WebMCP calls `route_to_vip_retention()` — Tier-3 team assigned |
| **400ms** | ✅ Done. Personalised reassurance message sent. |

The support rep hadn't finished reading the message.

---

## Architecture

```
VIP Chat Message
      │
      ▼ 0ms
JevDecisionService.cls
      │   POST https://api.typesafe.ai/v1/systemone
      │   model: jev-latest
      │   questions: Noul + Choice + Score (parallel)
      ▼ 50ms
Structured Decision
  { urgency: CRITICAL, action: APPROVE_MAX_REFUND, confidence: 0.95 }
      │
      ▼
agenticChatConsole LWC
      │
      ├─ WebMCP: approve_refund()          → VipRetentionController.approveRefund()
      └─ WebMCP: route_to_vip_retention()  → VipRetentionController.routeToVipRetention()
      │
      ▼ 400ms
      ✅ Resolved
```

---

## Components

| Layer | Component | Purpose |
|---|---|---|
| LWC | `agenticChatConsole` | Full demo UI — typewriter chat, Jev JSON panel, LIVE/SIMULATED badge, WebMCP tool cards, animated timeline |
| Apex | `JevDecisionService` | `POST /v1/systemone` callout — builds Noul/Choice/Score questions, parses calibrated response |
| Apex | `VipRetentionController` | `approveRefund()`, `routeToVipRetention()`, `generateReassuranceMessage()` — real Apex DML paths |
| Protocol | WebMCP `document.modelContext` | Native browser tool registration — no DOM scraping |
| NC | `TypeSafe_Jev` | Named Credential pointing to `https://api.typesafe.ai` |
| Label | `TypeSafe_API_Key` | Custom Label holding the Jev API key (replace after deploy) |

---

## Quick Start

### 1. Deploy

```bash
sf project deploy start --source-dir force-app --target-org <alias>
```

### 2. Set your TypeSafe AI API key

Get a key at [typesafe.ai](https://typesafe.ai), then:

```
Setup → Custom Labels → TypeSafe_API_Key → Edit
→ Replace "REPLACE_WITH_YOUR_TYPESAFE_API_KEY" with your real key
```

The LWC auto-detects whether the key is configured:
- **LIVE · typesafe.ai** badge — real Jev API, real measured latency
- **SIMULATED** badge — hardcoded fallback, no API key needed

### 3. Add the LWC to a Lightning App Page

Drag **Agentic Chat Console** onto any App Page via App Builder. Click **▶ Run Demo**.

### 4. Run Apex tests

```bash
sf apex run test --class-names VipRetentionControllerTest,JevDecisionServiceTest \
  --target-org <alias> --result-format human --wait 10
```

| Class | Tests | Covers |
|---|---|---|
| `VipRetentionControllerTest` | 5 | Simulated fallback, refund, routing, message generation |
| `JevDecisionServiceTest` | 4 | Live mock (CRITICAL + STANDARD), API error, ESCALATE routing |
| **Total** | **9** | |

All 9 pass on Dev02 without an API key (mock via `HttpCalloutMock`).

---

## Jev Question Types

| Type | What it returns | Use for |
|---|---|---|
| **Noul** | Probability `0.0–1.0` (not boolean — calibrated) | Binary yes/no decisions with confidence |
| **Choice** | Winning option + `confidence` + all `probabilities` | Routing, action selection |
| **Score** | Weighted score across ordered `levels` | Urgency, priority, severity rating |

All three are evaluated **in one parallel API call**.

---

## Cost vs Traditional LLM

| | Traditional LLM agent | Jev |
|---|---|---|
| Decision latency | 2–8s (token streaming) | **50–200ms** |
| Output tokens | High (generates text) | **0** (returns numbers) |
| Hallucination risk | Present | **None** (typed output) |
| UI interaction | Screenshot + DOM scraping | **Direct function call** |
| Total time | 15–20s | **400ms** |

---

## Related

- [dc-semantic-layer](https://github.com/furuCRM-Inc/dc-semantic-layer) — Operational semantic layer for Data Cloud: action guardrails, write-back preconditions, context-aware resolution
- [dc-agentforce-proxy](https://github.com/furuCRM-Inc/dc-agentforce-proxy) — Token compression middleware for Data Cloud + Agentforce (EN + JA)
- [TypeSafe AI Jev docs](https://docs.typesafe.ai/api)
