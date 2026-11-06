# 04 — Bundle map

What every file is. Read `README.md` first.

The numbered docs at the repository root are the same files as
`geo-audit-handover/` inside `audit-handover.zip`, including `02-running-an-audit.md`
and `06-llm-identity.md`. `skill/SKILL.md` matches root `SKILL.md`.
`engine/Audit-SKILL.md` matches root `Audit-SKILL.md`. Change both copies, then
rebuild the zip, so they do not drift. The engine code lives in the zip.

## State of the bundle

**Standalone.** The project lives in `~/Claude Projects/audit-handover/`, with
`engine/`, `skill/` and these docs side by side. Nothing outside that folder is
needed except the DataForSEO keys in `engine/.env`. Earlier copies in
`~/Downloads/geo-audit-bundle/` and `~/Dev Projects/geo-audit-full/workspace`
are superseded.

Reconciled against the working engine at
`~/Dev Projects/geo-audit-full/workspace` and cleaned up on 2026-09-14.

**Restored** (were missing or stale here): `scripts/audit-one.js`,
`scripts/normalize_aio.js`, `scripts/aio-read.js`, `src/aio-read.js`,
`scripts/render-roboflow.js`, `scripts/collect-only.js`,
`src/audit-references.js`, `.env.example`.

**Fixed**

- The score breakdown now reconciles. `normalize_aio.js` emitted six components
  while weighting four; it now emits only the four that count, each carrying its
  weight, and the renderer prints the weight next to each. Verified on a real
  run: components weighted 35/25/20/20 sum to the reported score.
- The unmeasured "Quality of placement when cited" component is gone. It was
  hardcoded `owned ? 50 : 30` and rendered as if it were data.
- Dead renderer code removed: `moves()` and `metrics()` were defined but never
  called.
- A client's name was leaking through a shared template. `buyerJourneyGaps.problemAware`
  was built from a string containing "Fortinet-style overview queries" and then
  stripped it with `.replace()` at runtime. Gone.
- **Analytics are configurable.** The GTM container was hardcoded. It still
  ships on by default, but `GEO_AUDIT_GTM_ID` now overrides it, and `off`
  renders a report with no tag for a client whose agreement forbids one.
- **One runtime, not two.** The four Python scripts were ported to JavaScript
  (`inject-banners.js`, `move-case-studies.js`, `check-reports.js`,
  `verify.js`), so a machine needs Node and nothing else. Verified by running
  both implementations over the same reports and diffing byte for byte. The two
  dead `normalize_*.py` files from the retired docx path were deleted.
- **Fixed a creep bug while porting.** The original `move_case_studies.py` added
  two bytes to every report on every run, because it re-inserted the moved block
  with fresh newlines without consuming the old ones. It was documented as
  idempotent and was not. The JS version consumes one adjacent newline on each
  side, so repeated runs leave the file byte-identical. (The Python copy still
  in `auq-geo-audits` has the original bug.)
- **The engine no longer needs `npm install`.** `dotenv` was the only dependency
  the audit path used; it was replaced with `src/load-env.js`, a small local
  loader with the same behaviour. express is now an optional dependency, needed
  only for the web app. Nothing is cloned, installed or fetched to run an audit.
- `Audit-SKILL.md` now describes the HTML path end to end. Its runbook tail
  walked through building a .docx with `build_v1.js`, which no longer exists, and
  it still told the agent to request a Cowork workspace folder, sample 3 times,
  and use a "Low / Emerging" band. All of that now matches the engine.
- **`check-reports.js` no longer fails legitimate reports.** Cited domains and
  verbatim quotes are exempt anywhere in the report, not only in the three data
  sections, so an SEO-tool brand's audit no longer fails on `semrush.com`. The
  analytics check follows `GEO_AUDIT_GTM_ID`: a report rendered with `off` passes
  when checked with `off`, and fails if a tag leaked into it.
- `SETUP.md` and `run-batch.sh` point at the bundle's `engine/`, not a
  `geo-audit-full/workspace` checkout, and no longer mention cloning or dotenv.
- `AIO_SAMPLES` defaults to 2 on every path. `collect-only.js` and
  `scripts/aio-read.js` still defaulted to 3, so the two-step path cost 50% more
  than documented. Fixed.
