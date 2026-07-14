# Codex GPT-5.6 Model Routing Design

## Goal

Update the Codex CLI adapter so each existing abstract model tier uses its corresponding GPT-5.6 model at high reasoning effort.

## Routing

| Source tier | Generated profile | Model | Reasoning effort | Rationale |
| --- | --- | --- | --- | --- |
| `high` | `quality` | `gpt-5.6-sol` | `high` | Sol is the flagship GPT-5.6 model, matching quality-first work. |
| `mid` | `balanced` | `gpt-5.6-terra` | `high` | Terra balances intelligence and model price while high effort preserves strong reasoning. |
| `low` | `budget` | `gpt-5.6-luna` | `high` | Luna targets efficient, high-volume work; high effort favors reasoning quality within that model tier. |

The repository keeps `mid` as its canonical tier. It will not add a `medium` alias.

High reasoning effort for `mid` and `low` intentionally changes the prior GPT-5.5 behavior, which used low effort for those tiers. This can increase latency and token use, but follows the requested quality bias. Model selection still differentiates the capability and cost tiers.

## Adapter Changes

`adapters/codex-cli/adapter.sh` remains the single translation boundary.

- Generated Codex profiles use sol, terra, and luna for `quality`, `balanced`, and `budget` respectively.
- `_cc_model_to_codex` maps abstract tiers directly to their GPT-5.6 counterparts.
- Legacy tier-equivalent model identifiers migrate consistently:
  - `gpt-5.4` to `gpt-5.6-sol`
  - `gpt-5.4-mini` to `gpt-5.6-terra`
  - `gpt-5.3-codex-spark` to `gpt-5.6-luna`
- `_cc_model_reasoning_effort` returns `high` for the three abstract tiers and three legacy identifiers.
- Other explicit `gpt-*` and provider-qualified model identifiers retain existing passthrough behavior. This includes explicit GPT-5.5 identifiers; only abstract and recognized legacy routes are migrated.

No new helper or routing table is introduced. Direct case mappings match the existing shell adapter structure and keep the change narrow.

## Data Flow

Agent frontmatter supplies `model: high`, `model: mid`, or `model: low`. The adapter resolves the model identifier and reasoning effort independently, then writes both into generated Codex agent TOML. Config translation writes the same choices into named profiles, keeping profile output and agent output aligned.

Unknown abstract values retain current passthrough behavior. The adapter does not validate remote model availability; Codex reports unsupported explicit model identifiers at runtime.

## Testing

Tests will be changed before production code and observed failing against the GPT-5.5 implementation.

- Unit-level shell assertions cover all three abstract tiers, all three legacy identifiers, and passthrough behavior.
- Generated-config assertions cover the three profile model and effort pairs.
- Agent translation coverage verifies CRLF frontmatter still produces luna with high effort.
- Real-corpus coverage verifies a high-tier agent uses sol and a mid-tier agent uses terra, both at high effort. The synthetic CRLF case covers the low-to-luna route.
- The focused Codex adapter suite runs after implementation, followed by the repository's full test suite and diff checks.

## Source Guidance

OpenAI's GPT-5.6 guide describes sol as the flagship model, terra as the intelligence-and-cost balance, and luna as the efficient high-volume option. It recommends beginning migrations with the existing reasoning effort, then benchmarking lower effort. This design deliberately uses high effort for every tier per project requirement.

Source: <https://developers.openai.com/api/docs/guides/latest-model>
