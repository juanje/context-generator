---
name: context-generator
version: 1.0.0
description: >
  Use this skill to generate or update project context files (.ai_review/project.md) that help
  AI code reviewers understand a codebase. Invoke it when users want to: fix AI review quality
  (reviewers flagging internal libraries, suggesting outdated versions, missing architecture
  context); create or refresh .ai_review/project.md or similar context files; build team-level
  or org-wide coding standards for AI reviewers; set up context for ai-code-review, Cursor rules,
  or any AI-assisted review system; or make LLM reviewers aware of project-specific patterns,
  internal services, and current dependency versions. Also use when users mention stale review
  context, project context generation, or want to help AI reviewers understand their codebase.
  This skill explores the repo, extracts versions from dependency files, analyzes architecture,
  and produces a concise context file — not a README, not a CLAUDE.md, not documentation.
---

# Context Generator

Generate and maintain concise project context files that patch three specific blind spots
LLMs have when reviewing code diffs.

## The Three Problems This Solves

1. **Stale Knowledge** — LLMs have a training cutoff (often 6-12 months old). They suggest
   outdated library versions, flag current versions as non-existent, and recommend deprecated
   APIs. The context file provides **current versions** of dependencies, models, and images.
   This is the single most impactful thing the context file does.

2. **Diff-Only Visibility** — The reviewing LLM sees only the diff, not the codebase. It
   doesn't know how changed code connects to the rest of the system, what patterns exist in
   unchanged code, or what abstractions wrap the libraries being used. The context file
   provides **structural and architectural knowledge** that makes the diff interpretable.

3. **Internal/Proprietary Knowledge** — The project may use internal libraries, services,
   tools, or conventions that the LLM has never seen in training data. It will make wrong
   assumptions about these. The context file **documents what's internal** and how it works.

Every line in the output must address at least one of these problems. Apply the inclusion
test: "If an LLM reviewer doesn't know this, will it produce a wrong or misleading review
comment?" If the answer is no, the line doesn't belong.

## Size Constraint

The context file shares the context window with the diff being reviewed. Many MRs/PRs are
large. Every token in the context file is a token unavailable for the review.

- Simple projects (<10 source files): **under 150 lines**
- Medium projects: **under 300 lines**
- Complex projects: **under 500 lines**
- Team files: **under 200 lines**

When in doubt, cut. Dense, specific content beats comprehensive coverage.

---

## Workflow

### Step 1: Detect Scope and Mode

**Scope detection:**
- User says "project", "this repo", "this codebase" → **Project scope**
- User says "team", "organization", "shared", "cross-project", "standards" → **Team scope**
- No explicit scope + running inside a repo → **Project scope** (default)
- Ambiguous → Ask

**Mode detection:**
- Context file exists with substantive content → **Update mode**
- Context file doesn't exist or contains only template placeholders → **Generate mode**
- User says "regenerate" or "start fresh" → **Generate mode** (confirm if curated content
  would be lost)

### Step 2: Execute the Appropriate Workflow

Jump to the relevant section below based on scope and mode.

### Step 3: Validate Before Finishing

Run through the quality checklist:
1. Every line prevents a review error — no generic content the LLM already knows
2. No hallucinated file paths, versions, or references — all from actual project files
3. All version numbers sourced from dependency files, not from memory
4. Under the size target for the project's complexity
5. No over-explanation of well-known tools or libraries
6. No duplication with CLAUDE.md or team context file (if applicable)

---

## Generate Mode — Project Scope

### Phase 1: Fast Facts

Run the extraction script to get a project snapshot in one call:

```bash
bash <skill-path>/scripts/extract_project_facts.sh [project-root]
```

This outputs: root files, language detection, dependency file contents, directory structure
(top 3 levels), git stats (recent commits, most-changed files, repo age), and key file
presence (CLAUDE.md, .cursor/rules/, .ai_review/, Dockerfile, CI configs).

Use this output to decide exploration depth. A 5-file utility needs minimal exploration.
A complex multi-package project needs thorough reading.

### Phase 2: Deep Exploration

Read files in order of value for the context file. Adapt depth to project complexity.

**Priority 1 — Versions (highest value, addresses stale knowledge):**
- Dependency files: pyproject.toml, package.json, go.mod, Cargo.toml, Gemfile, pom.xml,
  composer.json, requirements.txt, build.gradle
