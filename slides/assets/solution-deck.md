---
marp: true
theme: default
paginate: true
size: 16:9
style: |
  section {
    font-family: 'Helvetica', 'Arial', sans-serif;
    background: #FFFFFF;
    color: #1F2937;
    font-size: 26px;
    padding: 60px 70px;
  }
  h1 {
    color: #4F46E5;
    font-size: 46px;
  }
  h2 {
    color: #059669;
    font-size: 34px;
  }
  strong { color: #4F46E5; }
  table { font-size: 24px; }
  th { background: #4F46E5; color: white; }
  tr:nth-child(even) { background: #F3F4F6; }
  ol { font-size: 28px; line-height: 1.7; }
  section.lead {
    background: linear-gradient(135deg, #4F46E5 0%, #059669 100%);
    color: white;
    text-align: center;
    justify-content: center;
  }
  section.lead h1 { color: white; font-size: 52px; }
  section.lead h3 { color: #E0E7FF; font-weight: normal; }
  img { background: transparent; }
  footer { color: #9CA3AF; font-size: 16px; }
---

<!-- _class: lead -->

# Securely Connecting Amazon Quick to Internal Systems

### Private MCP Connection — bringing AI inside the enterprise security perimeter

*The AI assistant uses sensitive data, yet the data never leaves the private network.*

---

## Agenda

1. **Context** — Amazon Quick and the MCP connector
2. **The Problem** — why we can't expose internal data
3. **The Solution** — Private MCP Connection
4. **How It Works** — the request flow
5. **Use Case** — incident investigation
6. **Business Value** — what we gain
7. **Layered Security** — network + identity
8. **Why This Approach** — vs. alternatives
9. **Summary & Next Steps**

---

## Context

**Amazon Quick** is an enterprise AI assistant: search data, build agents, automate workflows.

Quick connects to external systems through the **MCP connector**.

But many critical systems live **inside a private network**:

- Internal databases
- Monitoring / logging systems
- Custom operational tools

> **How can AI use this data without exposing it to the Internet?**

---

## The Problem

![w:1000 center](problem.png)

Opening a public endpoint for the AI to call introduces:

- Sensitive data traveling over public paths
- A larger attack surface
- Difficulty meeting data-security compliance

---

## The Solution: Private MCP Connection

![w:1050 center](solution.png)

**Two core principles:**

- **Public certificate** → connection is properly encrypted (valid TLS)
- **Private hostname** → only visible inside the internal network

→ AI can use the data; the data **never leaves**.

---

## How It Works

![w:680 center](flow.png)

The entire flow stays **inside the private network** — no hop touches the public Internet.

---

## Use Case: Incident Investigation

**Scenario:** A customer reports *"I got a 500 error at checkout."*

| Before | With this solution |
|--------|---------------------|
| Engineers dig through many logs | Ask Quick in plain language |
| Time-consuming | Quick calls MCP inside the private net |
| Easy to miss things | Root cause found automatically |

> Result: *"The payment service timed out calling the bank API"* — in seconds.

---

## Business Value

| Aspect | Benefit |
|--------|---------|
| **Security** | Data never leaves the network; no public endpoint |
| **Compliance** | Meets sensitive-data isolation requirements |
| **Speed** | Natural-language incident response, instantly |
| **Simplicity** | Standard networking the team already knows |
| **Cost** | Fewer moving parts, no extra data-processing fees |

---

## Layered Security

![w:760 center](layers.png)

Network isolation is the **always-on** foundation; identity (OAuth) is an **optional** layer when needed.

---

## Why This Approach

Compared with going through a managed gateway service:

- **Fewer components** → easier to operate, fewer failure points
- **No public ingress** → better security by default
- **Amazon Quick's first-class path** → stable and supported
- **Flexible authentication** → run with no auth (network isolation) or enable OAuth

---

<!-- _class: lead -->

# Summary

### More useful AI — it works with real data
### Safer data — it never reaches the Internet
### Simpler operations — standard networking

**AI meets data, securely.**