- **Runs no longer look stuck.** On Live, a run was about 78 sequential DataForSEO
  calls and took about 9 minutes, but it printed nothing until the end. Now every
  query prints a progress line (`src/run-progress.js`), partial results are
  saved to `memory.json` after each query, and `verify.js` reports an unfinished
  run as PART rather than skipping it or scoring it.
- **Requests have a time limit.** HTTP calls had no timeout, so a stalled
  connection waited on Node's own limit of about 5 minutes. They now abort after
  `GEO_AUDIT_REQUEST_TIMEOUT_SEC`, default 120 seconds, as DataForSEO recommends
  for SERP calls.
- **Measurement moved from Live to the Standard queue at high priority.** See
  the next section.
- **`products` behaviour is documented.** Product names are matched as brand
  aliases for "mentioned, not cited", not only used for differentiator text. The
  docs said otherwise; a common-word product name inflates mentions.

**Made self-contained.** Publishing used to depend on a private GitHub repo
(`KirillAuq/auq-geo-audits`) that held the two banner scripts and the index
template, so the bundle could not finish a report without it. Both scripts were
copied in and now take a target folder as an argument, and `build-index.js`
generates the index locally. Output is local HTML only: no host, no repo, no git,
no tokens. Every mention of publishing was removed from `SKILL.md`, `SETUP.md`
and the handover docs.

**Deleted**: `START-HERE.txt`, `GEO-Audit-Runbook-v1-Brand-Only copy.md`, and
stray `.DS_Store` files.

**Never included, by design**: `.env` and `skill/team-config.env`. Both hold
live DataForSEO and Ahrefs keys. Distribute them through 1Password or a direct
secure send, never in this bundle.

Every script passes `node --check` and every `require()` in `audit-one.js`
resolves.

## Why the Standard queue (2026-09-14)

Live reads ran one request at a time: 39 queries x 2 samples took 15.5 minutes
for Braintrust, at up to $0.004 a read. DataForSEO's Standard queue takes up to
100 tasks per post and processes them in parallel, at $0.0024 a read with async
AI Overview loading at high priority. DataForSEO itself recommends Standard for
planned bulk collection and Live for on-demand dashboards.

Three Braintrust runs, same identity, same 39 queries, same scorer:

| Run | Score | Time | Cost | Same bucket as Live | AI Overview appeared, agrees with Live | Cited-source overlap with Live |
|---|---|---|---|---|---|---|
| Live, one at a time | 91 Dominant | 15.5 min | up to ~$0.31 | | | |
| Standard high, both samples posted together (test) | 88 Dominant | 3.2 min | $0.19 | 36/39 | 38/39 | 68% |
| Standard high, samples 60s apart (engine) | 92 Dominant | 1.9 min | $0.19 | 35/39 | 38/39 | 64% |

For scale, the only Live-vs-Live pair in the run history (fortinet, older query
set) agreed on 60% of buckets, 93% of AI Overview appearance, and 59% of cited
sources. AI Overviews churn between reads, and the Standard runs sit inside that
churn. Every AI Overview read in the engine run came back complete, with no Live
fallbacks. In the first test 2 of 78 reads were unreadable from the queue, which
is why the engine re-reads those over Live.

One open observation: Standard runs showed fewer queries where the two samples
disagreed on whether an AI Overview appeared (1 of 39, against 5 of 39 on Live),
even with the samples 60 seconds apart. Watch it across more domains. If it
holds, consider a longer `GEO_AUDIT_SAMPLE_STAGGER_SEC`.

## Still open

**One decision.** There are two report lineages and they produce different
documents.

*Lineage A, the engine.* `audit-one.js` or the two-step path, rendered by
`render-roboflow.js`. Google AI Overviews only.

*Lineage B, the hand-authored client reports.* The audits published at auq.io
carry "The size of the gap", "Every AI answer that cites the brand" and "How to
read this", plus ChatGPT columns and AI search volume. Nothing in the engine
produces any of it.

Their source is only partly traced. Hand-authored audits in this style sit under
`~/Claude Code Projects/kirillauq-repo/`, and two of them use band wording
("Barely visible") the engine never emits. But the specific reference page,
`8020rei.html`, is not in any local checkout, and no file on this machine
contains the "size of the gap" markup. Whoever owns lineage B should say where
it is actually authored.

