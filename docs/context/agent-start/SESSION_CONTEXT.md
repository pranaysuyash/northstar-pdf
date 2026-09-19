# Session Context

- Generated: 2026-09-19T03:36:01Z
- Project: `pdf_editor`
- Provider: `local`
- Model: `BAAI/bge-m3`
- Project collection: `projects_proj_pdf_editor`
- Shared collection: `projects_workspace_shared`

## Doctrine Family

- Canonical root: `/Users/pranay/Projects/agent-start/doctrines`
- Operating doctrine: `OPERATING_DOCTRINE.md` v8.1 (sha256 `c22b129bf41942d0…`) — always applies
- Project: `pdf_editor`
- Routing mechanism: agent-start doctrine-family router v1.1 (deterministic intent-signal model)
- Generated at: 2026-09-19T03:36:02Z
- Generator: agent-start lib/doctrine_family.py

Doctrine routing for this run (task intent not supplied; deferred):

| Doctrine | Version | Status | Reason |
|---|---:|---|---|
| Operating | 8.1 | selected | always active: cross-cutting control plane |
| Review | 1.2 | unknown | task intent not supplied at generation time; defer to Operating Doctrine section 16 routing |
| Exploration | 1.1 | unknown | task intent not supplied at generation time; defer to Operating Doctrine section 16 routing |
| Research | 1.0 | unknown | task intent not supplied at generation time; defer to Operating Doctrine section 16 routing |
| Architecture | 1.1 | unknown | task intent not supplied at generation time; defer to Operating Doctrine section 16 routing |
| Testing | 1.1 | unknown | task intent not supplied at generation time; defer to Operating Doctrine section 16 routing |
| Security / Privacy / Safety | 1.0 | unknown | task intent not supplied at generation time; defer to Operating Doctrine section 16 routing |
| Release Readiness | 1.0 | unknown | task intent not supplied at generation time; defer to Operating Doctrine section 16 routing |
| Documentation | 1.1 | unknown | task intent not supplied at generation time; defer to Operating Doctrine section 16 routing |
| Inquiry and Analysis | 1.0 | unknown | task intent not supplied at generation time; defer to Operating Doctrine section 16 routing |

No specialist doctrine was selected for this run. The Operating Doctrine routing table (section 16) governs if the task's mode changes; canonical specialist doctrines live at the root above.

## Project Doctrine Sync

- File: `/Users/pranay/Projects/pdf_editor/OPERATING_DOCTRINE.md`
- Sync status: `synced from /Users/pranay/Projects/agent-start/doctrines/OPERATING_DOCTRINE.md; legacy filenames archived or removed`
- Guidance: read the operating doctrine before implementation or review on this project.

## Project-Focused Retrieval

> NOTE: Project collection is temporarily locked by another index/search process; using shared workspace context for this run.

## Shared Cross-Project Retrieval

### Reusable Patterns
- Collection: `projects_workspace_shared`
- Query: `similar architecture patterns for pdf_editor`
_Collection check timed out. Retry shortly._

### Process Templates
- Collection: `projects_workspace_shared`
- Query: `project management templates and workflows`
_Collection check timed out. Retry shortly._

### Common Failure Modes
- Collection: `projects_workspace_shared`
- Query: `lessons learned mistakes retrospectives postmortems`
_Collection check timed out. Retry shortly._

### System Learning Graph
- Collection: `projects_workspace_shared`
- Query: `knowledge graph memory learning feedback loops autoresearch semantic taste graph`
_Collection check timed out. Retry shortly._


---
## Agent Collaboration Style

Pranay expects the agent to act as a genuine technical collaborator, not an instruction executor:
- Have and express opinions on design, naming, logic, test quality
- Push back when something is wrong - don't just flag it, fix it with a rationale
- Catch bugs proactively without waiting to be asked
- Discuss tradeoffs directly: here is why X is wrong and Y is better
- The goal is two engineers reviewing each other's work, not a contractor following a spec

This applies to code review, test quality, naming, architecture boundaries, commit grouping strategy, and anything that would affect the project long-term.
