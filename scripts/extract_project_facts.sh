#!/usr/bin/env bash
# extract_project_facts.sh — Fast project facts extraction
# Gathers structured facts about a project in one call so the agent
# doesn't need 10-15 individual tool calls for basic project info.
#
# Usage: bash extract_project_facts.sh [project-root]
# Default project-root: current directory

set -euo pipefail

PROJECT_ROOT="${1:-.}"
cd "$PROJECT_ROOT"

echo "========================================"
echo "PROJECT FACTS EXTRACTION"
echo "========================================"
echo "Root: $(pwd)"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# ── Root Files ──────────────────────────────────────────────
echo "── ROOT FILES ──"
ls -1a 2>/dev/null | grep -v '^\.\.$' | grep -v '^\.$' | head -40
echo ""

# ── Key File Presence ───────────────────────────────────────
echo "── KEY FILES ──"
for f in README.md README.rst README CLAUDE.md .ai_review/project.md \
         .ai_review/config.yml .cursor/rules Dockerfile docker-compose.yml \
         docker-compose.yaml .gitlab-ci.yml .github/workflows Makefile \
         Taskfile.yml justfile .pre-commit-config.yaml .editorconfig \
         .env.example env.example; do
    if [ -e "$f" ]; then
        echo "  [EXISTS] $f"
    fi
done
echo ""

# ── Primary Language Detection ──────────────────────────────
echo "── LANGUAGE DETECTION (by file count) ──"
if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    git ls-files 2>/dev/null | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -15
else
    find . -type f -not -path '*/\.*' -not -path '*/node_modules/*' \
           -not -path '*/vendor/*' -not -path '*/__pycache__/*' \
           -not -path '*/dist/*' -not -path '*/build/*' \
           -not -path '*/.git/*' 2>/dev/null \
    | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -15
fi
echo ""

# ── Dependency Files ────────────────────────────────────────
echo "── DEPENDENCY FILES ──"

dep_files=(
    "pyproject.toml" "setup.py" "setup.cfg" "requirements.txt" "Pipfile"
    "package.json" "yarn.lock" "pnpm-lock.yaml"
    "go.mod" "go.sum"
    "Cargo.toml"
    "Gemfile" "Gemfile.lock"
    "pom.xml" "build.gradle" "build.gradle.kts"
    "composer.json"
    "mix.exs"
    "pubspec.yaml"
    "Package.swift"
    "CMakeLists.txt" "conanfile.txt"
)

found_deps=0
for f in "${dep_files[@]}"; do
    if [ -f "$f" ]; then
        echo ""
        echo "--- $f ---"
        # Show full content for most files, truncate very large ones
        line_count=$(wc -l < "$f" 2>/dev/null || echo "0")
        if [ "$line_count" -gt 200 ]; then
            head -200 "$f"
            echo "... (truncated, $line_count total lines)"
        else
            cat "$f"
        fi
        found_deps=1
    fi
done

if [ "$found_deps" -eq 0 ]; then
    echo "  No standard dependency files found."
fi
echo ""

# ── Dockerfile / Container Images ──────────────────────────
echo "── CONTAINER IMAGES ──"
for f in Dockerfile Dockerfile.* docker-compose.yml docker-compose.yaml; do
    if [ -f "$f" ]; then
        echo "--- $f (FROM/image lines) ---"
        grep -n -i -E '^\s*(FROM|image:)' "$f" 2>/dev/null || echo "  (no FROM/image lines)"
    fi
done
echo ""

# ── Directory Structure ────────────────────────────────────
echo "── DIRECTORY STRUCTURE (top 3 levels) ──"
if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    git ls-files 2>/dev/null | sed 's|/[^/]*$||' | sort -u | \
        awk -F/ 'NF<=3' | head -50
else
    find . -type d -maxdepth 3 -not -path '*/\.*' -not -path '*/node_modules/*' \
           -not -path '*/vendor/*' -not -path '*/__pycache__/*' \
           -not -path '*/dist/*' -not -path '*/build/*' 2>/dev/null \
    | sed 's|^\./||' | sort | head -50
fi
echo ""

# ── Git Stats ──────────────────────────────────────────────
echo "── GIT STATS ──"
if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    total_commits=$(git rev-list --count HEAD 2>/dev/null || echo "unknown")
    echo "Total commits: $total_commits"

    first_commit=$(git log --reverse --format='%ci' 2>/dev/null | head -1)
    echo "First commit: ${first_commit:-unknown}"

    contributors=$(git shortlog -sn --no-merges 2>/dev/null | wc -l | tr -d ' ')
    echo "Contributors: $contributors"

    echo ""
    echo "--- Last 30 commit subjects ---"
    git log --oneline -30 2>/dev/null || echo "  (no commits)"

    echo ""
    echo "--- Most changed files (top 15 by commit frequency) ---"
    git log --name-only --pretty=format: --diff-filter=ACMR 2>/dev/null \
    | grep -v '^$' | sort | uniq -c | sort -rn | head -15

    echo ""
    echo "--- Recent tags ---"
    git tag --sort=-version:refname 2>/dev/null | head -5 || echo "  (no tags)"
else
    echo "  Not a git repository."
fi
echo ""

# ── CI/CD Config ───────────────────────────────────────────
echo "── CI/CD CONFIGURATION ──"
for f in .gitlab-ci.yml .github/workflows/*.yml .github/workflows/*.yaml \
         .circleci/config.yml .travis.yml Jenkinsfile .drone.yml \
         bitbucket-pipelines.yml azure-pipelines.yml; do
    if [ -f "$f" ] 2>/dev/null; then
        echo "  [EXISTS] $f"
    fi
done
# Check for GitLab CI includes directory (.gitlab/)
if [ -d ".gitlab" ]; then
    echo "  GitLab CI includes (.gitlab/):"
    find .gitlab -type f \( -name "*.yml" -o -name "*.yaml" \) 2>/dev/null | sort | head -20
fi
# Check for GitHub Actions directory
if [ -d ".github/workflows" ]; then
    echo "  GitHub Actions workflows:"
    ls -1 .github/workflows/ 2>/dev/null | head -10
fi
echo ""

# ── AI/LLM Model References ───────────────────────────────
echo "── AI/LLM MODEL REFERENCES ──"
if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    git ls-files 2>/dev/null | xargs grep -l -i -E \
        '(gpt-[34o]|claude|gemini|llama|mistral|qwen|model.*=|MODEL_NAME|model_id|model_name)' \
        2>/dev/null | head -10
else
    grep -r -l -i -E \
        '(gpt-[34o]|claude|gemini|llama|mistral|qwen|model.*=|MODEL_NAME|model_id|model_name)' \
        --include='*.py' --include='*.js' --include='*.ts' --include='*.yml' \
        --include='*.yaml' --include='*.toml' --include='*.json' --include='*.env*' \
        . 2>/dev/null | grep -v node_modules | grep -v __pycache__ | head -10
fi
echo ""

echo "========================================"
echo "END OF FACTS EXTRACTION"
echo "========================================"
