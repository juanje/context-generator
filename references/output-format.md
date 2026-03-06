# Output Format Specification

Read this file before writing any context file output. It defines the exact format,
quality criteria, and provides good vs bad examples for each section.

## The Inclusion Test

Before writing any line, ask: **"If an LLM reviewer doesn't know this, will it produce
a wrong or misleading review comment?"**

- If yes → include it
- If no → cut it

This test is the single most important quality criterion. Apply it ruthlessly.

## What to Include vs Exclude

**Include (directly prevents review errors):**
- Current versions of dependencies, models, images, tools
- How changed code connects to the rest of the system
- What's internal/proprietary and how it works
- Patterns that look wrong but are intentional
- Configuration rules the LLM will violate without context

**Exclude (doesn't prevent review errors):**
- Generic best practices the LLM already knows
- Detailed explanations of well-known libraries
- History of changes or changelogs
- Setup instructions, onboarding info, deployment guides
- Anything the LLM can infer from the diff itself
- Descriptions of what common tools do (everyone knows what pytest does)

---

## Project Scope — Section Templates

### Section 1: Project Overview

**Size target:** 3-5 lines. **Problem addressed:** Diff-only visibility.

```markdown
## Project Overview

**Purpose:** [One specific sentence that distinguishes this from similar projects]
**Type:** [CLI tool | Web service | Library | API | Mobile app | IaC | etc.]
**Domain:** [Business domain]
**Key Dependencies:** `dep1` (role), `dep2` (role), `dep3` (role)
```

BAD:
> **Purpose:** A web application for managing data and providing user interfaces
> for various business operations across the organization.

GOOD:
> **Purpose:** AI-powered CLI tool that reviews Git diffs via LLM providers and
> posts structured feedback to GitLab MRs / GitHub PRs.

The purpose line must be specific enough to distinguish this project from all others.

### Section 2: Technology Stack & Versions

**Size target:** 15-40 lines. **Problem addressed:** Stale knowledge (primary), diff-only visibility.

This is the most critical section. Versions are the #1 thing LLM reviewers get wrong.

```markdown
## Technology Stack

### Versions (current as of YYYY-MM-DD)
- **Python** 3.12 | **Node** 22 LTS | [primary language version]
- **[framework]** x.y.z
- **[key dep]** >=x.y.z - [project-specific usage note, only if non-obvious]
- **[key dep]** >=x.y.z - [why this one over alternatives, if relevant]

### AI/LLM Models (if applicable)
- Main: `model-name-version` | Synthesis: `model-name-version`

### Container Images (if applicable)
- Base: `image:tag` | Build: `image:tag`

### Dev Tools
- **Testing:** pytest >=9.0 (75% coverage) | **Linting:** ruff >=0.14 | **Types:** mypy strict
- **CI:** [platform] | **Package:** [tool]
```

**Rules:**
- Always include the date so the reviewer knows when versions were captured
- Only list deps a reviewer might encounter in diffs — skip transitive/invisible ones
- Dependency notes should only explain non-obvious usage or choices
- AI model names and container image tags are high-value — they change frequently

BAD (generic, wastes tokens):
> - **requests** - HTTP library for making API calls. Requests is a popular
>   Python library that simplifies HTTP communication.

BAD (missing version):
> - **langchain** - Used for LLM interactions

GOOD (concise, version-accurate, project-specific):
> - **langchain>=1.0.0** - LLM chains via `langchain_core` + provider packages.
>   Uses `with_structured_output(CodeReview)` for typed responses.
> - **httpx>=0.28.1** - All HTTP (sync + async). Chosen over aiohttp.

### Section 3: Architecture & Code Organization

**Size target:** 20-60 lines. **Problem addressed:** Diff-only visibility.

```markdown
## Architecture & Code Organization

### Structure
[Compact annotated tree — only directories/files that matter for review context]

### Key Patterns
[2-4 bullet points: patterns actually in use, with file references]
[Focus on patterns a reviewer might misunderstand from a diff alone]

### Critical Files
[Files that are high-risk, frequently changed, or have complex invariants]
[For each: one line on what it does + what to watch for in reviews]
```

**Rules:**
- Directory tree should be compact. Only paths a reviewer is likely to see in diffs.
- Patterns section: only patterns that aren't obvious from the code.
  "We use classes" is obvious.
  "All platform clients use Template Method — public methods handle caching,
  `_impl` methods do the work" is useful.
- Critical files: max 5-8. Each gets one line focusing on WHY it's critical for review.

BAD (over-documented):
> ### Structure
> ```
> src/
> ├── __init__.py          # Package initializer
> ├── main.py              # Main entry point for the application
> ├── utils/
> │   ├── __init__.py      # Utils package initializer
> │   ├── helpers.py       # Helper functions
> │   └── constants.py     # Constant values
> ```

GOOD (focused on review-relevant context):
> ### Structure
> ```
> src/ai_code_review/
> ├── cli.py              # Entry point, argument parsing
> ├── core/
> │   ├── review_engine.py # Central orchestrator (two-phase review)
> │   ├── gitlab_client.py # GitLab API integration
> │   └── github_client.py # GitHub API integration
> ├── models/config.py     # CRITICAL: layered config system
> ├── providers/           # AI provider implementations (LangChain)
> └── utils/prompts.py     # LLM prompt templates + chain construction
> ```

### Section 4: Review Guidance

**Size target:** 15-40 lines. **Problem addressed:** All three problems.

This is the highest-value section. It directly tells the reviewer what to enforce
and what to ignore.

```markdown
## Review Guidance

### What Reviewers Must Know
[Project-specific rules the LLM WILL get wrong without this context]
[Each item: one concise bullet with the rule and why]

### Do NOT Flag (Known False Positives)
[Patterns that look like issues but are intentional]
[Each: what it looks like, why it's correct, what reviewers wrongly suggest]

### Common Pitfalls
[Mistakes that actually happen in this codebase, from git history or known issues]
[Each: the mistake, the impact, the correct approach — 2-3 lines max]
```

**Rules:**
- "What Reviewers Must Know" = things the LLM consistently gets wrong for THIS project
- "Do NOT Flag" = intentional patterns that look like code smells
- "Common Pitfalls" = evidence-based from git history (reverts, fix commits)
- Every item must pass: "Would this prevent a specific wrong review comment?"

BAD (generic, the LLM already knows this):
> - Always handle errors properly
> - Use meaningful variable names
> - Write tests for new features

GOOD (project-specific, actionable):
> ### What Reviewers Must Know
> - **Config priority**: CLI > Env > File > Defaults. Never use `default_factory`
>   with field refs — breaks layering. Use `None` + getter pattern.
> - **Health checks are intentionally lightweight** for Direct API providers —
>   don't suggest adding API calls (only validates API key format).
>
> ### Do NOT Flag
> - `# type: ignore` on Pydantic dynamic attributes — known mypy limitation
> - Sync `httpx.get()` in initialization code — intentional, runs once
>
> ### Common Pitfalls
> - Setting field defaults in validators bypasses CLI/env overrides (commit 8fbf91b)
> - Template rendering: use 4 backticks in Jinja2 to prevent LLM code block breakage

### Section 5: Internal & Proprietary

**Size target:** 5-15 lines. **Problem addressed:** Internal knowledge.
**Only include if the project uses internal tools/services/libraries.**

```markdown
## Internal & Proprietary

- **[internal lib]**: [One line — what it is, what it does. The LLM has zero data on this.]
- **[internal API]**: [Endpoint pattern, auth method — only what's needed to understand code]
- **[internal convention]**: [What and why, if it differs from public conventions]
```

**Rules:**
- Only things the LLM genuinely cannot know. Open-source libraries are NOT internal.
- Minimal descriptions. Goal is preventing wrong assumptions, not full documentation.
- If no internal dependencies exist, omit this section entirely.

---

## Team Scope — Section Templates

Team files focus on what's shared across repos. Size target: under 200 lines total.

### Team Section 1: Team Overview

```markdown
## Team Overview

**Team/Org:** [Name]
**Scope:** [What projects/repos this context covers]
**Primary Stack:** [Language(s), framework(s), key shared tools]
```

### Team Section 2: Shared Technology & Versions

```markdown
## Shared Technology & Versions (current as of YYYY-MM-DD)

### Language & Runtime
- **Python** 3.12 | **Node** 22 LTS

### Shared Dependencies
- **[dep]** >=x.y.z - [how the team uses it — standard across all projects]

### Approved Container Images
- Base: `company-registry/python:3.12-slim` (NOT public `python:3.12`)

### AI/LLM Models (if applicable)
- Production: `model-version` | Development: `model-version`
```

### Team Section 3: Internal Services & Libraries

Often the highest-value team section — things no LLM has seen in training.

```markdown
## Internal Services & Libraries

- **company-auth-lib** v2.x: Internal JWT auth. Don't suggest public alternatives.
- **UserService** (internal-api.company.com): REST API. Always via `company-http-client`.
- **EventBus**: Internal Kafka wrapper. Uses `publish()`/`subscribe()`, NOT standard API.
```

### Team Section 4: Coding Standards

```markdown
## Coding Standards

- All async code must use `httpx`, never `aiohttp` in async contexts.
- Error responses follow RFC 7807. Don't suggest custom error formats.
- Structured logging only (`structlog`). Never `print()` or `logging.basicConfig()`.
```

### Team Section 5: Security & Compliance

```markdown
## Security & Compliance

- API keys must NEVER be logged. Use `mask_sensitive_data()` from `company-utils`.
- PII fields require encryption at rest. Check for `@pii_field` decorator.
```

### Team Section 6: Review Standards

```markdown
## Review Standards

### Always Flag
- Direct database queries outside the repository layer
- Hardcoded URLs or service endpoints

### Never Flag
- `# type: ignore` on SQLAlchemy dynamic attributes
- Long functions in migration scripts (one-time operations)
```

---

## Manual Sections (Both Scopes)

Below the `<!-- MANUAL SECTIONS - DO NOT MODIFY THIS LINE -->` marker.

On first generation, seed these with whatever you can infer. Don't leave them empty
when you have evidence from git history, code patterns, or README content.

**Project scope manual sections:**
- Architecture & Design Decisions — from git history (reverts, big refactors)
- Business Logic — domain rules, intentional deviations
- Domain-Specific Context — terminology, external services
- Special Cases — exceptions, legacy compatibility, intentional anti-patterns

**Team scope manual sections:**
- Architectural Principles — shared patterns, approved technologies
- Deployment & Infrastructure — how services are deployed
- Cross-Project Dependencies — how shared libraries interact

**Style:** Concise bullet points, not paragraphs. Each entry answers:
"What would a reviewer get wrong without knowing this?"

---

## Size Calibration Guide

### How to decide what's worth including

1. **Would a reviewer see this in a typical diff?** If not, it probably doesn't belong.
2. **Would the LLM get this right without the context?** If yes, skip it.
3. **Is there a simpler way to say this?** One line beats three.
4. **Is this project-specific or generic?** Generic knowledge wastes tokens.

### Size by project complexity

| Complexity | Total Lines | Tech Stack | Architecture | Review Guidance | Other |
|-----------|------------|-----------|--------------|----------------|-------|
| Simple    | <150       | 10-15     | 10-20        | 10-20          | 5-10  |
| Medium    | <300       | 20-30     | 30-50        | 20-35          | 10-20 |
| Complex   | <500       | 30-45     | 50-80        | 30-50          | 15-30 |

These are maximums. Fewer lines at the same quality is always better.

### Formatting Conventions

- Use bullet points over prose
- Use inline code for file references: `src/config.py`
- Use bold for dependency names: **httpx>=0.28.1**
- Prefer tables for structured version info
- Use `---` to separate auto-generated from manual sections
- Always include the manual sections marker on generation

---

## Generated-By Footer (Both Scopes)

Every generated context file must end with a concise footer indicating that it was
AI-generated and stating the tool and version used. Place the footer on the very last
line of the file, after all content (including manual sections).

```markdown
---
*Generated by [context-generator](https://github.com/juanje/context-generator) vX.Y.Z | <host-tool> <host-version> with <model>*
```

**Placeholder values:**
- `vX.Y.Z` — version from the skill's frontmatter (`version` field in SKILL.md)
- `<host-tool> <host-version>` — the IDE or CLI running the skill (e.g. `Cursor 2.6.11`)
- `<model>` — the LLM model executing the skill (e.g. `claude-4.6-opus-high`)

Fill in the host tool, version, and model from the runtime environment. If any value
is not available, omit that part rather than guessing.

The footer must be present on both initial generation and full refresh. During
section-level or additive updates, preserve an existing footer as-is (update values
only if they have changed).
