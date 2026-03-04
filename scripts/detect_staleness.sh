#!/usr/bin/env bash
# detect_staleness.sh — Compare existing context file against current project state
# Identifies sections of the context file that may be stale.
#
# Usage: bash detect_staleness.sh [project-root] [context-file-path]
# Default project-root: current directory
# Default context-file: .ai_review/project.md

set -euo pipefail

PROJECT_ROOT="${1:-.}"
CONTEXT_FILE="${2:-${PROJECT_ROOT}/.ai_review/project.md}"

cd "$PROJECT_ROOT"

echo "========================================"
echo "STALENESS DETECTION REPORT"
echo "========================================"
echo "Project: $(pwd)"
echo "Context file: $CONTEXT_FILE"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

if [ ! -f "$CONTEXT_FILE" ]; then
    echo "ERROR: Context file not found: $CONTEXT_FILE"
    echo "Run in generate mode instead."
    exit 1
fi

CONTEXT_MTIME=""
if stat -f '%Sm' "$CONTEXT_FILE" &>/dev/null 2>&1; then
    # macOS
    CONTEXT_MTIME=$(stat -f '%Sm' -t '%Y-%m-%dT%H:%M:%S' "$CONTEXT_FILE" 2>/dev/null)
elif stat -c '%y' "$CONTEXT_FILE" &>/dev/null 2>&1; then
    # Linux
    CONTEXT_MTIME=$(stat -c '%y' "$CONTEXT_FILE" 2>/dev/null | cut -d. -f1)
fi
echo "Context file last modified: ${CONTEXT_MTIME:-unknown}"
echo ""

# ── Dependency Changes ──────────────────────────────────────
echo "── DEPENDENCY CHANGES ──"

check_dep_versions() {
    local dep_file="$1"
    local label="$2"

    if [ ! -f "$dep_file" ]; then
        return
    fi

    echo ""
    echo "--- $label ($dep_file) ---"

    # Extract version-like patterns from the dependency file
    local current_deps
    current_deps=$(cat "$dep_file" 2>/dev/null)

    # Extract dependency names mentioned in the context file
    # Look for patterns like **depname** or `depname` followed by version-like strings
    local context_deps
    context_deps=$(grep -oE '\*\*[a-zA-Z0-9_-]+[><=!~^]+[0-9][0-9.]*' "$CONTEXT_FILE" 2>/dev/null \
        | sed 's/\*\*//g' || true)

    if [ -z "$context_deps" ]; then
        context_deps=$(grep -oE '`[a-zA-Z0-9_-]+`.*[><=!~^]+[0-9][0-9.]*' "$CONTEXT_FILE" 2>/dev/null \
            | sed 's/`//g' || true)
    fi

    if [ -n "$context_deps" ]; then
        echo "Versions mentioned in context file:"
        echo "$context_deps" | head -20
        echo ""
    fi

    # Check if dependency file is newer than context file
    if [ -n "$CONTEXT_MTIME" ]; then
        local dep_mtime
        if stat -f '%Sm' "$dep_file" &>/dev/null 2>&1; then
            dep_mtime=$(stat -f '%Sm' -t '%Y-%m-%dT%H:%M:%S' "$dep_file" 2>/dev/null)
        elif stat -c '%y' "$dep_file" &>/dev/null 2>&1; then
            dep_mtime=$(stat -c '%y' "$dep_file" 2>/dev/null | cut -d. -f1)
        fi
        if [ -n "${dep_mtime:-}" ]; then
            echo "  Dependency file last modified: $dep_mtime"
            # Simple string comparison works for ISO dates
            if [[ "${dep_mtime}" > "${CONTEXT_MTIME}" ]]; then
                echo "  *** STALE: $dep_file is newer than context file ***"
            else
                echo "  OK: context file is newer"
            fi
        fi
    fi
}

# Check all common dependency files
for f in pyproject.toml setup.py setup.cfg requirements.txt Pipfile \
         package.json go.mod Cargo.toml Gemfile pom.xml build.gradle \
         build.gradle.kts composer.json mix.exs pubspec.yaml; do
    check_dep_versions "$f" "$(echo "$f" | tr '[:lower:]' '[:upper:]')"
done
echo ""

# ── Files Referenced in Context ─────────────────────────────
echo "── FILE REFERENCES CHECK ──"
echo "Files/directories mentioned in context file that may have changed:"
echo ""

# Extract file paths from the context file (patterns like `src/foo/bar.py` or src/foo/)
file_refs=$(grep -oE '`[a-zA-Z0-9_./-]+\.(py|js|ts|tsx|go|rs|rb|java|kt|swift|c|cpp|h|yml|yaml|toml|json|md)`' \
    "$CONTEXT_FILE" 2>/dev/null | sed 's/`//g' | sort -u || true)

dir_refs=$(grep -oE '`?[a-zA-Z0-9_-]+/[a-zA-Z0-9_/-]*`?' "$CONTEXT_FILE" 2>/dev/null \
    | sed 's/`//g' | grep -v '^http' | sort -u || true)

