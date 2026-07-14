#!/usr/bin/env bash
# =============================================================================
# tests/scripts/platform-parity.test.sh — Four-platform build parity suite
# =============================================================================
# Proves that Codex CLI changes did not regress Claude Code, Gemini CLI,
# OpenCode, or Codex CLI build artifacts.  Runs as part of tests/run.sh.
# =============================================================================
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

_platform_parity_skill_routing_section() {
  local dispatcher="$1"
  awk '
    /^## Skill routing / { in_section=1 }
    /^## Agent routing / { exit }
    in_section
  ' "$dispatcher"
}

# ---------------------------------------------------------------------------
# test_platform_build_matrix_produces_expected_dispatchers_and_roots
#
# Builds all four platforms and asserts each produces the correct dispatcher,
# platform config directory, and at least one canonical agent file.
# ---------------------------------------------------------------------------
test_platform_build_matrix_produces_expected_dispatchers_and_roots() {
  local result=0

  # Platform → expected artifacts map
  # Format: "<dispatcher>|<agent_file>|<config_file>"
  declare -A EXPECTED
  EXPECTED["claude-code"]="dist/claude-code/CLAUDE.md|dist/claude-code/.claude/agents/architect.md|dist/claude-code/.mcp.json"
  EXPECTED["gemini-cli"]="dist/gemini-cli/GEMINI.md|dist/gemini-cli/.gemini/agents/architect.md|dist/gemini-cli/.gemini/settings.json"
  EXPECTED["opencode"]="dist/opencode/AGENTS.md|dist/opencode/.opencode/agents/architect.md|dist/opencode/opencode.json"
  EXPECTED["codex-cli"]="dist/codex-cli/AGENTS.md|dist/codex-cli/.codex/agents/architect.toml|dist/codex-cli/.codex/config.toml"

  for platform in claude-code gemini-cli opencode codex-cli; do
    if ! bash "$ROOT/scripts/build.sh" --platform "$platform" >/dev/null 2>&1; then
      echo "FAIL: build failed for platform: $platform"
      result=1
      continue
    fi

    IFS='|' read -r dispatcher agent_file config_file <<< "${EXPECTED[$platform]}"

    [[ -f "$ROOT/$dispatcher" ]] \
      || { echo "FAIL [$platform]: dispatcher missing: $dispatcher"; result=1; }
    [[ -f "$ROOT/$agent_file" ]] \
      || { echo "FAIL [$platform]: agent file missing: $agent_file"; result=1; }
    [[ -f "$ROOT/$config_file" ]] \
      || { echo "FAIL [$platform]: config file missing: $config_file"; result=1; }
  done

  # Additional Codex-specific: skills directory
  [[ -f "$ROOT/dist/codex-cli/.agents/skills/onboarding/SKILL.md" ]] \
    || { echo "FAIL [codex-cli]: .agents/skills/onboarding/SKILL.md missing"; result=1; }

  return $result
}

