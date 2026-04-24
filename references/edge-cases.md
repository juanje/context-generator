# Edge Cases

This document covers edge cases and special handling scenarios for the context generator.

## Small projects (<10 files)
Skip detailed directory tree. Focus on deps and patterns. Context file should be proportionally small.

## Monorepos
Focus on the package/service the user is working in. Ask if ambiguous. Note cross-package dependencies.

## No git repository
Skip git history. Use filesystem listing. Note that design decisions couldn't be inferred from history.

## Existing custom structure
Preserve custom structure rather than forcing the template. Update content within the existing organization.

## Non-code projects (IaC, config repos)
Adapt sections to project type. Read `references/adaptation-guide.md` for guidance.

## CLAUDE.md exists but no project.md
Read CLAUDE.md, generate project.md as complement.

## Multiple context systems
If `.cursor/rules/` or similar exists, be aware of it and avoid contradiction. The output format is standard markdown — compatible with most AI context systems.

## Zero-dependency projects
Focus on language patterns, architecture, and conventions rather than version constraints. Still valuable for architectural guidance.

## Legacy codebases
Pay extra attention to:
- Patterns that look wrong but are intentional (document in "Do NOT Flag")
- Migration states (old and new patterns coexisting)
- Technical debt that's acknowledged but not yet addressed

## High-security environments
Be mindful of:
- Not extracting sensitive configuration details
- Focusing on patterns rather than specific values
- Internal library names and conventions without exposing implementation details