missing_count=0
if [ -n "$file_refs" ]; then
    while IFS= read -r ref; do
        if [ ! -e "$ref" ]; then
            echo "  [MISSING] $ref"
            missing_count=$((missing_count + 1))
        fi
    done <<< "$file_refs"
fi

if [ "$missing_count" -eq 0 ]; then
    echo "  All referenced files still exist."
fi
echo ""

# ── New Top-Level Directories ──────────────────────────────
echo "── NEW DIRECTORIES ──"
echo "Top-level directories not mentioned in context file:"
echo ""

new_count=0
for dir in */; do
    dir_name="${dir%/}"
    # Skip hidden dirs and common non-interesting dirs
    case "$dir_name" in
        .*|node_modules|__pycache__|.git|dist|build|target|vendor|venv|.venv|.tox|.mypy_cache|.ruff_cache|.pytest_cache|htmlcov|.eggs|*.egg-info)
            continue
            ;;
    esac

    if ! grep -q "$dir_name" "$CONTEXT_FILE" 2>/dev/null; then
        echo "  [NEW] $dir_name/"
        new_count=$((new_count + 1))
    fi
done

if [ "$new_count" -eq 0 ]; then
    echo "  No new top-level directories."
fi
echo ""

# ── Git Changes Since Context File ─────────────────────────
echo "── GIT CHANGES SINCE CONTEXT FILE ──"
if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    if [ -n "$CONTEXT_MTIME" ]; then
        # Count commits since context file was modified
        commit_count=$(git log --oneline --since="$CONTEXT_MTIME" 2>/dev/null | wc -l | tr -d ' ')
        echo "Commits since context file was modified: $commit_count"
        echo ""

        if [ "$commit_count" -gt 0 ]; then
            echo "--- Commit subjects since last update ---"
            git log --oneline --since="$CONTEXT_MTIME" 2>/dev/null | head -30
            echo ""

            echo "--- Files most changed since last update ---"
            git log --name-only --pretty=format: --since="$CONTEXT_MTIME" 2>/dev/null \
            | grep -v '^$' | sort | uniq -c | sort -rn | head -15
        fi
    else
        echo "  Could not determine context file modification time."
        echo "  Showing last 20 commits for reference:"
        git log --oneline -20 2>/dev/null
    fi
else
    echo "  Not a git repository — skipping."
fi
echo ""

# ── Dockerfile/Image Changes ──────────────────────────────
echo "── CONTAINER IMAGE CHECK ──"
for f in Dockerfile Dockerfile.* docker-compose.yml docker-compose.yaml; do
    if [ -f "$f" ] 2>/dev/null; then
        echo "--- Current images in $f ---"
        grep -n -i -E '^\s*(FROM|image:)' "$f" 2>/dev/null || true
        echo ""

        echo "--- Images mentioned in context file ---"
        grep -i -E '(FROM|image:|base:|build:).*`[^`]+`' "$CONTEXT_FILE" 2>/dev/null || \
            echo "  (no container images found in context file)"
        echo ""
    fi
done

# ── Summary ────────────────────────────────────────────────
echo "========================================"
echo "STALENESS SUMMARY"
echo "========================================"
echo ""

stale_areas=""

# Check if any dependency files are newer
for f in pyproject.toml package.json go.mod Cargo.toml Gemfile composer.json; do
    if [ -f "$f" ] && [ -n "$CONTEXT_MTIME" ]; then
        dep_mtime=""
        if stat -f '%Sm' "$f" &>/dev/null 2>&1; then
            dep_mtime=$(stat -f '%Sm' -t '%Y-%m-%dT%H:%M:%S' "$f" 2>/dev/null)
        elif stat -c '%y' "$f" &>/dev/null 2>&1; then
            dep_mtime=$(stat -c '%y' "$f" 2>/dev/null | cut -d. -f1)
        fi
        if [ -n "${dep_mtime:-}" ] && [[ "${dep_mtime}" > "${CONTEXT_MTIME}" ]]; then
            stale_areas="${stale_areas}  - Technology Stack & Versions (${f} changed)\n"
        fi
    fi
done

if [ "$missing_count" -gt 0 ]; then
    stale_areas="${stale_areas}  - Architecture & Code Organization ($missing_count referenced files missing)\n"
fi

if [ "$new_count" -gt 0 ]; then
    stale_areas="${stale_areas}  - Architecture & Code Organization ($new_count new directories)\n"
fi

if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    if [ -n "$CONTEXT_MTIME" ]; then
        cc=$(git log --oneline --since="$CONTEXT_MTIME" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$cc" -gt 10 ]; then
            stale_areas="${stale_areas}  - Review Guidance / Common Pitfalls ($cc commits since last update)\n"
        fi
    fi
fi

if [ -n "$stale_areas" ]; then
    echo "Potentially stale sections:"
    echo -e "$stale_areas"
else
    echo "No obvious staleness detected. Context file appears up to date."
fi

echo ""
echo "========================================"
echo "END OF STALENESS REPORT"
echo "========================================"