- Dockerfile FROM lines, docker-compose.yml image tags
- AI/LLM model names in config files, constants, environment variables
- Extract **exact version constraints** for all dependencies the reviewer might encounter
  in diffs. This is the #1 thing reviewers get wrong without context.

**Priority 2 — Architecture (addresses diff-only visibility):**
- Entry points (main, cli, app, index — whatever the project uses)
- Configuration/settings files (how config works, what the priority system is)
- Core business logic (the files other files depend on — follow imports)
- Model/type definitions
- Read files in full when needed. No arbitrary line limits.

**Priority 3 — Patterns (addresses diff-only visibility):**
- Design patterns actually in use (factory, strategy, template method, etc.)
- Naming conventions, module organization, error handling patterns
- Abstractions over external services (HTTP clients, DB layers, API wrappers)
- Configuration system (env vars, config files, CLI args — what's the priority?)

**Priority 4 — Git History (seeds manual sections):**
- Last 30-50 commit messages for patterns, decisions, and conventions
- Reverts, regression fixes, commits mentioning architectural choices
- Conventional commit patterns, PR/MR references
- This is the primary source for "Common Pitfalls" and "Architecture Decisions"

**Priority 5 — Development Workflow:**
- CI/CD configuration (what's enforced, what's optional)
- Pre-commit hooks, linting, formatting, type checking
- Test framework, coverage requirements, test organization

**Priority 6 — Existing Documentation:**
- README.md, ARCHITECTURE.md, CONTRIBUTING.md
- CLAUDE.md or .cursor/rules/ — complement these, don't duplicate
- If CLAUDE.md exists, read it fully and ensure consistency

Skip phases that don't yield useful information. No git? Skip Phase 4. No CI? Skip that
part of Phase 5. Tiny project? Phases 2-3 collapse into a brief scan.

For non-standard project types (IaC, frontend apps, data/ML, monorepos), read
`references/adaptation-guide.md` after this phase to calibrate your approach.

### Phase 3: Optional Question

After exploration, you may offer **ONE** high-leverage question — something where the
answer would significantly improve the output and isn't inferrable from code.

**Good questions** (specific, grounded in what you found):
- "I see both aiohttp and httpx in the deps. Is there a preferred choice for new code?"
- "The retry logic in payment_processor.py uses unusual backoff. Intentional or a flag?"
- "Config has both env vars and YAML loading. What's the priority order?"

**Bad questions** (don't ask these):
- "What does this project do?" — Inferrable from README and code
- "What language is this?" — Obvious from files
- "What are your coding conventions?" — Detectable from code patterns
- Open-ended questions requiring long written answers

The user can answer, skip, or say "just generate it." All valid responses. **Never block
on a question.** The output must be useful even with zero user input.

### Phase 4: Write the Output

Read `references/output-format.md` for the exact format specification with section
templates and quality criteria.

Read `references/example-context.md` to calibrate what "every token earns its place"
looks like in practice.

**Default output path:** `.ai_review/project.md`
Create the `.ai_review/` directory if it doesn't exist. The user can specify any path.

**Project scope auto-generated sections:**
1. Project Overview (3-5 lines)
2. Technology Stack & Versions (most critical section)
3. Architecture & Code Organization
4. Review Guidance (highest value section)
5. Internal & Proprietary (only if applicable)

**Manual sections** (below the `<!-- MANUAL SECTIONS -->` marker):
- Architecture & Design Decisions — seed from git history
- Business Logic — seed what you can infer, leave room for user input
- Domain-Specific Context — terminology, external services
- Special Cases — exceptions, legacy compatibility

Seed manual sections with whatever you can infer. Don't leave them empty when you
have evidence from git history or code patterns.

**Footer:** End the file with the generated-by footer (see `references/output-format.md`).
Use the version from this skill's frontmatter, and include the host tool and model.

---

## Generate Mode — Team Scope

Team context covers shared conventions across multiple repositories. There's no single
codebase to analyze exhaustively, so user input is more valuable here.

### Gathering Information

Ask **2-4 focused questions** with concrete options (use the host agent's question tool):

1. "What's your team's primary tech stack?" → Common stacks as options + Other
2. "Does your team use internal libraries or services that LLMs wouldn't know about?"
   → Yes (list them) / No / Skip
3. "Any coding standards reviewers should enforce across all projects?"
   → Options: logging rules / error handling / HTTP client preferences / naming / Skip
4. "Any security or compliance requirements for code reviews?"
   → Options: PII handling / auth patterns / audit logging / Skip

All questions are skippable. If the user skips everything, produce a useful skeleton
seeded from the current repo (if running inside one) as a representative sample.

### Writing the Output

Read `references/output-format.md` for the team scope format specification.

**Team scope sections:**
1. Team Overview (3-5 lines)
2. Shared Technology & Versions
3. Internal Services & Libraries
4. Coding Standards & Conventions
5. Security & Compliance (when applicable)
6. Review Standards

**Size target:** under 200 lines. Team files are loaded alongside project files — both
share the context window.

**Footer:** End the file with the generated-by footer (see `references/output-format.md`).
Include the host tool and model.

### How Team + Project Files Complement Each Other

- **Team file**: "We use Python 3.12, FastAPI, PostgreSQL. All services use structured logging."
- **Project file**: "This service handles payments. Uses review_engine.py as orchestrator."

No duplication. If the team file documents shared stack versions, the project file only
lists project-specific additions or overrides.

---

## Update Mode (Both Scopes)

### Step 1: Assess Staleness

Run the staleness detection script:

```bash
bash <skill-path>/scripts/detect_staleness.sh [project-root] [context-file-path]
```

This reports: changed dependencies (added/removed/version bumps), files/directories
mentioned in the context file that no longer exist, new directories not mentioned,
and git commits since the context file was last modified.

### Step 2: Determine Update Scope

**If the user gave a specific request** ("update the tech stack", "add this anti-pattern"):
Just do it. No questions needed.

**If running without specific request** (general refresh):
Report what looks stale and suggest updates. Don't silently overwrite.

### Step 3: Apply Updates

**Section-level update** (user targets a specific area):
1. Read the existing section
2. Read the current state of relevant source files
3. Rewrite only the affected section, preserving everything else

**Additive update** (user wants to add information):
1. Read the relevant section
2. Add new content in the established format
3. Check for duplication — don't add if similar content exists

**Full refresh** (user requests complete regeneration):
1. Confirm that manual sections will be preserved
2. Re-explore the project (same as generate mode phases)
3. Regenerate all auto-generated sections
4. Preserve everything below `<!-- MANUAL SECTIONS - DO NOT MODIFY THIS LINE -->`
5. Update the generated-by footer with the current version, tool, and model

### Preservation Rules

- **Never** overwrite content below the manual sections marker without explicit permission
- Updates should only add or improve quality — never downgrade
- When unsure whether something should change, ask
- Report staleness in sections not automatically updated

---

## Relationship to Other Context Files

### CLAUDE.md
- **CLAUDE.md**: Instructions for the AI agent working IN the codebase
- **project.md**: Context for AI code REVIEWERS evaluating changes

Read CLAUDE.md if it exists. Don't duplicate — complement. Focus project.md on
review-specific guidance. Stay consistent with CLAUDE.md's opinions.

### Cursor Rules / Other AI Context
If `.cursor/rules/` or similar exists, be aware of it and avoid contradiction.
The output format is standard markdown — compatible with most AI context systems.

---

## Edge Cases

- **Small projects (<10 files)**: Skip detailed directory tree. Focus on deps and patterns.
  Context file should be proportionally small.
- **Monorepos**: Focus on the package/service the user is working in. Ask if ambiguous.
  Note cross-package dependencies.
- **No git repository**: Skip git history. Use filesystem listing. Note that design
  decisions couldn't be inferred from history.
- **Existing custom structure**: Preserve custom structure rather than forcing the template.
  Update content within the existing organization.
- **Non-code projects (IaC, config repos)**: Adapt sections to project type. Read
  `references/adaptation-guide.md` for guidance.
- **CLAUDE.md exists but no project.md**: Read CLAUDE.md, generate project.md as complement.

---

## Resource Reference

| Resource | When to Load | Purpose |
|----------|-------------|---------|
| `scripts/extract_project_facts.sh` | Always first in generate mode | Fast project snapshot in one call |
| `scripts/detect_staleness.sh` | Update mode, before making changes | Identifies what's stale |
| `references/output-format.md` | Before writing any output | Format spec, section templates, good vs bad examples |
| `references/example-context.md` | First generation | Calibrate quality and conciseness |
| `references/adaptation-guide.md` | After Phase 1, if non-standard project | Adapt approach for project type or AI tool |
