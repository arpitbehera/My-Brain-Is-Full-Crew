# Five Obsidian Skills Adapter Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship five canonical Obsidian skill bundles through every adapter, preserve their optional resources, route matching requests before agent fallback, and report missing runtime CLIs without installing anything.

**Architecture:** `adapters/lib.sh` owns one allowlisted bundle copier plus one platform-path rewriter for copied text files. Each adapter retains its destination and platform-specific compatibility pass, while `DISPATCHER.md` remains the single routing source. Shell tests cover helper behavior, adapter output, exact Codex corpus, four-platform parity, runtime prerequisites, and the Claude regression snapshot.

**Tech Stack:** Bash, POSIX command-line tools, repository shell test runner, Markdown/YAML skill bundles.

---

### Task 1: Lock canonical skill and runtime prerequisite contracts

**Files:**
- Create: `tests/skills/obsidian-skills.test.sh`
- Add: `skills/defuddle/SKILL.md`
- Add: `skills/json-canvas/SKILL.md`
- Add: `skills/json-canvas/references/EXAMPLES.md`
- Add: `skills/obsidian-bases/SKILL.md`
- Add: `skills/obsidian-bases/references/FUNCTIONS_REFERENCE.md`
- Add: `skills/obsidian-cli/SKILL.md`
- Add: `skills/obsidian-markdown/SKILL.md`
- Add: `skills/obsidian-markdown/references/CALLOUTS.md`
- Add: `skills/obsidian-markdown/references/EMBEDS.md`
- Add: `skills/obsidian-markdown/references/PROPERTIES.md`

- [ ] **Step 1: Write failing source-contract tests**

Create `tests/skills/obsidian-skills.test.sh`:

```bash
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
    [[ -f "$ROOT/$file" ]] || { echo "missing canonical skill resource: $file"; result=1; }
  done
  return $result
}

test_runtime_cli_skills_stop_and_report_missing_prerequisites() {
  local defuddle="$ROOT/skills/defuddle/SKILL.md"
  local obsidian="$ROOT/skills/obsidian-cli/SKILL.md"
  local result=0

  grep -Fq 'command -v defuddle' "$defuddle" || { echo 'defuddle command check missing'; result=1; }
  grep -Fq 'npm install -g defuddle' "$defuddle" || { echo 'defuddle install guidance missing'; result=1; }
  grep -Eqi 'do not (run|install)|never (run|install)|does not install' "$defuddle" \
    || { echo 'defuddle no-auto-install rule missing'; result=1; }

  grep -Fq 'command -v obsidian' "$obsidian" || { echo 'obsidian command check missing'; result=1; }
  grep -Eqi 'stop|do not continue|before running' "$obsidian" \
    || { echo 'obsidian stop-on-missing rule missing'; result=1; }
  grep -Eqi 'running Obsidian|Obsidian (must|needs to) be (open|running)' "$obsidian" \
    || { echo 'running Obsidian prerequisite missing'; result=1; }
  return $result
}
```

- [ ] **Step 2: Run tests and verify prerequisite contract fails**

Run:

```bash
rtk bash -c 'source tests/skills/obsidian-skills.test.sh; test_runtime_cli_skills_stop_and_report_missing_prerequisites'
```

Expected: FAIL with `defuddle command check missing` and `obsidian command check missing`.

- [ ] **Step 3: Add explicit non-mutating prerequisite instructions**

Add before Defuddle usage examples:

````markdown
## Prerequisite check

Before every use, verify the CLI is available:

```bash
command -v defuddle
```

If the command is missing, stop and report: `npm install -g defuddle`. Do not run the installation command automatically.
````

Add before Obsidian command examples:

````markdown
## Prerequisite check

Before every use, verify the CLI is available:

```bash
command -v obsidian
```

If the command is missing, stop and report that the Obsidian CLI is required. Do not install or configure it automatically. Obsidian must also be open with the target vault available; if the CLI reports that no running instance is available, stop and report that requirement without launching or reconfiguring Obsidian.
````