So the polished thing a prospect has historically seen is not what the batch
produces. Either fold lineage B's sections into the renderer or keep them as an
explicit manual tier, but write the decision down. Right now the split is
invisible to anyone new.

Note that lineage B's back catalogue stays where it is. The 314 reports already
in `KirillAuq/auq-geo-audits` and their `auq.io/audits/` URLs are untouched by
this bundle, so links already sent to prospects keep working. This bundle only
changes how new reports are produced.

## Four runtime files that look superseded but are not

`src/audit-references.js` reads **four** files at run time, all at once, and
injects them into agent memory. If any one is missing that path fails:

```
engine/GEO-Audit-Spec-v1-Brand-Only.md
engine/Audit-SKILL.md
engine/references/methodology.md
engine/references/ahrefs-api.md
```

The first and third describe the retired Ahrefs and docx approach, so they read
as dead. They are not. Both carry a header saying so. For current guidance,
these handover files are the source of truth.

`engine/Audit-SKILL.md` is also the authoritative original: current method, with
an operational runbook appended.

## File-by-file

### `engine/scripts/` — what you run

| Path | What it is |
|---|---|
| `audit-one.js` | **The batch unit.** Domain plus identity in, HTML out, one process, no LLM. Site fetch and AIO read in parallel, then `normalize_aio` then `render-roboflow`. Prints one status line. 52 lines. |
| `collect-only.js` | Measurement only. Writes `site` and `aio` into run memory. Step 1 of the two-step path. |
| `collect-identity.js` | Separate LLM identity check. Writes `llm-identity.json`. Does not score and does not send the baseline in the prompt. |
| `test-llm-identity.js` | Offline tests and the sanitized fixture render. No network. |
| `normalize_aio.js` | **The scorer.** memory.json to canonical.json. Buckets, themes, the weighted score, the templated narrative, and `analysis.insightFacts` (via `src/insights.js`). No API calls. |
| `insights.js` | Prints the insight fact sheet per domain from the latest complete run: the grounding for the "What it found" and "Pitch" chat step. Uses `analysis.insightFacts`, or computes it from `memory.json` for older runs. `--json` for the structured object. No network. Non-zero exit if a domain has no complete run. |
| `render-roboflow.js` | canonical.json to HTML. AUQ house design, top-nav, score block, tested-queries table, jump links. |
| `aio-read.js` | Thin CLI over `src/aio-read.js`, for measuring without a full run. |
| `inject-banners.js` | Stamps the "Work with AUQ" banner and the case-studies section onto rendered reports. Idempotent. Takes the output folder as its first argument, else `$GEO_AUDIT_OUT_DIR`. |
| `move-case-studies.js` | Moves the case-studies section above the tested-queries table. Idempotent. Same argument. |
| `build-index.js` | Builds a local `index.html` for a folder of reports, cards sorted by score. Reads `canonical.json`, falls back to parsing the rendered HTML. |
| `check-reports.js` | Checks rendered reports against the writing rules. Case-insensitive tool-name match with measured data exempt (data sections, cited domains, quotes). Checks the analytics tag against `GEO_AUDIT_GTM_ID`: required by default, forbidden when `off`. |
| `run-audit.js`, `generate-report.js` | The old server pipeline, including metered analyze and report phases. Avoid. |
| `debug-ahrefs.js`, `test-audit.js` | Diagnostics. |

### `engine/src/` — the modules

