# 02 — Running an audit

Commands, configuration, verification, and the failure modes that have actually
bitten. Where the output goes is in `05-output-and-index.md`.

## Configuration

Everything machine-specific comes from environment variables. Nothing is
hardcoded. Put these in `~/.zshrc` or a `config.sh` you source.

| Variable | Required | Meaning |
|---|---|---|
| `GEO_AUDIT_ENGINE_DIR` | **yes** | Absolute path to the engine directory (the one holding `scripts/`, `src/`, `package.json`, `.env`). |
| `GEO_AUDIT_OUT_DIR` | no | Where rendered `.html` reports land. Default `$GEO_AUDIT_ENGINE_DIR/../audit-output`. |
| `GEO_AUDIT_IDENTITY_DIR` | no | Where per-domain identity JSON lives. Default `$GEO_AUDIT_OUT_DIR/identities`. |
| `AIO_SAMPLES` | no | Samples per query. Default 2. Higher is more stable and more expensive. |
| `GEO_AUDIT_MAXJOBS` | no | Batch concurrency. Default 2, and `run-batch.sh` clamps to 2. Each audit polls `tasks_ready` 6 times a minute and that endpoint allows 20 a minute account-wide, so 2 is comfortably safe and is what has been tested. |
| `GEO_AUDIT_STAGGER` | no | Seconds between audit launches. Default 4. |
| `GEO_AUDIT_ERR_THRESHOLD` | no | Max errored queries the verifier tolerates. Default 5. |
| `GEO_AUDIT_AIO_MODE` | no | How AI Overviews are read. `standard` (default): DataForSEO Standard queue at high priority. `live`: one Live request at a time, about 7x slower; for comparison runs only. |
| `GEO_AUDIT_PRIORITY` | no | Standard queue priority. `2` = high (default, about 1 minute turnaround). `1` = normal (about 5 minutes, half the price). |
| `GEO_AUDIT_SAMPLE_STAGGER_SEC` | no | Seconds between posting sample round 1 and round 2. Default 60, so the two samples are not taken at the same instant. |
| `GEO_AUDIT_STRAGGLER_SEC` | no | A queued read not back after this many seconds is re-read Live. Default 90. |
| `GEO_AUDIT_POLL_SEC` | no | Seconds between `tasks_ready` checks. Default 10 (6 calls a minute; the account-wide limit is 20). |
| `GEO_AUDIT_REQUEST_TIMEOUT_SEC` | no | Time limit per DataForSEO HTTP request. Default 120, which is what DataForSEO recommends for SERP calls. |
| `GEO_AUDIT_GTM_ID` | no | The GTM container injected into every report. Defaults to the AUQ container. Set to another ID to use a different one, or to `off` to render without a tag. Set it the same way when running `check-reports.js`. See `05-output-and-index.md`. |

Keys live in `engine/.env`, copied from `.env.example`:

```
GEO_AUDIT_DATAFORSEO_LOGIN=...
GEO_AUDIT_DATAFORSEO_PASSWORD=...
GEO_AUDIT_AHREFS_MCP_KEY=...        # optional, volume weighting only
```

**AUQ provides these.** Keys are never included in a handoff bundle, so they
reach you separately. Without them every query returns "fetch failed" and the
audit scores 0.

The Anthropic key in `.env.example` is **not used**. Analysis runs on the local
Claude Code session. If you find something calling it, that code path is the old
one and should be avoided.

If a shared `team-config.env` is distributed, it sits at the skill root and
`run-batch.sh` auto-sources it, so teammates need no personal keys. It holds
live secrets, is gitignored, and is distributed only through 1Password or a
direct secure send. `chmod 600` it. If it leaks, rotate the DataForSEO and
Ahrefs keys. It is **not** present in this bundle.

## One-shot: the whole audit in one command

Deterministic, no human in the loop, no LLM. This is what `run-batch.sh` calls
once per domain.

```bash
cd "$GEO_AUDIT_ENGINE_DIR"
node scripts/audit-one.js acme.com "$GEO_AUDIT_IDENTITY_DIR/acme.json" "$GEO_AUDIT_OUT_DIR/acme.html"
```

Pass `-` instead of an identity path to run without one. The brand name is then
inferred from the domain and there are no category themes, so coverage is empty
and the score is meaningless. Always pass a real identity file.

It fetches the site and reads AI Overviews in parallel, writes `memory.json` and
`canonical.json` into `.data/runs/<runId>/`, and renders the HTML. Expect about
2 minutes. It prints a start line, queue status lines while reads are
outstanding, one line per query once both its samples are in, and the status line
last:

