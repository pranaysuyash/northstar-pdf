# Session Context

- Generated: 2026-08-25T08:31:13Z
- Project: `pdf_editor`
- Provider: `local`
- Model: `BAAI/bge-m3`
- Project collection: `projects_proj_pdf_editor`
- Shared collection: `projects_workspace_shared`

## Doctrine Family

- Canonical root: `/Users/pranay/Projects/agent-start/doctrines`
- Operating doctrine: `OPERATING_DOCTRINE.md` v8.0 (sha256 `93dc8e76f2c26489…`) — always applies
- Project: `pdf_editor`
- Routing mechanism: agent-start doctrine-family router v1.0 (deterministic intent-signal model)
- Generated at: 2026-08-25T08:31:13Z
- Generator: agent-start lib/doctrine_family.py

Doctrine routing for this run (task intent not supplied; deferred):

| Doctrine | Version | Status | Reason |
|---|---:|---|---|
| Operating | 8.0 | selected | always active: cross-cutting control plane |
| Review | 1.1 | unknown | task intent not supplied at generation time; defer to Operating Doctrine section 16 routing |
| Exploration | 1.1 | unknown | task intent not supplied at generation time; defer to Operating Doctrine section 16 routing |
| Research | 1.0 | unknown | task intent not supplied at generation time; defer to Operating Doctrine section 16 routing |
| Architecture | 1.0 | unknown | task intent not supplied at generation time; defer to Operating Doctrine section 16 routing |
| Testing | 1.1 | unknown | task intent not supplied at generation time; defer to Operating Doctrine section 16 routing |
| Security / Privacy / Safety | 1.0 | unknown | task intent not supplied at generation time; defer to Operating Doctrine section 16 routing |
| Release Readiness | 1.0 | unknown | task intent not supplied at generation time; defer to Operating Doctrine section 16 routing |
| Documentation | 1.1 | unknown | task intent not supplied at generation time; defer to Operating Doctrine section 16 routing |

No specialist doctrine was selected for this run. The Operating Doctrine routing table (section 16) governs if the task's mode changes; canonical specialist doctrines live at the root above.

## Project Doctrine Sync

- File: `/Users/pranay/Projects/pdf_editor/OPERATING_DOCTRINE.md`
- Sync status: `synced from /Users/pranay/Projects/agent-start/doctrines/OPERATING_DOCTRINE.md; legacy filenames archived or removed`
- Guidance: read the operating doctrine before implementation or review on this project.

## Project-Focused Retrieval

### Architecture Decisions
- Collection: `projects_proj_pdf_editor`
- Query: `architecture decisions for pdf_editor`
_Fast mode (--skip-index): retrieval skipped to keep startup non-blocking. Run `/Users/pranay/Projects/agent-start --project pdf_editor` for full retrieval, or set `AGENT_START_SKIP_INDEX_RETRIEVE=1` if you want retrieval with skip-index._

### Project Management Workflow
- Collection: `projects_proj_pdf_editor`
- Query: `project management workflow for pdf_editor`
_Fast mode (--skip-index): retrieval skipped to keep startup non-blocking. Run `/Users/pranay/Projects/agent-start --project pdf_editor` for full retrieval, or set `AGENT_START_SKIP_INDEX_RETRIEVE=1` if you want retrieval with skip-index._

### Known Issues and Worklogs
- Collection: `projects_proj_pdf_editor`
- Query: `known issues and worklog for pdf_editor`
_Fast mode (--skip-index): retrieval skipped to keep startup non-blocking. Run `/Users/pranay/Projects/agent-start --project pdf_editor` for full retrieval, or set `AGENT_START_SKIP_INDEX_RETRIEVE=1` if you want retrieval with skip-index._

### Prompts and Guidelines
- Collection: `projects_proj_pdf_editor`
- Query: `prompts and guidelines for pdf_editor`
_Fast mode (--skip-index): retrieval skipped to keep startup non-blocking. Run `/Users/pranay/Projects/agent-start --project pdf_editor` for full retrieval, or set `AGENT_START_SKIP_INDEX_RETRIEVE=1` if you want retrieval with skip-index._

### System Learning Graph
- Collection: `projects_proj_pdf_editor`
- Query: `knowledge graph memory learning feedback loops autoresearch semantic taste graph for pdf_editor`
_Fast mode (--skip-index): retrieval skipped to keep startup non-blocking. Run `/Users/pranay/Projects/agent-start --project pdf_editor` for full retrieval, or set `AGENT_START_SKIP_INDEX_RETRIEVE=1` if you want retrieval with skip-index._

## Shared Cross-Project Retrieval

### Reusable Patterns
- Collection: `projects_workspace_shared`
- Query: `similar architecture patterns for pdf_editor`
_Fast mode (--skip-index): retrieval skipped to keep startup non-blocking. Run `/Users/pranay/Projects/agent-start --project pdf_editor` for full retrieval, or set `AGENT_START_SKIP_INDEX_RETRIEVE=1` if you want retrieval with skip-index._

### Process Templates
- Collection: `projects_workspace_shared`
- Query: `project management templates and workflows`
_Fast mode (--skip-index): retrieval skipped to keep startup non-blocking. Run `/Users/pranay/Projects/agent-start --project pdf_editor` for full retrieval, or set `AGENT_START_SKIP_INDEX_RETRIEVE=1` if you want retrieval with skip-index._

### Common Failure Modes
- Collection: `projects_workspace_shared`
- Query: `lessons learned mistakes retrospectives postmortems`
_Fast mode (--skip-index): retrieval skipped to keep startup non-blocking. Run `/Users/pranay/Projects/agent-start --project pdf_editor` for full retrieval, or set `AGENT_START_SKIP_INDEX_RETRIEVE=1` if you want retrieval with skip-index._

### System Learning Graph
- Collection: `projects_workspace_shared`
- Query: `knowledge graph memory learning feedback loops autoresearch semantic taste graph`
_Fast mode (--skip-index): retrieval skipped to keep startup non-blocking. Run `/Users/pranay/Projects/agent-start --project pdf_editor` for full retrieval, or set `AGENT_START_SKIP_INDEX_RETRIEVE=1` if you want retrieval with skip-index._


---
## Agent Collaboration Style

Pranay expects the agent to act as a genuine technical collaborator, not an instruction executor:
- Have and express opinions on design, naming, logic, test quality
- Push back when something is wrong - don't just flag it, fix it with a rationale
- Catch bugs proactively without waiting to be asked
- Discuss tradeoffs directly: here is why X is wrong and Y is better
- The goal is two engineers reviewing each other's work, not a contractor following a spec

This applies to code review, test quality, naming, architecture boundaries, commit grouping strategy, and anything that would affect the project long-term.