- [ ] **Step 4: Run source-contract tests**

Run:

```bash
rtk bash -c 'source tests/skills/obsidian-skills.test.sh; test_five_obsidian_skill_sources_and_references_exist; test_runtime_cli_skills_stop_and_report_missing_prerequisites'
```

Expected: PASS.

- [ ] **Step 5: Commit canonical sources and prerequisite tests**

```bash
rtk git add tests/skills/obsidian-skills.test.sh skills/defuddle skills/json-canvas skills/obsidian-bases skills/obsidian-cli skills/obsidian-markdown
rtk git commit -m "feat: add Obsidian skill sources"
```

### Task 2: Add shared skill-bundle copy and rewrite helpers

**Files:**
- Modify: `adapters/lib.sh`
- Modify: `tests/adapters/lib.test.sh`

- [ ] **Step 1: Write failing helper tests**

Append tests that create `SKILL.md`, `scripts/`, `references/`, `assets/`, `agents/openai.yaml`, and `extra/ignored.txt`; assert the allowlisted resources are copied, `extra/` is absent, and platform-neutral paths are rewritten in copied text files:

```bash
test_copy_skill_bundle_preserves_only_supported_resources() {
  local src; src="$(mktemp -d)"
  local dst; dst="$(mktemp -d)/fixture"
  mkdir -p "$src/scripts" "$src/references" "$src/assets" "$src/agents" "$src/extra"
  printf '%s\n' 'Use .platform/skills/fixture/ and DISPATCHER.md.' > "$src/SKILL.md"
  printf '%s\n' '#!/usr/bin/env bash' 'echo .platform/agents/example.md' > "$src/scripts/run.sh"
  printf '%s\n' 'See .platform/references/guide.md.' > "$src/references/guide.md"
  printf '%s\n' 'See DISPATCHER.md.' > "$src/assets/template.md"
  printf '%s\n' 'instruction: "Read .platform/references/guide.md"' > "$src/agents/openai.yaml"
  printf '%s\n' 'ignored' > "$src/extra/ignored.txt"

  copy_skill_bundle "$src" "$dst"

  local result=0
  [[ -f "$dst/SKILL.md" ]] || { echo 'SKILL.md missing'; result=1; }
  [[ -f "$dst/scripts/run.sh" ]] || { echo 'script missing'; result=1; }
  [[ -f "$dst/references/guide.md" ]] || { echo 'reference missing'; result=1; }
  [[ -f "$dst/assets/template.md" ]] || { echo 'asset missing'; result=1; }
  [[ -f "$dst/agents/openai.yaml" ]] || { echo 'openai.yaml missing'; result=1; }
  [[ ! -e "$dst/extra" ]] || { echo 'unsupported extra directory copied'; result=1; }
  rm -rf "$src" "$(dirname "$dst")"
  return $result
}

test_rewrite_skill_bundle_platform_paths_rewrites_text_tree() {
  local root; root="$(mktemp -d)"
  mkdir -p "$root/references" "$root/assets" "$root/agents"
  printf '%s\n' '.platform/skills/fixture/ DISPATCHER.md' > "$root/SKILL.md"
  printf '%s\n' '.platform/references/guide.md' > "$root/references/guide.md"
  printf '%s\n' '.platform/agents/example.md' > "$root/assets/template.md"
  printf '%s\n' 'instruction: DISPATCHER.md' > "$root/agents/openai.yaml"

  rewrite_skill_bundle_platform_paths "$root" "gemini" "GEMINI.md"

  local result=0
  grep -RIl '.platform/\|DISPATCHER.md' "$root" | grep -q . \
    && { echo 'platform-neutral path leaked'; result=1; }
  grep -Fq '.gemini/references/guide.md' "$root/references/guide.md" \
    || { echo 'reference path not rewritten'; result=1; }
  grep -Fq 'GEMINI.md' "$root/agents/openai.yaml" \
    || { echo 'dispatcher path not rewritten'; result=1; }
  rm -rf "$root"
  return $result
}
```