```
[acme.com] runId a1b2c3 | 39 queries x 2 samples | Standard queue, priority high | sample rounds 60s apart | Live fallback after 90s | request timeout 120s
[acme.com] 24s queue: rounds posted 1/2 | reads back 22/78 | queued 17 | via Live 0
[acme.com] 67s queue: rounds posted 2/2 | reads back 39/78 | queued 39 | via Live 0
[acme.com] [ 1/39] 78s best endpoint security -> invisible
[acme.com] [ 2/39] 78s endpoint security vendors -> owned (1 via Live)
...
[acme.com] 112s queue: rounds posted 2/2 | reads back 78/78 | queued 0 | via Live 1
[acme.com] [39/39] 112s acme vs wiz -> mentioned_not_cited
[acme.com] runId a1b2c3 | score 34 Low | trigger 72% | cited 9/28 | -> out/acme.html
```

No per-query lines appear until round 2 starts coming back, a little after the
first minute; the queue lines show it moving before that. `(1 via Live)` means
one of that query's samples fell back to a Live read. The status line is always
last, because `run-batch.sh` copies the final line into `_progress.log`. An
errored query shows as `-> ERROR <reason>`, for example
`still queued after 90s; Live fallback failed: DataForSEO request timed out after 120s`.

The site fetch is wrapped so a blocked or slow site cannot fail the audit. It
only feeds differentiator text in the report. The themes come from the identity
file.

The narrative sections it produces are **templated**, not written: real numbers
and real theme names slotted into fixed sentences. For client-facing work use
the two-step path below.

## Two-step: bespoke analysis

Same measurement and same scoring formula, with the Claude session writing the
analysis instead of templates.

### 1. Collect

```bash
cd "$GEO_AUDIT_ENGINE_DIR"
node scripts/collect-only.js acme.com [identity.json]
```

Runs site fetch plus the AIO read (Standard queue, same as the one-shot path) and writes `site` and `aio` into
`.data/runs/<runId>/memory.json`. No Anthropic key.

First time on a domain, run it once without an identity file, read the `site`
memory, write `identity.json` from it (schema and rules in `01-method.md`), then
re-run with it.

### 2. Analyze and score

Read the run's `memory.json` (`site`, `aio`), follow stages 4 to 6 of
`01-method.md`, and write the canonical JSON yourself: `meta` + `geoScore` +
`analysis`. You are the analysis agent. There is no API call here.

Always include `analysis.testedQueries` — the full query log copied from
`aio.results` as `{query, layer, bucket, citedTop}`, where `citedTop` is the top
three cited domains. The report's "Queries we tested" table is built from it,
with three columns: Query, brand in the AI answer, and top sources cited.
`layer` is kept in the data but is not shown as a column.

Full key list in `03-report-spec.md`.

### 3. LLM identity check

Separate from the score. Protocol, endpoints, and the Gemini country-code
gotcha are in `06-llm-identity.md`.

```bash
node scripts/collect-identity.js acme.com "Acme" \
  --baseline /path/to/acme.baseline.json \
  --samples 2 \
  --out "$GEO_AUDIT_ENGINE_DIR/.data/runs/<runId>/llm-identity.json"
```

Uses `GEO_AUDIT_DATAFORSEO_LOGIN` and `GEO_AUDIT_DATAFORSEO_PASSWORD`. The
`DATAFORSEO_LOGIN` and `DATAFORSEO_PASSWORD` names are aliases. Do not print
them. If they are unset, the script writes `not_tested` and exits 2.

### 4. Render

```bash
node scripts/render-roboflow.js <runDir|canonical.json> out.html
```

A run directory prefers `canonical.json` when it is present, so the stored
score is what renders. `llm-identity.json` in that directory is merged in for
the identity section only. Writes one self-contained HTML file. The AUQ
top-nav, the tested-queries table, and the jump links into it are injected
automatically. No post-processing.

`audit-one.js` does not call this check. Re-render after `collect-identity.js`
if that HTML should include the snapshots. Until then the section says Not tested.

## Batch of domains

```bash
cd /path/to/audit-handover
GEO_AUDIT_ENGINE_DIR="$GEO_AUDIT_ENGINE_DIR" \
GEO_AUDIT_OUT_DIR="$GEO_AUDIT_OUT_DIR" \
GEO_AUDIT_IDENTITY_DIR="$GEO_AUDIT_IDENTITY_DIR" \
AIO_SAMPLES=2 GEO_AUDIT_MAXJOBS=2 GEO_AUDIT_STAGGER=4 \
bash skill/scripts/run-batch.sh acme.com beta.io
```

