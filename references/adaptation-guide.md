# Adaptation Guide

How to adapt the context file format for different project types and AI tools.
Read this after Phase 1 (project identity) when the project doesn't fit the
default "application codebase" template.

---

## Project Type Adaptations

### Web Services (FastAPI, Express, Rails, Spring, etc.)

**Emphasize:**
- API patterns: routing conventions, middleware chain, request/response lifecycle
- Authentication/authorization: how auth works, what middleware enforces it
- Database access patterns: ORM usage, migration strategy, query conventions
- Error handling: how errors propagate from service layer to HTTP responses

**De-emphasize:**
- Frontend assets (if any — those are secondary)
- Deployment details (unless they affect code patterns)

**Section adjustments:**
- Architecture section: include request flow (route → middleware → service → DB)
- Review Guidance: emphasize API contract stability, migration safety

### CLI Tools (Click, Commander, Cobra, clap, etc.)

**Emphasize:**
- Argument parsing: how options map to behavior, validation rules
- Exit codes: what each code means, when to use which
- Output formatting: stdout vs stderr, machine-readable vs human-readable
- Error handling: user-facing error messages, graceful degradation

**De-emphasize:**
- Internal module structure (often simpler than services)
- Database patterns (usually not applicable)

**Section adjustments:**
- Architecture section: focus on command structure and data flow
- Review Guidance: emphasize backwards-compatible CLI interface changes

### Libraries / SDKs

**Emphasize:**
- Public API surface: what's exported, what's internal, stability guarantees
- Backwards compatibility: versioning strategy, deprecation process
- Extension points: how users customize behavior (hooks, plugins, callbacks)
- Type annotations: public types that consumers depend on

**De-emphasize:**
- Internal implementation details (unless they leak into the public API)
- Deployment and operations (library consumers handle this)

**Section adjustments:**
- Architecture section: focus on public API organization and internal boundaries
- Review Guidance: emphasize semver compliance, public API changes need scrutiny
- Add "Public API Surface" as a critical review area

### Infrastructure as Code (Terraform, Pulumi, CloudFormation, Ansible)

**Replace standard sections:**
- "Architecture & Code Organization" → "Resource Organization"
- "Key Patterns" → "Module/Stack Structure"
- "Critical Files" → "Critical Resources & State"

**Emphasize:**
- Module structure: how reusable modules are organized
- State management: where state lives, who manages it
- Environment separation: how dev/staging/prod differ
- Variable conventions: naming, defaults, overrides
- Security resources: IAM roles, security groups, secrets management

**De-emphasize:**
- Programming patterns (less applicable)
- Testing frameworks (IaC testing is different)

**Section adjustments:**
- Tech Stack: list provider versions, module versions, CLI tool versions
- Review Guidance: state file safety, blast radius of changes, dependency order

### Monorepos

**Scope decision:**
- If the user specifies a package: scope to that package only
- If ambiguous: ask which package/service to focus on
- If they want the whole repo: create a high-level context + per-package sections

**Emphasize:**
- Cross-package dependencies and boundaries
- Shared tooling and conventions
- Build system (nx, turborepo, bazel, lerna) and how it affects changes
- Which packages are independently deployable vs tightly coupled

**Section adjustments:**
- Structure section: show package boundaries, shared directories
- Review Guidance: cross-package impact awareness, dependency rules

### Data / ML Projects

**Emphasize:**
- Data pipeline patterns: ETL/ELT steps, data validation, schema evolution
- Model versioning: how models are tracked, reproduced, deployed
- Experiment tracking: MLflow, W&B, or custom — how experiments relate to code
- Data contracts: input/output schemas, feature stores, data quality checks

**De-emphasize:**
- Standard web patterns (usually secondary)
- UI/frontend (if it's a dashboard, keep it minimal)

**Section adjustments:**
- Architecture: pipeline DAG, data flow, model serving
- Tech Stack: include ML framework versions, CUDA/GPU requirements
- Review Guidance: data leakage risks, reproducibility, feature engineering patterns

### Frontend Apps (React, Vue, Angular, Svelte)

**Emphasize:**
- Component patterns: naming, structure, composition approach
- State management: what's used (Redux, Zustand, Context, signals), where state lives
- Routing: how routes are organized, guards/middleware
- Build/bundle configuration: relevant webpack/vite/esbuild settings
- CSS strategy: modules, styled-components, Tailwind, etc.

**De-emphasize:**
- Backend/API details (unless tightly coupled)
- Database patterns (usually not applicable)

**Section adjustments:**
- Architecture: component hierarchy, state flow, data fetching patterns
- Tech Stack: framework version, build tool version, key lib versions
- Review Guidance: component re-render risks, accessibility, bundle size impact

---

## AI Tool Adaptations

### ai-code-review

**Default target.** The context file is loaded as `project_context` during reviews.

- Output to `.ai_review/project.md` (default path)
- Full format as specified in output-format.md
- Team context goes in a separate file (team scope)
- Priority: team_context > project_context > commit_history

No special adaptation needed — this is the primary format.

### Claude Code (CLAUDE.md complement)

When CLAUDE.md already exists, the context file should complement it:

- Read CLAUDE.md fully before generating
- Don't duplicate content that's in CLAUDE.md
- Focus on review-specific guidance (CLAUDE.md covers development workflow)
- Cross-reference: "See CLAUDE.md for build commands and development setup"

**What goes where:**
- CLAUDE.md: How to work in this codebase (commands, workflows, rules for the agent)
- project.md: How to review changes to this codebase (context for the reviewer)

### Cursor Rules

Cursor uses `.cursor/rules/` for project context. The context file format maps well:

- Project Overview → can be a rule file preamble
- Tech Stack → maps to "Technology Context" rule
- Architecture → maps to "Code Organization" rule
- Review Guidance → maps to "Code Review Standards" rule

**If outputting for Cursor specifically:**
- Split into multiple focused files in `.cursor/rules/` instead of one large file
- Use Cursor's rule format (plain markdown, one topic per file)
- Keep each rule file under 100 lines

### Windsurf / Aider / Other

The markdown format is universally compatible. No special syntax needed.

- Output to whatever path the tool expects (user-specified)
- The section structure works as-is for any tool that reads markdown context
- If the tool has a specific format, adapt the section headers accordingly

---

## Language-Specific Notes

These aren't full adaptations — just things to watch for per language ecosystem.

**Python:** pyproject.toml is the primary dep file. Watch for src-layout vs flat-layout.
Check for type: ignore comments to document in "Do NOT Flag."

**JavaScript/TypeScript:** package.json + lockfile. Note whether it's npm/yarn/pnpm.
Check tsconfig strictness. Note any build-time vs runtime dep distinctions.

**Go:** go.mod for deps. Note if it uses internal/ convention. Watch for build tags.
Check for //go:generate directives to document.

**Rust:** Cargo.toml for deps. Note workspace structure if it's a multi-crate project.
Check for unsafe blocks to document as "Do NOT Flag" or "Always Flag."

**Java/Kotlin:** pom.xml or build.gradle. Note Spring Boot version if applicable.
Check for annotation processors that affect code structure.

**Ruby:** Gemfile for deps. Note Rails version if applicable. Check for
initializers that set up conventions.