# ---------------------------------------------------------------------------
# test_platform_build_matrix_preserves_obsidian_skill_bundles_and_routing
#
# Builds all four platforms and asserts each preserves the five Obsidian skill
# bundles, their representative references, and dispatcher routing entries.
# ---------------------------------------------------------------------------
test_platform_build_matrix_preserves_obsidian_skill_bundles_and_routing() {
  local result=0
  local skills=(defuddle json-canvas obsidian-bases obsidian-cli obsidian-markdown)
  local expected_rows=(
    '| 15 | `/defuddle` | Extract clean Markdown from web pages, removing navigation and page clutter before reading or saving content. | EN: URL to read/analyze, online docs, articles, blog posts, standard web pages, "extract this page", "clean markdown from this URL" |'
    '| 16 | `/json-canvas` | Create and edit Obsidian JSON Canvas files with nodes, edges, groups, and visual connections. | EN: ".canvas file", "Canvas file", "create a canvas", "edit canvas", "mind map", "flowchart", "visual canvas", "connect canvas nodes" |'
    '| 17 | `/obsidian-bases` | Create and edit Obsidian Bases with views, filters, formulas, summaries, and database-like note views. | EN: ".base file", "Bases", "table view", "card view", "list view", "map view", "filters", "formulas", "database view", "note database" |'
    '| 18 | `/obsidian-cli` | Interact with a running Obsidian vault from the command line: read, create, search, manage notes/tasks/properties, and debug plugins/themes. | EN: "use Obsidian CLI", "search vault with CLI", "create note with CLI", "manage notes", "manage tasks", "reload plugin", "run JavaScript in Obsidian", "capture Obsidian errors", "inspect DOM" |'
    '| 19 | `/obsidian-markdown` | Create and edit Obsidian Flavored Markdown including wikilinks, embeds, callouts, properties, tags, comments, math, and Mermaid. | EN: ".md file in Obsidian", "wikilink", "embed", "callout", "frontmatter", "properties", "tags", "Obsidian note", "format this note" |'
  )
  local platform skill skill_root dispatcher reference build_log
  local skill_section routing_prefix skill_line agent_line idx
  local -a actual_rows

  for platform in claude-code gemini-cli opencode codex-cli; do
    build_log="$(mktemp)"
    if ! bash "$ROOT/scripts/build.sh" --platform "$platform" >"$build_log" 2>&1; then
      echo "FAIL: build failed for platform: $platform"
      sed 's/^/  /' "$build_log"
      rm -f "$build_log"
      result=1
      continue
    fi
    rm -f "$build_log"

    case "$platform" in
      claude-code)
        skill_root="$ROOT/dist/claude-code/.claude/skills"
        dispatcher="$ROOT/dist/claude-code/CLAUDE.md"
        ;;
      gemini-cli)
        skill_root="$ROOT/dist/gemini-cli/.gemini/skills"
        dispatcher="$ROOT/dist/gemini-cli/GEMINI.md"
        ;;
      opencode)
        skill_root="$ROOT/dist/opencode/.opencode/skills"
        dispatcher="$ROOT/dist/opencode/AGENTS.md"
        ;;
      codex-cli)
        skill_root="$ROOT/dist/codex-cli/.agents/skills"
        dispatcher="$ROOT/dist/codex-cli/AGENTS.md"
        ;;
    esac

    for skill in "${skills[@]}"; do
      [[ -f "$skill_root/$skill/SKILL.md" ]] \
        || { echo "FAIL [$platform]: missing $skill/SKILL.md"; result=1; }
      grep -Fq "/$skill" "$dispatcher" \
        || { echo "FAIL [$platform]: dispatcher missing /$skill"; result=1; }
    done

    grep -Fq '**19 skills**' "$dispatcher" \
      || { echo "FAIL [$platform]: dispatcher missing **19 skills**"; result=1; }

    skill_line="$(grep -nFm1 '## Skill routing ' "$dispatcher" | cut -d: -f1)"
    agent_line="$(grep -nFm1 '## Agent routing ' "$dispatcher" | cut -d: -f1)"
    if [[ -z "$skill_line" || -z "$agent_line" || "$skill_line" -ge "$agent_line" ]]; then
      echo "FAIL [$platform]: Skill routing section must precede Agent routing"
      result=1
    else
      skill_section="$(_platform_parity_skill_routing_section "$dispatcher")"
      mapfile -t actual_rows < <(grep -E '^\| (15|16|17|18|19) \|' <<< "$skill_section")
      [[ "${#actual_rows[@]}" -eq "${#expected_rows[@]}" ]] \
        || { echo "FAIL [$platform]: expected ${#expected_rows[@]} exact Obsidian routing rows in Skill routing, found ${#actual_rows[@]}"; result=1; }
      for idx in "${!expected_rows[@]}"; do
        [[ "${actual_rows[$idx]:-missing}" == "${expected_rows[$idx]}" ]] \
          || { echo "FAIL [$platform]: routing row $((idx + 15)) differs or is out of order"; result=1; }
      done

      routing_prefix="$(sed -n "1,$((agent_line - 1))p" "$dispatcher")"
      [[ "$routing_prefix" == *'**Skills FIRST, agents SECOND.**'* ]] \
        || { echo "FAIL [$platform]: Skills FIRST contract missing before Agent routing"; result=1; }
      [[ "$routing_prefix" == *'STOP — do not also invoke an agent.'* ]] \
        || { echo "FAIL [$platform]: skill-match STOP contract missing before Agent routing"; result=1; }
    fi

    for reference in \
      json-canvas/references/EXAMPLES.md \
      obsidian-bases/references/FUNCTIONS_REFERENCE.md \
      obsidian-markdown/references/PROPERTIES.md; do
      [[ -f "$skill_root/$reference" ]] \
        || { echo "FAIL [$platform]: missing $reference"; result=1; }
    done
  done

  return $result
}

