#!/usr/bin/env bash
# Tier 2 unit test for cc-tuned/skills/*/SKILL.md files.
#
# Each cc-tuned skill must:
#   - Start with YAML frontmatter (--- delimiters)
#   - Have a `name:` field matching its directory name
#   - Have a non-empty `description:` field
#   - Body must reference at least one upstream skill (superpowers:<name>)
#     enforcing the "wrap, don't replace" architectural rule

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="${SCRIPT_DIR}/../../skills"
UPSTREAM_SKILLS_DIR="${SCRIPT_DIR}/../../../skills"

fail=0
pass=0

# Collect names of upstream skills for reference-validation (pipe-separated for grep)
upstream_skill_names=$(ls "$UPSTREAM_SKILLS_DIR" 2>/dev/null | tr '\n' '|' | sed 's/|$//')

echo "test-skill-frontmatter.sh"

if [ ! -d "$SKILLS_DIR" ] || [ -z "$(ls -A "$SKILLS_DIR" 2>/dev/null | grep -v '^\.gitkeep$' || true)" ]; then
    echo "  (no cc-tuned skills yet — test passes vacuously)"
    echo "  0 passed, 0 failed"
    exit 0
fi

for skill_dir in "$SKILLS_DIR"/*/; do
    skill_name=$(basename "$skill_dir")
    skill_file="${skill_dir}SKILL.md"

    if [ ! -f "$skill_file" ]; then
        echo "  FAIL: $skill_name has no SKILL.md"
        fail=$((fail + 1))
        continue
    fi

    head_content=$(head -30 "$skill_file")

    # 1. Frontmatter delimiters
    if printf '%s' "$head_content" | grep -qE '^---$'; then
        delim_count=$(printf '%s' "$head_content" | grep -cE '^---$')
        if [ "$delim_count" -ge 2 ]; then
            echo "  pass: $skill_name: frontmatter delimited"
            pass=$((pass + 1))
        else
            echo "  FAIL: $skill_name: missing second --- delimiter"
            fail=$((fail + 1))
        fi
    else
        echo "  FAIL: $skill_name: no frontmatter --- delimiter"
        fail=$((fail + 1))
    fi

    # 2. name: field matches directory
    if printf '%s' "$head_content" | grep -qE "^name:\s*${skill_name}\s*$"; then
        echo "  pass: $skill_name: name field matches directory"
        pass=$((pass + 1))
    else
        echo "  FAIL: $skill_name: name field missing or mismatched"
        fail=$((fail + 1))
    fi

    # 3. description: field present and non-empty
    desc_line=$(printf '%s' "$head_content" | grep -E '^description:' | head -1 || true)
    if [ -n "$desc_line" ]; then
        desc_value=$(printf '%s' "$desc_line" | sed -E 's/^description:\s*//; s/^"//; s/"$//; s/^[[:space:]]*//; s/[[:space:]]*$//')
        if [ -n "$desc_value" ]; then
            echo "  pass: $skill_name: description present and non-empty"
            pass=$((pass + 1))
        else
            echo "  FAIL: $skill_name: description present but empty"
            fail=$((fail + 1))
        fi
    else
        echo "  FAIL: $skill_name: description missing"
        fail=$((fail + 1))
    fi

    # 4. Body references at least one upstream skill via superpowers:<name>
    if [ -n "$upstream_skill_names" ] && grep -qE "superpowers:(${upstream_skill_names})" "$skill_file"; then
        echo "  pass: $skill_name: body references an upstream skill (wrap-don't-replace)"
        pass=$((pass + 1))
    else
        echo "  FAIL: $skill_name: body does not reference any upstream skill (must wrap, not replace)"
        fail=$((fail + 1))
    fi
done

echo
echo "  ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