Slug rule: the first DNS label (`acme.com` -> `acme`). Override per domain with
`acme.com:acmecorp`. Identity is read from `$GEO_AUDIT_IDENTITY_DIR/<slug>.json`
and the runner warns if it is absent. Reports go to `$GEO_AUDIT_OUT_DIR/<slug>.html`,
progress to `_progress.log`, per-domain stdout to `_<slug>.out`.

Long batches should be launched so they survive a shell reset. On macOS there is
no `setsid`, so use `nohup` plus `disown`:

```bash
cd /path/to/audit-handover
nohup bash skill/scripts/run-batch.sh acme.com beta.io > /dev/null 2>&1 &
disown
```

`tmux new -s audits` or `screen` works too and lets you reattach to watch
progress. `_progress.log` only gets a line when a domain finishes, so follow a
running domain in its own output:

```bash
tail -f "$GEO_AUDIT_OUT_DIR/_acme.out"
```

Partial results are saved to the run's `memory.json` after every finished query. A run
that is stopped keeps the reads it already made, marked `aio.partial: true`, and
the verifier reports it as PART. The report and `canonical.json` are only written
when the run finishes.

## Verify, always, before handing anything over

```bash
cd /path/to/audit-handover
GEO_AUDIT_ENGINE_DIR="$GEO_AUDIT_ENGINE_DIR" \
node skill/scripts/verify.js acme.com beta.io
```

Reads the latest run per domain from `$GEO_AUDIT_ENGINE_DIR/.data/runs/*/memory.json`
and prints trigger rate and errored-query count.

- **OK** — trigger rate above 0 and errored queries at or under the threshold
  (default 5 of about 39).
- **BAD** — trigger 0, or too many errors. DataForSEO failed or refused the reads,
  including their Live fallbacks.
- **PART** — the latest run is still collecting, or was stopped part-way. It
  shows how many queries were read. Let it finish, or re-run it.
- **MISS** — no run found.

Exit code is non-zero if anything is BAD, PART or MISS, so you can gate on it.

Re-run any BAD domain solo, then verify again:

```bash
GEO_AUDIT_ENGINE_DIR="$GEO_AUDIT_ENGINE_DIR" AIO_SAMPLES=2 \
node "$GEO_AUDIT_ENGINE_DIR/scripts/audit-one.js" \
  acme.com "$GEO_AUDIT_IDENTITY_DIR/acme.json" "$GEO_AUDIT_OUT_DIR/acme.html"
```

Never report a score for a domain that is not clean. If a domain could not be
measured, say so. Do not emit a 0.

## Finishing the reports

Reports are local files. Nothing is published, pushed, or uploaded.

After a batch: verify, add the conversion banners, rebuild the local index.

```bash
cd "$GEO_AUDIT_ENGINE_DIR"
node scripts/inject-banners.js "$GEO_AUDIT_OUT_DIR"
node scripts/move-case-studies.js "$GEO_AUDIT_OUT_DIR"
node scripts/build-index.js "$GEO_AUDIT_OUT_DIR"
node scripts/check-reports.js "$GEO_AUDIT_OUT_DIR"
```

Both banner scripts are idempotent. If the reports were rendered with
`GEO_AUDIT_GTM_ID=off`, run `check-reports.js` with it set too. Full detail is in
`05-output-and-index.md`.

## Reporting back

Give a table of every domain with GEO score and band, plus the local file path
for each report. Call out the Dominant and Absent results. Report failures
honestly.

Then, as the final step, write two blocks per clean domain in the chat: **What
it found** and **Pitch**. Ground them in the fact sheet:

```bash
GEO_AUDIT_ENGINE_DIR="$GEO_AUDIT_ENGINE_DIR" node skill/scripts/insights.js acme.com beta.io
```

The logic is in the engine: `engine/src/insights.js` builds the facts and
`engine/scripts/insights.js` prints them (`--json` for the structured object).
The skill's `insights.js` is a thin wrapper that finds the engine through
`GEO_AUDIT_ENGINE_DIR`. Every run made by `audit-one.js` or `normalize_aio.js`
stores the facts in `canonical.json` as `analysis.insightFacts`, so they travel
with the run. For runs made before that key existed, and for hand-written
canonicals on the two-step path, the script computes them from `memory.json`.