test_source_dispatcher_resolves_obsidian_skill_trigger_overlap() {
  local routing; routing="$(_platform_parity_skill_routing_section "$ROOT/DISPATCHER.md")"
  local result=0

  [[ "$routing" == *'Select by the requested output artifact or operation, not incidental input or source terms.'* ]] \
    || { echo 'FAIL: dispatcher does not prioritize requested output over incidental terms'; result=1; }
  [[ "$routing" == *'`.canvas` or Obsidian Canvas → `/json-canvas`; Mermaid inside an Obsidian `.md` note → `/obsidian-markdown`.'* ]] \
    || { echo 'FAIL: dispatcher does not resolve Canvas and Mermaid overlap'; result=1; }
  [[ "$routing" == *'A URL ending in `.md` is direct Markdown retrieval, not Defuddle.'* ]] \
    || { echo 'FAIL: dispatcher does not exclude direct .md URLs from Defuddle'; result=1; }
  [[ "$routing" == *'When terms overlap, choose the single best skill using these qualifiers, then STOP. Do not chain or fall back to an agent.'* ]] \
    || { echo 'FAIL: dispatcher does not stop after resolving overlapping skill terms'; result=1; }

  return $result
}

# ---------------------------------------------------------------------------
# test_claude_snapshot_regression_still_passes_after_codex_changes
#
# Runs the Claude Code snapshot regression test.  Fails immediately if the
# snapshot diff reports any drift — Codex changes must not touch Claude output.
# ---------------------------------------------------------------------------
test_claude_snapshot_regression_still_passes_after_codex_changes() {
  local log; log="$(mktemp)"
  if ! bash "$ROOT/tests/regression/run.sh" >"$log" 2>&1; then
    echo "FAIL: Claude snapshot regression reported drift:"
    cat "$log"
    rm -f "$log"
    return 1
  fi
  rm -f "$log"
  return 0
}

# ---------------------------------------------------------------------------
# test_codex_install_update_gate_remains_in_the_full_suite
#
# Asserts that the Codex CLI install/update test file still exists and
# defines both required test function names.  This gate ensures the parity
# suite does not accidentally exclude Codex install regression coverage.
# ---------------------------------------------------------------------------
test_codex_install_update_gate_remains_in_the_full_suite() {
  local install_test="$ROOT/tests/scripts/codex-cli-install.test.sh"
  local result=0

  [[ -f "$install_test" ]] \
    || { echo "FAIL: tests/scripts/codex-cli-install.test.sh does not exist"; return 1; }

  grep -q 'test_launchme_installs_codex_cli_layout' "$install_test" \
    || { echo "FAIL: test_launchme_installs_codex_cli_layout not found in codex-cli-install.test.sh"; result=1; }
  grep -q 'test_updateme_auto_detects_and_refreshes_codex_cli_install' "$install_test" \
    || { echo "FAIL: test_updateme_auto_detects_and_refreshes_codex_cli_install not found in codex-cli-install.test.sh"; result=1; }

  return $result
}
