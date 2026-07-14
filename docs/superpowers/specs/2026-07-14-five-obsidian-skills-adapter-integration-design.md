# Five Obsidian Skills Adapter Integration Design

## Goal

Add `defuddle`, `json-canvas`, `obsidian-bases`, `obsidian-cli`, and `obsidian-markdown` as first-class Crew skills. Every supported adapter must emit a usable skill bundle, including referenced documentation, and every generated dispatcher must route matching requests to these skills before agent fallback.

## Source of Truth

The five directories under `skills/` become canonical source bundles. `DISPATCHER.md` remains the platform-neutral routing source. The five routing rows in `docs/superpowers/refs/CODEX NEW AGENTS.md` provide the accepted descriptions and trigger vocabulary, but the generated Codex `AGENTS.md` remains adapter output rather than a separately maintained source.

The project skill count changes from 14 to 19. Existing skill ordering remains unchanged; the five additions occupy positions 15 through 19 in this order:

1. `defuddle`
2. `json-canvas`
3. `obsidian-bases`
4. `obsidian-cli`
5. `obsidian-markdown`

## Skill-Bundle Contract

A skill bundle consists of required `SKILL.md` plus these optional resources when present:

- `scripts/`
- `references/`
- `assets/`
- `agents/openai.yaml`

A shared helper in `adapters/lib.sh` copies that contract. This replaces platform drift caused by three adapters copying only `SKILL.md` while Codex already preserves optional resources.

Each adapter keeps its existing destination and platform-specific rewriting:

| Adapter | Destination | Post-copy behavior |
| --- | --- | --- |
| Claude Code | `.claude/skills/<name>/` | Rewrite platform-neutral paths in copied text resources. |
| Gemini CLI | `.gemini/skills/<name>/` | Rewrite platform-neutral paths in copied text resources. |
| OpenCode | `.opencode/skills/<name>/` | Rewrite platform-neutral paths in copied text resources. |
| Codex CLI | `.agents/skills/<name>/` | Retain targeted Codex path and tool-language compatibility rewrites. |

Relative links such as `references/EXAMPLES.md` remain relative and resolve inside every generated skill directory. Unknown extra directories are not copied; expanding the bundle contract remains explicit.

## Runtime Dependencies

No installer gains global package installation or Obsidian configuration behavior.

- `defuddle` checks whether `defuddle` is available before use. When absent, it reports `npm install -g defuddle`; it does not run installation automatically.
- `obsidian-cli` checks whether `obsidian` is available and explains that a running Obsidian instance is required. It reports unmet prerequisites instead of attempting system setup.
- `json-canvas`, `obsidian-bases`, and `obsidian-markdown` operate on vault files using existing platform file and shell capabilities.

These checks belong in skill instructions, keeping installers platform-neutral and avoiding unapproved system changes.

## Routing Data Flow

`DISPATCHER.md` lists all 19 skills and places skill routing before agent routing. Each adapter copies and rewrites this dispatcher into its native root file. A request matching one of the new descriptions or trigger phrases selects the skill in the root conversation; it does not also invoke a fallback agent.

The Codex adapter continues to normalize root-context skill execution and bounded child-agent language. The provided Codex example is used as an acceptance reference for count, five routing rows, skill location, and routing priority—not copied verbatim.

## Error Handling

- Missing required `SKILL.md`: existing adapter behavior skips the directory.
- Missing optional bundle resource: copy helper treats it as absent and continues.
- Copy failure: adapter build fails under existing shell error handling rather than producing a partial success claim.
- Missing runtime CLI: relevant skill stops before running the command and reports the prerequisite.
- Missing running Obsidian instance: `obsidian-cli` reports the runtime requirement without changing user configuration.

## Testing

Implementation follows TDD.

1. Shared adapter tests specify preservation of optional skill resources.
2. Claude, Gemini, OpenCode, and Codex adapter tests verify destination paths and relative references.
3. Codex real-corpus expectations change from 14 to 19 exact skill directories.
4. Four-platform parity builds verify all five `SKILL.md` files and representative references:
   - `json-canvas/references/EXAMPLES.md`
   - `obsidian-bases/references/FUNCTIONS_REFERENCE.md`
   - `obsidian-markdown/references/PROPERTIES.md`
5. Generated dispatchers verify the count `19` and all five routing names.
6. Claude regression snapshot gains all five complete generated bundles.
7. Full repository tests verify no adapter or install/update regression.

## Scope Boundaries

- No automatic npm installation.
- No Obsidian installation, launch, or configuration changes.
- No modification of the five skills' substantive Canvas, Bases, CLI, or Markdown guidance beyond prerequisite handling.
- No new agents or changes to existing agent responsibilities.
- No new MCP server or external service configuration.
