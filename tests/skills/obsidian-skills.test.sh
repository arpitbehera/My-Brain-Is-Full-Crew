#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

test_five_obsidian_skill_sources_and_references_exist() {
  local result=0
  local file
  for file in \
    skills/defuddle/SKILL.md \
    skills/json-canvas/SKILL.md \
    skills/json-canvas/references/EXAMPLES.md \
    skills/obsidian-bases/SKILL.md \
    skills/obsidian-bases/references/FUNCTIONS_REFERENCE.md \
    skills/obsidian-cli/SKILL.md \
    skills/obsidian-markdown/SKILL.md \
    skills/obsidian-markdown/references/CALLOUTS.md \
    skills/obsidian-markdown/references/EMBEDS.md \
    skills/obsidian-markdown/references/PROPERTIES.md; do
    [[ -s "$ROOT/$file" ]] || { echo "missing or empty canonical skill resource: $file"; result=1; }
  done
  return $result
}

test_five_obsidian_skills_have_valid_frontmatter_and_link_references() {
  local result=0
  local file
  for file in \
    skills/defuddle/SKILL.md \
    skills/json-canvas/SKILL.md \
    skills/obsidian-bases/SKILL.md \
    skills/obsidian-cli/SKILL.md \
    skills/obsidian-markdown/SKILL.md; do
    awk '
      NR == 1 { starts_with_frontmatter = ($0 == "---"); next }
      starts_with_frontmatter && !frontmatter_closed && $0 == "---" { frontmatter_closed = 1; next }
      starts_with_frontmatter && !frontmatter_closed && /^name:[[:space:]]*[^[:space:]]/ { has_name = 1 }
      starts_with_frontmatter && !frontmatter_closed && /^description:[[:space:]]*[^[:space:]]/ { has_description = 1 }
      END { exit !(starts_with_frontmatter && frontmatter_closed && has_name && has_description) }
    ' "$ROOT/$file" || { echo "invalid skill frontmatter: $file"; result=1; }
  done

  local owner
  local reference
  while IFS='|' read -r owner reference; do
    grep -Fq "](references/$reference)" "$ROOT/$owner" \
      || { echo "unlinked skill reference: $owner -> references/$reference"; result=1; }
  done <<'EOF'
skills/json-canvas/SKILL.md|EXAMPLES.md
skills/obsidian-bases/SKILL.md|FUNCTIONS_REFERENCE.md
skills/obsidian-markdown/SKILL.md|CALLOUTS.md
skills/obsidian-markdown/SKILL.md|EMBEDS.md
skills/obsidian-markdown/SKILL.md|PROPERTIES.md
EOF
  return $result
}

test_runtime_cli_skills_stop_and_report_missing_prerequisites() {
  local defuddle="$ROOT/skills/defuddle/SKILL.md"
  local obsidian="$ROOT/skills/obsidian-cli/SKILL.md"
  local result=0

  local defuddle_prerequisite_line
  local defuddle_usage_line
  local obsidian_prerequisite_line
  local obsidian_command_line
  defuddle_prerequisite_line="$(awk '$0 == "## Prerequisite check" { print NR; exit }' "$defuddle")"
  defuddle_usage_line="$(awk '$0 == "## Usage" { print NR; exit }' "$defuddle")"
  obsidian_prerequisite_line="$(awk '$0 == "## Prerequisite check" { print NR; exit }' "$obsidian")"
  obsidian_command_line="$(awk '$0 == "## Command reference" { print NR; exit }' "$obsidian")"

  grep -Fq 'command -v defuddle' "$defuddle" || { echo 'defuddle command check missing'; result=1; }
  grep -Fq 'If the command is missing, stop and report: `npm install -g defuddle`. Do not run the installation command automatically.' "$defuddle" \
    || { echo 'defuddle exact stop/report directive missing'; result=1; }
  [[ "$(grep -Fc 'npm install -g defuddle' "$defuddle")" -eq 1 ]] \
    || { echo 'defuddle install guidance must occur only in the stop/report prerequisite'; result=1; }
  [[ -n "$defuddle_prerequisite_line" && -n "$defuddle_usage_line" && "$defuddle_prerequisite_line" -lt "$defuddle_usage_line" ]] \
    || { echo 'defuddle prerequisite must precede usage examples'; result=1; }

  grep -Fq 'command -v obsidian' "$obsidian" || { echo 'obsidian command check missing'; result=1; }
  grep -Fq 'If the command is missing, stop and report that the Obsidian CLI is required.' "$obsidian" \
    || { echo 'obsidian exact stop-on-missing directive missing'; result=1; }
  grep -Fq 'Do not install or configure it automatically.' "$obsidian" \
    || { echo 'obsidian exact no-install/configure directive missing'; result=1; }
  grep -Fq 'Obsidian must also be open with the target vault available;' "$obsidian" \
    || { echo 'obsidian open target-vault prerequisite missing'; result=1; }
  grep -Fq 'stop and report that requirement without launching or reconfiguring Obsidian.' "$obsidian" \
    || { echo 'obsidian exact no-launch/reconfigure directive missing'; result=1; }
  [[ -n "$obsidian_prerequisite_line" && -n "$obsidian_command_line" && "$obsidian_prerequisite_line" -lt "$obsidian_command_line" ]] \
    || { echo 'obsidian prerequisite must precede command examples'; result=1; }
  return $result
}