- [ ] **Step 2: Run helper tests and verify missing-function failures**

Run:

```bash
rtk bash -c 'source tests/adapters/lib.test.sh; test_copy_skill_bundle_preserves_only_supported_resources'
rtk bash -c 'source tests/adapters/lib.test.sh; test_rewrite_skill_bundle_platform_paths_rewrites_text_tree'
```

Expected: FAIL with `copy_skill_bundle: command not found` and `rewrite_skill_bundle_platform_paths: command not found`.

- [ ] **Step 3: Implement minimal shared helpers**

Add to `adapters/lib.sh` after `rewrite_platform_paths`:

```bash
copy_skill_bundle() {
  local src="$1" dst="$2"
  [[ -f "$src/SKILL.md" ]] || return 1
  mkdir -p "$dst"
  cp "$src/SKILL.md" "$dst/SKILL.md"

  local dir
  for dir in scripts references assets; do
    if [[ -d "$src/$dir" ]]; then
      mkdir -p "$dst/$dir"
      cp -R "$src/$dir/." "$dst/$dir/"
    fi
  done

  if [[ -f "$src/agents/openai.yaml" ]]; then
    mkdir -p "$dst/agents"
    cp "$src/agents/openai.yaml" "$dst/agents/openai.yaml"
  fi
}

rewrite_skill_bundle_platform_paths() {
  local root="$1" platform_dir="$2" dispatcher="$3"
  [[ -d "$root" ]] || return 0

  while IFS= read -r -d '' file; do
    grep -Iq . "$file" || continue
    rewrite_platform_paths "$file" "$platform_dir" "$dispatcher"
  done < <(find "$root" -type f -print0)
}
```

- [ ] **Step 4: Run helper tests and full shared-library tests**

Run:

```bash
rtk bash -c 'source tests/adapters/lib.test.sh; test_copy_skill_bundle_preserves_only_supported_resources; test_rewrite_skill_bundle_platform_paths_rewrites_text_tree'
rtk bash tests/run.sh
```

Expected: helper tests PASS; full suite may still fail only at known adapter parity/snapshot expectations addressed below.

- [ ] **Step 5: Commit helper seam**

```bash
rtk git add adapters/lib.sh tests/adapters/lib.test.sh
rtk git commit -m "feat: add shared skill bundle copier"
```

### Task 3: Route all four adapters through the bundle contract

**Files:**
- Modify: `adapters/claude-code/adapter.sh`
- Modify: `adapters/gemini-cli/adapter.sh`
- Modify: `adapters/opencode/adapter.sh`
- Modify: `adapters/codex-cli/adapter.sh`
- Modify: `tests/adapters/claude-code/adapter.test.sh`
- Modify: `tests/adapters/gemini-cli/adapter.test.sh`
- Modify: `tests/adapters/opencode/adapter.test.sh`
- Modify: `tests/adapters/codex-cli/adapter.test.sh`

- [ ] **Step 1: Expand each adapter skill test to require optional resources**

For each adapter fixture, add `references/guide.md`, `assets/template.md`, `scripts/run.sh`, and `agents/openai.yaml`. Assert platform-specific destinations exist and `.platform/` plus `DISPATCHER.md` do not remain in copied text. Preserve Codex's existing test for targeted tool-language rewrites.

Representative assertions for Claude Code:

```bash
[[ -f "$dst/.claude/skills/foo/references/guide.md" ]] || { echo 'reference missing'; result=1; }
[[ -f "$dst/.claude/skills/foo/assets/template.md" ]] || { echo 'asset missing'; result=1; }
[[ -f "$dst/.claude/skills/foo/scripts/run.sh" ]] || { echo 'script missing'; result=1; }
[[ -f "$dst/.claude/skills/foo/agents/openai.yaml" ]] || { echo 'openai.yaml missing'; result=1; }
grep -RIl '.platform/\|DISPATCHER.md' "$dst/.claude/skills/foo" | grep -q . \
  && { echo 'neutral path leaked from Claude bundle'; result=1; }
```