| Path | What it is |
|---|---|
| `aio-read.js` | **The measurement.** Builds the query set (7 decision-stage modifiers per category). Default `standard` mode: posts each sample round as one Standard-queue `task_post` at high priority, 60s apart, collects via `tasks_ready` and `task_get`, and re-reads refused, failed, unreadable or straggling tasks over Live (with 3 retries at 6s for unreadable AI Overviews). `live` mode reads one Live request at a time. Buckets each query by registrable domain and records `aio.mode`, `aio.durationSec` and `aio.cost`. |
| `llm-identity.js` | LLM Responses Live client for the identity check. Prompt builder, Gemini country-field omission, parsers. |
| `llm-identity-compare.js` | Phrase overlap against a dated baseline. No confidence percentage. |
| `insights.js` | `buildFacts(memory, canon)` and `formatFacts(facts)`. Score, theme verdicts (same rule as the coverage rollup) with the domains cited instead, branded and comparison queries with the own domain's source position, top domains where the brand is absent, Wikipedia citations, homepage title. Pure, no network. |
| `run-progress.js` | Progress hooks for `measure()`: a start line, queue status lines while reads are outstanding, one output line per finished query, and a partial save of `memory.json` after each. Used by `audit-one.js`, `collect-only.js` and `scripts/aio-read.js`. |
| `load-env.js` | Minimal `.env` parser replacing dotenv, so the audit path has no npm dependencies. Existing environment variables win, matching dotenv. |
| `agent-memory.js` | Run memory store and the `.data/runs/<runId>/` layout. |
| `site-fetch.js` | Homepage and key-page fetch. Failure-tolerant by design. |
| `ahrefs-mcp.js` | Ahrefs pulls plus `inferBrandName`. Field names vary by account. |
| `audit-references.js` | Loads the four runtime docs into agent memory. See the note above. |
| `server.js`, `app.js`, `audit-jobs.js`, `audit-agent.js` | The web workflow. The agent path burns the metered key. |
| `claude-client.js` | Metered Anthropic client. Not used on either current path. |
| `report-html.js`, `report-css.js`, `report-chunks.js` | The older HTML report path, separate from `render-roboflow.js`. |

### `engine/` — docs, config, web

| Path | What it is |
|---|---|
| `Audit-SKILL.md` | Current method plus the operational runbook. |
| `GEO-Audit-Spec-v1-Brand-Only.md`, `references/methodology.md` | Runtime-loaded. See the note above. |
| `references/ahrefs-api.md` | Ahrefs call order and gotchas. Only for optional volume weighting. |
| `.env.example` | PORT, DataForSEO login and password, optional Ahrefs, and an unused Claude key. |
| `package.json` | No required dependencies. express is optional, for the web app only. |
| `templates/roboflow.css`, `roboflow.fonts.html` | The report design system. Read by the renderer at run time. |
| `public/`, `api/`, `vercel.json` | The lead-magnet landing page and the `/app` workflow UI, plus their Vercel entry. Not part of the audit flow, which is entirely local. Keep or delete independently. |

### `skill/` — the Claude Code skill

| Path | What it is |
|---|---|
| `SKILL.md` | The skill contract: inputs, env table, workflow, DataForSEO limits note, local finishing step, and the final "What it found" / "Pitch" chat step. |
| `SETUP.md` | One-time per-machine setup. |
| `scripts/run-batch.sh` | Batch runner over `audit-one.js`. Clamps concurrency to 2 (keeps `tasks_ready` polling under its 20 calls/min account limit), staggers launches, writes `_progress.log`. |
| `scripts/verify.js` | Post-run verifier. Trigger rate and error count per domain. PART for a run still collecting or stopped. Non-zero exit on any BAD, PART or MISS. |
| `scripts/insights.js` | Thin wrapper that runs the engine's `scripts/insights.js` via `GEO_AUDIT_ENGINE_DIR`. Grounds the "What it found" and "Pitch" chat step (SKILL.md step 7). |
| `templates/identity.example.json` | Identity schema with inline notes. Read before writing one. |

Install:

```bash
mkdir -p ~/.claude/skills
cp -R skill ~/.claude/skills/geo-audit
```

Claude Code discovers skills by scanning `~/.claude/skills/*/SKILL.md`, and the
folder name is the skill's identifier, so it must be `geo-audit` to match the
`name:` in the frontmatter. The copy is a snapshot: re-copy after updating the
bundle, or symlink instead (`ln -s "$PWD/skill" ~/.claude/skills/geo-audit`) to
keep them in sync.

Installing the skill is optional. It is what lets you say "run GEO audits for
acme.com, beta.io" and have Claude Code drive the pipeline. The engine scripts
run perfectly well by hand without it.

## Run artifacts

Under `$GEO_AUDIT_ENGINE_DIR/.data/runs/<runId>/`:

| File | Contents |
|---|---|
| `memory.json` | `meta`, `site`, `aio`, `identity`, and on the two-step path `analysis` and `geoScore`. Saved after every query while collecting, with `meta.phase: "collecting"` and `aio.partial: true` until the run finishes. |
| `canonical.json` | Final scored output. Source of truth for verification and index cards. |

`$GEO_AUDIT_OUT_DIR/` holds `<slug>.html`, `_progress.log`, `_<slug>.out`.
