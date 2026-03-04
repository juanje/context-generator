# context-generator

An AI agent skill that generates and maintains concise project context files to help LLM code
reviewers understand your codebase.

> **Primary use case:** generates `.ai_review/project.md` for use with
> [ai-code-review](https://gitlab.com/redhat/edge/ci-cd/ai-code-review), an AI-powered code
> review tool for local changes, GitLab MRs, and GitHub PRs. It can also be adapted for any
> other LLM-based reviewer that accepts a context file.

## What it does

It patches three blind spots LLMs have when reviewing code diffs:

1. **Stale knowledge** — extracts current dependency versions from your actual project files so
   reviewers don't suggest outdated APIs
2. **Diff-only visibility** — documents architecture and patterns invisible from a diff alone
3. **Internal/proprietary knowledge** — documents internal libraries and conventions the LLM has
   never seen

The output is a concise Markdown file — not a README, not documentation — written specifically
for an LLM reviewer to consume alongside a code diff.

## Installation

Clone the repository into the skills directory of your AI agent.

**Claude Code:**
```bash
git clone https://github.com/juanje/context-generator.git ~/.claude/skills/context-generator
```

**Cursor:**
```bash
git clone https://github.com/juanje/context-generator.git ~/.cursor/skills/context-generator
```

Then restart your agent. The skill will be available automatically.

## Usage

Just ask your agent:

- *"Generate a context file for this project"*
- *"Update the project context"*
- *"Create a team context file for our shared coding standards"*

The skill will explore your repository, extract current dependency versions, analyze the
architecture, and write `.ai_review/project.md` (or any path you specify).

## License

MIT — see `LICENSE` file.