Use `.gemini/skills/foo`, `.opencode/skills/foo`, and `.agents/skills/foo` for the other adapters.

- [ ] **Step 2: Run adapter tests and verify Claude/Gemini/OpenCode fail on missing resources**

Run:

```bash
rtk bash tests/run.sh
```

Expected: new optional-resource assertions fail for Claude Code, Gemini CLI, and OpenCode; Codex remains green.

- [ ] **Step 3: Replace per-adapter SKILL-only copies with shared helper calls**

Claude Code loop body:

```bash
local out="$dst/.claude/skills/$name"
copy_skill_bundle "$skill_dir" "$out"
rewrite_skill_bundle_platform_paths "$out" "$CC_FW_DIR" "$CC_DISPATCHER"
```

Gemini CLI loop body:

```bash
local out="$dst/.$GEMINI_FW_DIR/skills/$name"
copy_skill_bundle "$skill_dir" "$out"
rewrite_skill_bundle_platform_paths "$out" "$GEMINI_FW_DIR" "$GEMINI_DISPATCHER"
```

OpenCode loop body:

```bash
local out="$dst/.opencode/skills/$name"
copy_skill_bundle "$skill_dir" "$out"
rewrite_skill_bundle_platform_paths "$out" "$OC_FW_DIR" "$OC_DISPATCHER"
```

Codex loop body:

```bash
local out="$dst/.agents/skills/$name"
copy_skill_bundle "$skill_dir" "$out"
_cc_rewrite_skill_text_tree "$name" "$out"
```

- [ ] **Step 4: Run adapter unit tests**

Run:

```bash
rtk bash tests/run.sh
```

Expected: adapter bundle tests PASS; failures remaining only for dispatcher count/routing and intentional Claude snapshot drift.

- [ ] **Step 5: Commit adapter integration**

```bash
rtk git add adapters/lib.sh adapters/claude-code/adapter.sh adapters/gemini-cli/adapter.sh adapters/opencode/adapter.sh adapters/codex-cli/adapter.sh tests/adapters
rtk git commit -m "feat: preserve skill bundles across adapters"
```

### Task 4: Add 19-skill routing and exact Codex corpus expectations

**Files:**
- Modify: `DISPATCHER.md`
- Modify: `tests/adapters/codex-cli/adapter.test.sh`
- Modify: `tests/scripts/platform-parity.test.sh`

- [ ] **Step 1: Write failing routing/parity assertions**

Add a parity test that builds all adapters and checks every new bundle plus representative references and generated dispatcher content:

```bash
test_platform_build_matrix_preserves_obsidian_skill_bundles_and_routing() {
  local result=0
  local platform skill_root dispatcher skill
  local skills=(defuddle json-canvas obsidian-bases obsidian-cli obsidian-markdown)

  for platform in claude-code gemini-cli opencode codex-cli; do
    bash "$ROOT/scripts/build.sh" --platform "$platform" >/dev/null 2>&1 \
      || { echo "FAIL [$platform]: build failed"; result=1; continue; }
    case "$platform" in
      claude-code) skill_root="$ROOT/dist/$platform/.claude/skills"; dispatcher="$ROOT/dist/$platform/CLAUDE.md" ;;
      gemini-cli)  skill_root="$ROOT/dist/$platform/.gemini/skills"; dispatcher="$ROOT/dist/$platform/GEMINI.md" ;;
      opencode)    skill_root="$ROOT/dist/$platform/.opencode/skills"; dispatcher="$ROOT/dist/$platform/AGENTS.md" ;;
      codex-cli)   skill_root="$ROOT/dist/$platform/.agents/skills"; dispatcher="$ROOT/dist/$platform/AGENTS.md" ;;
    esac

    for skill in "${skills[@]}"; do
      [[ -f "$skill_root/$skill/SKILL.md" ]] \
        || { echo "FAIL [$platform]: $skill/SKILL.md missing"; result=1; }
      grep -Fq "/$skill" "$dispatcher" \
        || { echo "FAIL [$platform]: $skill routing row missing"; result=1; }
    done

    grep -Fq '**19 skills**' "$dispatcher" \
      || { echo "FAIL [$platform]: 19-skill count missing"; result=1; }
    [[ -f "$skill_root/json-canvas/references/EXAMPLES.md" ]] \
      || { echo "FAIL [$platform]: JSON Canvas reference missing"; result=1; }
    [[ -f "$skill_root/obsidian-bases/references/FUNCTIONS_REFERENCE.md" ]] \
      || { echo "FAIL [$platform]: Bases reference missing"; result=1; }
    [[ -f "$skill_root/obsidian-markdown/references/PROPERTIES.md" ]] \
      || { echo "FAIL [$platform]: Markdown reference missing"; result=1; }
  done
  return $result
}
```

