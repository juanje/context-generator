#!/usr/bin/env python3
"""
Validates generated context files against quality criteria.

Usage: python3 scripts/validate_context.py .ai_review/project.md
"""

import sys
import re
from pathlib import Path
from typing import List, Tuple


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ['-h', '--help']:
        print(__doc__)
        print("\nValidation checks:")
        print("- File exists and is readable")
        print("- Has required sections")
        print("- Version dates are present")
        print("- Line count within recommended limits")
        print("- No TODO/FIXME placeholders")
        return

    context_file = Path(sys.argv[1])

    if not context_file.exists():
        print(f"Error: Context file not found: {context_file}")
        sys.exit(1)

    try:
        content = context_file.read_text(encoding='utf-8')
    except Exception as e:
        print(f"Error reading context file: {e}")
        sys.exit(1)

    issues = validate_context(content)

    if issues:
        print(f"❌ Validation failed ({len(issues)} issues):")
        for issue in issues:
            print(f"  - {issue}")
        sys.exit(1)
    else:
        print("✅ Context file validation passed")


def validate_context(content: str) -> List[str]:
    """Validate context file content and return list of issues."""
    issues = []
    lines = content.split('\n')
    line_count = len(lines)

    # Check for required sections
    required_sections = [
        "Project Overview",
        "Technology Stack",
        "Architecture & Code Organization",
        "Review Guidance"
    ]

    for section in required_sections:
        if f"## {section}" not in content:
            issues.append(f"Missing required section: {section}")

    # Check for version date
    if not re.search(r'current as of \d{4}-\d{2}-\d{2}', content):
        issues.append("Technology Stack section should include 'current as of YYYY-MM-DD'")

    # Check line count limits
    if line_count > 500:
        issues.append(f"Content too long: {line_count} lines (recommended: <500)")
    elif line_count > 300:
        issues.append(f"Content lengthy: {line_count} lines (consider moving details to references/)")

    # Check for placeholder content
    placeholders = ['TODO', 'FIXME', 'XXX', '[TBD]', '[PLACEHOLDER]']
    for placeholder in placeholders:
        if placeholder in content:
            issues.append(f"Contains placeholder: {placeholder}")

    # Check that sections have content (not just headers)
    for section in required_sections:
        section_pattern = rf"## {re.escape(section)}(.*?)(?=## |\Z)"
        match = re.search(section_pattern, content, re.DOTALL)
        if match:
            section_content = match.group(1).strip()
            if len(section_content) < 50:  # Minimum meaningful content
                issues.append(f"Section '{section}' appears to have minimal content")

    # Check for overly generic content
    generic_phrases = [
        "follow best practices",
        "handle errors appropriately",
        "use meaningful variable names",
        "write tests for new features"
    ]

    for phrase in generic_phrases:
        if phrase.lower() in content.lower():
            issues.append(f"Contains generic advice: '{phrase}' - should be project-specific")

    return issues


if __name__ == "__main__":
    main()