It reads the latest complete run per domain, with no network calls.
It prints the score, a verdict per theme (the same rule as the report's coverage
table) with the domains cited instead, every comparison and branded query with
its top sources, the domains that win where the brand is absent, Wikipedia
citations, and the homepage title.

- **What it found** is three bullets: where the brand gets cited, where it is
  missing (flag it as the biggest gap when the homepage leads with a missing
  category), and how the head-to-head queries resolved.
- **Pitch** is two short paragraphs. The first opens "At a glance, {Brand}
  scored {score}/100." and says what is unusual about this audit. The second
  opens "The more interesting piece, though:" with the single most striking
  finding and who takes the queries instead.

Good pitch angles, strongest first: the brand name means something else
(off-topic or Wikipedia sources on branded and comparison queries); the
homepage's headline category is missing; the brand ranks organically but is not
cited (only with Ahrefs or Semrush data pulled in the same session); one peer
dominates the queries where the brand is absent.

Every claim must trace to the fact sheet or to data fetched in that session.
The run stores cited domains, not the AI answer text, so do not describe what an
answer said beyond what its sources show. Format, rules and worked examples (Felt and
Sangoma) are in `skill/SKILL.md`, step 7.

## Failure modes

**Every query errors, score 0.** The DataForSEO keys are wrong or the account
is out of balance: `task_post` is refused and every Live fallback fails too.
Check `.env` and the DataForSEO dashboard.

**Many reads go "via Live".** The queue is slow or refusing tasks. The audit
still completes, but each Live read costs up to $0.004 and takes seconds, so the
run is slower and dearer. Check the error text in `_<slug>.out`. If DataForSEO
reports errors by the dozen, it advises pausing for 5 to 10 minutes.

**Rate limits.** DataForSEO allows 2,000 SERP calls a minute, 100 tasks per
`task_post`, and 20 `tasks_ready` calls a minute account-wide. An audit makes 2
posts, about 12 `tasks_ready` calls, and one `task_get` per read. The binding
limit is `tasks_ready`: keep `GEO_AUDIT_MAXJOBS=2` (the runner clamps to it) and
`GEO_AUDIT_POLL_SEC` at 10 or more.

**About a third of queries come back unreadable.** `load_async_ai_overview` was
not set. Re-polling does not recover them. Re-run with it set.

**Coverage is empty and the score is meaningless.** No `identity.json`, or no
`categories` in it. Nothing downstream works without category themes.

**A theme rendered as "IoT platform platform".** A category root ended in a word
the modifier set doubles. Fix the identity file.

**Wrong brand entirely.** The brand name differs from the domain, or the product
name is what buyers use. Fix `brand` in the identity file.

**`www.` prefix breaks the site fetch.** Use the bare domain.

**It looks stuck.** About 2 minutes is normal, and the first minute shows only
queue lines. Check `_<slug>.out`: a queue line prints at least every 15 seconds
while counts change. Nothing waits on the queue longer than
`GEO_AUDIT_STRAGGLER_SEC` (90s) before falling back to Live, and no HTTP request
outlives `GEO_AUDIT_REQUEST_TIMEOUT_SEC` (120s).

**False "mentioned, not cited" results.** A `products` entry is a common word,
and it matched ordinary answer text. Product names count as brand aliases. Use
only distinctive names, or leave `products` empty.

**A batch dies when the shell resets.** Launch it with `nohup ... &` followed by
`disown`, or run it inside `tmux`/`screen`. `setsid` does not exist on macOS, so
any instruction using it fails immediately.

## Cost

60 to 80 reads per domain (30 to 40 queries at 2 samples) on the Standard queue
at high priority: $0.0012 per read plus $0.0006 for `load_async_ai_overview`, so
**about $0.19 per audit**. Each Live fallback read costs up to $0.004 ($0.002
plus $0.002 for async loading, refunded when the AI Overview was cached). The
run records the actual spend in `aio.cost`: `standardUsd`, `liveUsd`,
`totalUsd`, and how many reads went each way.

`GEO_AUDIT_PRIORITY=1` (normal priority) halves the queue price but averages
about 5 minutes per round, and more reads would hit the 90-second Live fallback
unless `GEO_AUDIT_STRAGGLER_SEC` is raised too. Untested.

Optional Ahrefs calls bill by **rows returned**, not by request. Log the `units`
field from each response into the run's JSON as you go, or the run's credit cost
is not recoverable afterwards.