Update the Codex exact-corpus array with the five names in alphabetical order and change expected count from 14 to 19.

- [ ] **Step 2: Run parity test and verify dispatcher assertions fail**

Run:

```bash
rtk bash -c 'source tests/scripts/platform-parity.test.sh; test_platform_build_matrix_preserves_obsidian_skill_bundles_and_routing'
```

Expected: FAIL because generated dispatchers still say `14 skills` and lack five routing rows.

- [ ] **Step 3: Update source dispatcher count and routing rows**

Change the count to `19 skills`. Append rows 15-19, preserving accepted order and vocabulary from `docs/superpowers/refs/CODEX NEW AGENTS.md`:

```markdown
| 15 | `/defuddle` | Extract clean Markdown from web pages, removing navigation and page clutter before reading or saving content. | EN: URL to read/analyze, online docs, articles, blog posts, standard web pages, "extract this page", "clean markdown from this URL" |
| 16 | `/json-canvas` | Create and edit Obsidian JSON Canvas files with nodes, edges, groups, and visual connections. | EN: ".canvas file", "Canvas file", "create a canvas", "edit canvas", "mind map", "flowchart", "visual canvas", "connect canvas nodes" |
| 17 | `/obsidian-bases` | Create and edit Obsidian Bases with views, filters, formulas, summaries, and database-like note views. | EN: ".base file", "Bases", "table view", "card view", "list view", "map view", "filters", "formulas", "database view", "note database" |
| 18 | `/obsidian-cli` | Interact with a running Obsidian vault from the command line: read, create, search, manage notes/tasks/properties, and debug plugins/themes. | EN: "use Obsidian CLI", "search vault with CLI", "create note with CLI", "manage notes", "manage tasks", "reload plugin", "run JavaScript in Obsidian", "capture Obsidian errors", "inspect DOM" |
| 19 | `/obsidian-markdown` | Create and edit Obsidian Flavored Markdown including wikilinks, embeds, callouts, properties, tags, comments, math, and Mermaid. | EN: ".md file in Obsidian", "wikilink", "embed", "callout", "frontmatter", "properties", "tags", "Obsidian note", "format this note" |
```

Keep the existing `Skills FIRST, agents SECOND` rule and skill-match `STOP` behavior unchanged.

- [ ] **Step 4: Run Codex corpus and four-platform parity tests**

Run:

```bash
rtk bash -c 'source tests/adapters/codex-cli/adapter.test.sh; test_cc_translate_skills_real_corpus_has_exact_skill_directories'
rtk bash -c 'source tests/scripts/platform-parity.test.sh; test_platform_build_matrix_preserves_obsidian_skill_bundles_and_routing'
```

Expected: PASS.

- [ ] **Step 5: Commit routing and corpus expectations**

