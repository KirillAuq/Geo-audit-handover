# GEO Audit — handover

A brand-only GEO (Generative Engine Optimization) audit. One input: a domain.
One output: a self-contained HTML report scoring how Google's AI Overviews
represent that brand, in the AUQ house design.

A live example of the older hand-authored report format, kept for reference:
https://auq.io/audits/8020rei.html — note that this is **not** what the engine
produces. See `03-report-spec.md`.

## The six files

| File | Read it when |
|---|---|
| `README.md` (this) | First. Orientation, setup, first run. |
| `01-method.md` | You need to know what the audit measures and how the score is built. |
| `02-running-an-audit.md` | You are actually running one. Commands, env vars, verification, failure modes. |
| `03-report-spec.md` | You are changing the report, or writing the JSON the renderer consumes. |
| `04-bundle-map.md` | You need to know what every file is, and the known rough edges. |
| `05-output-and-index.md` | You have finished reports and want them banner-stamped and indexed. All local, no host. |

## What the audit is

A positioning diagnostic, not a competitive benchmark. It answers: what do
Google's AI Overviews think this brand does, what does it specialize in, and
where does it show up versus go missing.

Competitor names are never an input. Names that surface in the data are reported
as observed "AI-revealed peers". Queries are category-only and non-branded, so
the brand cannot inflate its own score by being cited for its own name.

## Two ways to run it

**One-shot (deterministic, batchable).** One command per domain, no human in the
loop, no LLM anywhere in the chain.

```bash
node scripts/audit-one.js acme.com identities/acme.json out/acme.html
```

Collects, buckets, scores, and renders in a single process. The narrative
sections come out **templated** — real numbers and real theme names slotted into
fixed sentences. Right for prospecting volume, where the score is the product.

**Two-step (bespoke prose).** Collect, then have the Claude session read the run
memory and author the analysis, then render.

```bash
node scripts/collect-only.js acme.com identities/acme.json
# Claude writes analysis + geoScore into canonical.json
node scripts/render-roboflow.js <runDir|canonical.json> out/acme.html
```

Same measurement, same scoring formula, written analysis instead of templates.
Right for client-facing work.

Both paths are in `02-running-an-audit.md`.

## Shape of a run

```
domain
  -> identity.json        brand, categories, products, competitors (quality-critical)
  -> query set            categories x 7 decision-stage modifiers, plus a lean comparison layer
  -> AIO read             DataForSEO Standard queue, high priority, US/en/desktop,
                          load_async_ai_overview, 2 samples 60s apart
  -> bucketing            owned / mentioned-not-cited / invisible / pending / no-AIO
  -> score                four weighted components, 0-100, banded
  -> canonical.json       meta + geoScore + analysis (incl. insightFacts)
  -> render               one self-contained .html
  -> chat insights        "What it found" + "Pitch" per domain, from scripts/insights.js
```

Measurement uses DataForSEO keys, which AUQ provides separately. No Anthropic
key is used on either path. Reports are local HTML files: nothing publishes to a
host, no step uses git, and there is nothing to install. See
`05-output-and-index.md`.

## Layout

Everything needed lives in one folder, `audit-handover/`:

```
audit-handover/
  engine/               the Node engine: scripts/, src/, templates/, .env.example
  skill/                the Claude Code skill: SKILL.md, SETUP.md, scripts/
  geo-audit-handover/   these docs
  audit-output/         created on first run: reports, identities, logs
```

The only thing not in it is the DataForSEO keys, which go in `engine/.env`.

## Setup, once per machine

```bash
cd engine
cp .env.example .env          # add the DataForSEO login + password AUQ gave you
mkdir -p ~/.claude/skills
cp -R ../skill ~/.claude/skills/geo-audit
```

No `npm install`, no clone, no build. The audit pipeline has zero npm
dependencies and runs on a stock Node 18+ install. (`npm install` is only for
the optional web app, which uses express.)

Then in your shell profile:

```bash
export GEO_AUDIT_ENGINE_DIR="/absolute/path/to/audit-handover/engine"
export GEO_AUDIT_MAXJOBS=2    # the tested batch concurrency
```

Reports and identity files default to `audit-handover/audit-output/`, so the
project stays self-contained. Set `GEO_AUDIT_OUT_DIR` only to put them elsewhere.

```bash
# optional
export GEO_AUDIT_OUT_DIR="/somewhere/else/audit-output"
```

Requirements: Node 18 or newer, and Claude Code. Nothing else. No Python, no npm packages, no clone, no build. Full env var table in
`02-running-an-audit.md`.

## Cost and time

One audit is 30 to 40 queries at 2 samples, so 60 to 80 reads on DataForSEO's
Standard queue at high priority: **about $0.19** ($0.0012 per read plus $0.0006
for async AI Overview loading). A read that has to fall back to Live costs up to
$0.004. The engine records the actual spend in the run's `aio.cost`.

An audit takes **about 2 minutes**. All of a sample round's queries go to
DataForSEO in one request and are processed in parallel; the second round is
posted 60 seconds after the first. The Braintrust reference run took 112 seconds
and $0.1872, with no Live fallbacks. A batch at concurrency 2 finishes about two
domains every 2 to 3 minutes.

The engine used to read over Live, one request at a time, which took about 15
minutes per audit. `GEO_AUDIT_AIO_MODE=live` still does that, for comparison
runs. See `04-bundle-map.md` for the comparison that justified the switch.

## Provenance

The engine was reconciled against the working copy at
`~/Dev Projects/geo-audit-full/workspace` and cleaned up on 2026-09-14.
`audit-one.js`, `normalize_aio.js`, `aio-read.js` and the current
`render-roboflow.js` were restored from there; the score breakdown was fixed so
it reconciles with the total; dead docx-era code and docs were removed. No
`.env` and no keys are in this bundle, by design.

Verified after cleanup: every script passes `node --check`, a real run rebuilds
and renders end to end, the weighted components sum to the reported score, and
the rendered HTML has zero em dashes, zero en dashes and no third-party tool
names.

Full detail in `04-bundle-map.md`.