```bash
rtk git add DISPATCHER.md tests/adapters/codex-cli/adapter.test.sh tests/scripts/platform-parity.test.sh
rtk git commit -m "feat: route five Obsidian skills"
```

### Task 5: Refresh intentional Claude regression output

**Files:**
- Modify: `tests/regression/snapshot/CLAUDE.md`
- Create: `tests/regression/snapshot/.claude/skills/defuddle/SKILL.md`
- Create: `tests/regression/snapshot/.claude/skills/json-canvas/`
- Create: `tests/regression/snapshot/.claude/skills/obsidian-bases/`
- Create: `tests/regression/snapshot/.claude/skills/obsidian-cli/SKILL.md`
- Create: `tests/regression/snapshot/.claude/skills/obsidian-markdown/`

- [ ] **Step 1: Run regression test and verify intentional drift**

Run:

```bash
rtk bash tests/regression/run.sh
```

Expected: FAIL showing five new skill bundles and dispatcher routing/count changes.

- [ ] **Step 2: Regenerate snapshot from clean feature workspace**

Run:

```bash
rtk bash tests/regression/take-snapshot.sh
```

Expected: snapshot lists all five complete Claude skill bundles, including representative references.

- [ ] **Step 3: Verify snapshot scope**

Run:

```bash
rtk git diff --stat -- tests/regression/snapshot
rtk git diff -- tests/regression/snapshot/CLAUDE.md
rtk proxy find tests/regression/snapshot/.claude/skills/defuddle \
  tests/regression/snapshot/.claude/skills/json-canvas \
  tests/regression/snapshot/.claude/skills/obsidian-bases \
  tests/regression/snapshot/.claude/skills/obsidian-cli \
  tests/regression/snapshot/.claude/skills/obsidian-markdown -type f -print
```

Expected: only dispatcher changes and five new generated bundles; no unrelated snapshot drift.

- [ ] **Step 4: Run regression test**

Run:

```bash
rtk bash tests/regression/run.sh
```

Expected: PASS with `File lists match.` and `PASS: dist matches snapshot`.

- [ ] **Step 5: Commit snapshot**

```bash
rtk git add tests/regression/snapshot
rtk git commit -m "test: refresh Claude skill snapshot"
```

### Task 6: Full verification and spec audit

**Files:**
- Verify all files changed by Tasks 1-5.

- [ ] **Step 1: Run shell syntax checks**

```bash
rtk bash -n adapters/lib.sh adapters/claude-code/adapter.sh adapters/gemini-cli/adapter.sh adapters/opencode/adapter.sh adapters/codex-cli/adapter.sh tests/skills/obsidian-skills.test.sh tests/scripts/platform-parity.test.sh
```

Expected: exit 0, no output.

- [ ] **Step 2: Run complete test suite**

```bash
rtk bash tests/run.sh
```

Expected: `Failed: 0`.

- [ ] **Step 3: Build all supported adapters**

```bash
rtk bash scripts/build.sh --platform claude-code
rtk bash scripts/build.sh --platform gemini-cli
rtk bash scripts/build.sh --platform opencode
rtk bash scripts/build.sh --platform codex-cli
```

Expected: all four commands exit 0.

- [ ] **Step 4: Audit scope and requirements**

```bash
rtk git diff --check HEAD~4..HEAD
rtk git status --short
rtk git log --oneline -5
```

Confirm: 19 routes; five canonical bundles; allowlisted optional resources only; no npm install execution; no Obsidian setup; no new agents/MCP configuration; no unrelated files.

- [ ] **Step 5: Request spec and code-quality review**

Review the complete branch against `docs/superpowers/specs/2026-07-14-five-obsidian-skills-adapter-integration-design.md`. Fix every Critical or Important issue, rerun affected tests, then rerun `rtk bash tests/run.sh`.

- [ ] **Step 6: Commit review fixes if needed**

```bash
rtk git add adapters DISPATCHER.md skills tests
rtk git commit -m "fix: address Obsidian skill review"
```
