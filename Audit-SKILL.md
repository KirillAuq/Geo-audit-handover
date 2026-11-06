---
name: geo-audit-brand-only
description: Run a brand-only GEO (Generative Engine Optimization) audit of how Google AI Overviews represent a single brand, taking only a domain as input and producing a self-contained HTML positioning report in the AUQ house design. Use this whenever the user wants to understand how a brand is described, positioned, or cited in Google AI Overviews (AIO) without competitor benchmarking — e.g. "run a GEO audit on acme.com", "what do AI Overviews say about our brand", "audit our AIO positioning", "brand-only AI visibility report". Reads Google AI Overviews per positioning query via DataForSEO's Standard queue at high priority (Ahrefs optional, for search-volume weighting only). Competitor benchmarking (share of voice, head-to-head) is a different audit and is not part of this engine.
---

# GEO Audit — Brand-Only

## What this produces

A single self-contained HTML report that answers one question: **what do Google's AI Overviews think this brand does, what does it specialize in, and where does it show up versus go missing in AIO results.**

This is a positioning diagnostic, not a competitive benchmark. Competitor names that surface in the data are reported as an observed finding ("AIO-revealed peers"), never taken as an input. The only thing the user provides is a domain.

If the user wants share-of-voice and head-to-head competitor analysis, stop and say so. That is a different audit, and nothing in this engine produces it.

## Inputs

A single domain string (e.g. `acme.com`). Nothing else. Everything downstream — brand name, category, use cases, audience, positioning queries — is derived inside the run from the domain.

## Generation mode — NO metered API key (default, set 2026-06-19)

The server's `analyze` and `report` phases call a separate **console.anthropic.com API key** in `.env`. Standing instruction: **do not use that key — run the analysis on the local Claude account (the Claude Code session driving this work).** Only the data-collection step needs external services (site fetch + DataForSEO AIO read; Ahrefs optional for volume), which use their own keys, not Anthropic's.

Default flow for every report:
1. **Collect (key-free):** `node scripts/collect-only.js <domain> [identity.json]` — runs site-fetch + the AIO read (DataForSEO Standard queue, high priority) and saves `site` + `aio` to `.data/runs/<runId>/memory.json`. No Anthropic key. Pass an `identity.json` (`brand`, `competitors`, and `categories` = non-branded category terms that drive the queries; `products` is for differentiator text and is also matched as a brand alias, so list only distinctive product names) derived from the site. Without it there are no category themes, so coverage is empty — always provide categories. For best results: run once to fetch the site, derive `identity.json` from the `site` memory, then re-run with it. (`POST /audit` also works but its `analyze`/`report` phases burn the metered key, and the server route still uses the old Ahrefs path — avoid it.)
2. **Analyze + score (local Claude session):** read the run's `memory.json` (`site`, `aio`), follow the analysis stages below, and write the canonical JSON yourself (`meta` + `geoScore` + `analysis`). Always include `analysis.testedQueries` — the full query log copied from `aio.results` as `{query, layer, bucket, citedTop}` (citedTop = top 3 cited domains) — so the report can show exactly which queries were searched. You are the analysis agent — no API call.
3. **Render (key-free):** `node scripts/render-roboflow.js <canon.json> <out>.html` (AUQ house design). The renderer appends a "Queries we tested" table (from `analysis.testedQueries`, or as a fallback from raw `aio.results`) with three columns — Query, brand in the AI answer, top sources cited; there is no Type column, and `layer` is kept in the data only — and links the content-coverage, performance, and peers sections to it with jump-link CTAs. It also renders the **AUQ site top-nav** on every report — logo (→ auq.io) left, centered links **AUQ GEO** (/geo-llm-optimization/), **GEO Analytics** (/geo-analytics/), **Pricing** (/pricing/), **Our Team** (/team/), and a **Contact Us** (/contact-us/) CTA button right; sticky, centered via a 3-zone grid, and collapses to logo + CTA below 820px. Included automatically — no action needed.

**Or run all three steps at once.** `node scripts/audit-one.js <domain> <identity.json|-> <out>.html` collects, scores with `scripts/normalize_aio.js`, and renders in a single process, with no LLM anywhere in the chain. Use it for batches. The narrative comes out templated rather than written, so the two-step flow above is what client work uses.

The old Python reshapers (`normalize_run.py`, `normalize_local.py`) were part of the retired docx path and have been removed.

## Workflow

Follow these stages in order. Read `references/methodology.md` for the full reasoning behind each stage; the summary below is enough to execute.

1. **Site extraction.** Fetch the homepage plus a few structurally important pages (about, products, pricing, customers) with web_fetch. Extract: brand name (often differs from the domain), one-line description, the category the brand places itself in, primary use cases, audience signals. Watch for brand-vs-product naming — if the domain is `acme.com` but the product is "AcmeShield Pro," queries must use the product name.
2. **Positioning query construction.** Build the query set from the brand's own positioning (category themes × decision-stage modifiers, plus a lean comparison layer). No branded queries. Not discovered from a keyword index by traffic. See `references/methodology.md` → "Positioning query construction."
3. **AIO read.** For each query, read the Google AI Overview (DataForSEO SERP `ai_overview` element): triggered?, answer text, every cited URL. Sample each query 2 times (`AIO_SAMPLES`, default 2), rounds 60 seconds apart, with `load_async_ai_overview: true`, via the Standard queue at high priority with a Live fallback. The request, sampling, fallback and retry logic live in `src/aio-read.js`; read it before changing anything about the call.
4. **Deterministic bucketing.** Sort each query from the read: brand domain cited = owned; brand named but not cited = mentioned-not-cited; AIO fired but brand neither named nor cited = invisible (log who was cited); async-unreadable = `aio_pending`; no AIO = not an AIO query. Never call a theme invisible unless a query was tested and the brand was absent.
5. **Analysis.** Compute AIO trigger rate, citation rate, and position-when-cited from the reads. Extract identity statements. Build content and entity coverage from the buckets. Surface AIO-revealed peers from the competitor citations.
6. **Report generation.** Write the canonical JSON the renderer consumes, then render it to HTML (see "Generating the report").

## Generating the report

The deliverable is HTML, not docx. `scripts/audit-one.js` renders it as the last
step of a run; the two-step path renders with `scripts/render-roboflow.js`.

The docx builders this file used to point at (`build_report.js`, `build_v1.js`)
were retired with the docx path and are not part of the engine. The report
structure, the canonical JSON the renderer consumes, and the writing rules are
in `geo-audit-handover/03-report-spec.md`.

# GEO Audit Runbook - v1 Brand-Only

Operational instructions for an agent to execute the v1 Brand-Only GEO audit end to end. Pair this with `geo-audit-handover/01-method.md` (what the audit is) and `geo-audit-handover/03-report-spec.md` (what the report must contain). This runbook covers how to actually do it.

---

## 1. Purpose

Produce a Google AI Overviews positioning diagnostic for a single brand, delivered as a self-contained HTML file in AUQ's house design. Brand-only (no competitor benchmarking; peers are observed, not input).

## 2. Inputs

The agent receives exactly one input from the user:

- `domain` - a bare domain string (example: `winpure.com`). No protocol, no path.

Everything else (brand name, category, use cases, audience, positioning queries, peers) is derived inside the audit.

Before starting, confirm `GEO_AUDIT_ENGINE_DIR` points at the engine and `engine/.env` holds the DataForSEO credentials. Reports are written to `$GEO_AUDIT_OUT_DIR`.

## 3. Output specification

| Item | Value |
|---|---|
| File format | Self-contained HTML |
| File name | `<slug>.html`, where slug is the first DNS label (`acme.com` -> `acme.html`) |
| Save location | `$GEO_AUDIT_OUT_DIR` (default `$GEO_AUDIT_ENGINE_DIR/../audit-output`) |
| Sections | The sections defined in the spec, plus a Methodology appendix and a "Queries we tested" table (full query log, linked from the data-driven sections) |
| Validation | `node scripts/check-reports.js "$GEO_AUDIT_OUT_DIR"` passes: no em or en dashes anywhere, no tool names in the report's own prose (measured data is exempt). See `03-report-spec.md`. |

Do not produce any additional output formats unless the user explicitly asks. No docx, no PDF, no slide deck, no markdown summary.

## 4. Capabilities required

The agent needs access to:

1. **Web fetch** for the brand's own site. The engine does this itself in `src/site-fetch.js`; a web-fetch tool is only needed to read pages by hand while writing the identity file.
2. **A SERP reader that parses Google AI Overviews.** The measurement source is DataForSEO: Standard queue at high priority (`serp/google/organic/task_post`, `priority: 2`, collected via `tasks_ready` and `task_get/advanced`), with Live (`serp/google/organic/live/advanced`) as the fallback. Query-anchored: submit a positioning query, read the `ai_overview` element (triggered?, answer text, cited URLs). Sample each query 2 times. Implemented in `src/aio-read.js`.
3. **(Optional) Ahrefs MCP** (tool prefix `mcp__e5d2bebe-...`) for search-volume enrichment of the positioning queries (`keywords-explorer-overview`) and the brand's own top pages (`site-explorer-top-pages`). Not used to select queries.
4. **The bundled renderer** (`scripts/render-roboflow.js`). The deliverable is HTML. No docx skill, no docx npm package.
5. **A shell** with Node 18 or newer. Nothing else: no npm install, no Python.

If the SERP reader cannot return Google AI Overview data, stop and surface this to the user. The audit's primary surface is AIO, and neither the official Google Search API nor the Gemini API is an acceptable substitute (neither reads AIO).

## 5. Execution

### Phase 0 - Prep
- Read `GEO-Audit-Spec-v1-Brand-Only.md` to confirm scope.
- Read `geo-audit-handover/03-report-spec.md` for the section order, the canonical JSON the renderer consumes, and the writing rules.
- Create a task list with the phases below.

### Phase 1 - Site extraction
Fetch the homepage of `domain`. Read the page and extract:

- Brand name (often differs from the domain).
- One-line description / value proposition (the hero headline plus subhead).
- Category language the brand uses for itself.
- Product/module names (often a navigation list).
- Use cases / capabilities (clean, match, dedupe, etc.).
- Audience signals (SMB, enterprise, regulated industries, specific verticals).
- Proof points: customer logos, accuracy stats, scale stats, named differentiators (on-premise, no-code, flat pricing, etc.).
- Named on-site competitors (look for "Compare with X" pages).

If the homepage is thin, fetch one or two of: `/about`, `/pricing`, `/products`, `/customers`. Avoid pulling more than three pages; this is identity grounding, not a crawl.

Write the brand-side identity to a notes file (mental or on disk) for the side-by-side comparison in Section 1 of the report.

### Phase 2 - Positioning query construction (category-only, non-branded)
This is a thinking step, not a data pull. Build the query set from the positioning extracted in Phase 1 — never from a keyword index ranked by traffic.

**Themes are categories ONLY.** Cross each non-branded category term with the decision-stage modifier set: `best {t}`, `{t} vendors`, `{t} solutions`, `{t} software`, `{t} platform`, `top {t} providers`, `{t} comparison` (~7 per theme). Do **not** build queries from the brand name or from product names (e.g. "FortiGate", "Haystack") — "is the brand cited" is trivially true for its own name, so branded queries inflate the score with meaningless data. In the identity object, `categories` drives the queries; `products` is never used for queries, but it is used for the report's differentiator text and matched as brand aliases when bucketing, so list only distinctive names.

Add a lean comparison layer (~4) only to surface peers: `alternatives to {brand}` and `{brand} vs {competitor}` for the top 2-3 competitors. Target ~30 to 40 queries total.

Optional volume weighting: to prioritize queries, pass the *already-built list* to `keywords-explorer-overview` for volume. Do not let a keyword tool generate or reorder the set by traffic. Pull `site-explorer-top-pages` only for the brand's own-page citation footprint context.

### Phase 3 - Assemble the query set (~30 to 40)

Two layers, both non-branded:

- **Positioning / category (the core, ~35):** each category theme × modifier set, e.g. `best {category}`, `{category} vendors`, `{category} solutions`, `{category} software`, `{category} platform`, `top {category} providers`, `{category} comparison`.
- **Comparison (lean, ~4):** `alternatives to {brand}`, `{brand} vs {competitor}` (top 2-3). For peer discovery only.

There is **no branded layer** ("what is {brand}", "{brand} reviews", "{brand} pricing", etc.) and no "top keywords by traffic" tier. Save the query set to a `.txt` or `.md` file in the working directory for traceability, but do not deliver it to the user unless asked.

### Phase 4 - AIO read (Google AI Overviews only, US)

For each query in the set, read the Google AI Overview with DataForSEO's Standard queue at high priority (`serp/google/organic/task_post`, `priority: 2`; `location_name` United States, `language_code` en, `device` desktop). All queries for a sample round go in one post; results are collected with `tasks_ready` and `task_get/advanced`. A task the queue refuses, fails, returns unreadable, or still holds after 90 seconds is re-read over Live (`serp/google/organic/live/advanced`). Submit the query string; this is query-anchored, so it works whether or not the brand ranks.

From each response capture:
- **Triggered:** is an `ai_overview` item present in `items`.
- **Answer text:** the AIO text/markdown.
- **Citations:** every cited URL and its registrable domain (the brand and everyone else).

**Sample each query 2 times** (`AIO_SAMPLES`, default 2; higher is steadier and costs more), with the second round posted 60 seconds after the first (`GEO_AUDIT_SAMPLE_STAGGER_SEC`) so the samples are not taken at the same instant. AIO triggering is volatile; treat it as triggered if it fired on any sample, and record the per-query trigger rate. **Set `load_async_ai_overview: true` on the request** so DataForSEO renders and returns the async AI Overview inline; without it ~1/3 of queries come back as an unreadable `asynchronous_ai_overview` stub, and re-polling does not fix it (verified). It adds $0.0006 per read on the Standard queue ($0.002 on Live), and it is required for trustworthy coverage.

Save the raw reads to a file in the working directory. Decide "is the brand cited" by matching the citation's registrable domain to the target domain, not by string-matching the brand name in the text.

### Phase 5 - Bucketing and analysis

**Deterministic bucketing first (no judgment on presence).** For every query, assign from the Phase 4 read using three signals:
- brand domain cited as a source in the AIO → **owned**
- brand named in the AIO text but its domain not cited → **mentioned, not cited** (common: the brand is in the answer but not the source)
- AIO triggered, brand neither named nor cited → **invisible** (record the competitor domains cited instead)
- AIO present but rendered async and unreadable (`asynchronous_ai_overview: true`) → **`aio_pending`** (retry; never "invisible")
- no AIO across all samples → **not an AIO query** (this is not "invisible")

The mention-vs-citation split matters: a brand can be the named answer ("FortiSASE is best for...") while its own domain is not a cited source. That is "mentioned, not cited," and the fix is a citation gap, not a presence gap.

Build the content and entity coverage table directly from these buckets. **Grounding rule:** every row must trace to a query that was actually read. Never move a theme into "invisible" because the brand sells it but you don't see it — if no query tested that theme, it is "not measured (recommend tracking)," not invisible.

**Identity statements.** Read the AIO answer texts where the brand is cited. Pull verbatim sentences where AIO describes the brand. Use them as quote blocks in Section 1. Compare to the brand-side language from Phase 1.

**Recurring descriptors.** List the words AIO consistently uses for the brand (function, scale, customer type, etc.).

**Notably absent descriptors.** List the brand's own pillars that did not appear in any AIO answer where it was cited. This gap is the heart of Section 1.

**Buyer-journey coverage.** Map the buckets across stages: problem-aware, solution-aware, comparison. There is no branded stage, because there are no branded queries. Report each stage's owned / partial / invisible counts.

**Off-site action list.** From the third-party citations across the reads, list the external domains AIO pulls from in the category. Group them: listicle publishers, educational hubs, review sites, communities.

**AIO-revealed peers.** From the citation lists on the queries where the brand is absent, list the brands AIO cites instead. Do not seed a competitor list. This is observed output. Note how AIO frames the relationship (default reference point, enterprise alternative, free option, secondary alternative, etc.).

### Phase 6 - GEO score (brand-only composite, 0-100)

Use a transparent four-component weighted index (no brand-query component — the query set is category-only). Each component is scored 0 to 100, then weighted. This mirrors `scripts/normalize_aio.js`.

| Component | Weight | How to score |
|---|---|---|
| In-Overview inclusion | 35% | Owned queries divided by triggered (AIO-fired) queries, as a percentage. The core citation rate. |
| Category presence | 25% | Share of triggered queries where the brand is cited or named (owned + mentioned-not-cited). |
| Identity accuracy | 20% | Share of category themes where the brand appears (owned or mentioned). |
| Topic coverage breadth | 20% | Share of category themes the brand owns outright. |

Bands: 0 to 25 Absent, 26 to 50 Low, 51 to 75 Competitive, 76 to 100 Dominant.

The four components, each with its weight, are printed in the "What's in the score" block inside the executive summary, so the score is reproducible.

### Phase 7 - Render

The report is HTML, rendered from the canonical JSON. Nothing is laid out by
hand.

```bash
node scripts/render-roboflow.js <runDir|canonical.json> <out>.html
```

The renderer injects the AUQ top-nav, the score block, the tested-queries table
and the jump links automatically. If a section looks wrong, fix the canonical
JSON, not the template. Section order and the full key list are in
`geo-audit-handover/03-report-spec.md`.

On the one-shot path `scripts/audit-one.js` does collection, scoring and this
render in a single process, and the narrative comes out templated rather than
written.

### Phase 8 - Verify

Never hand over a degraded audit. Check the run first:

```bash
GEO_AUDIT_ENGINE_DIR="$GEO_AUDIT_ENGINE_DIR" node <skill-dir>/scripts/verify.js acme.com
```

A domain is clean when the AIO trigger rate is above zero and errored queries
are few. Anything flagged BAD had DataForSEO failing or refusing reads, and must be re-run
solo before it goes anywhere.

Then check the rendered reports against the writing rules:

```bash
node scripts/check-reports.js "$GEO_AUDIT_OUT_DIR"
```

The checker exempts measured data (the citations, peers and tested-queries
sections, cited domains, and verbatim quotes), so a cited tool domain is a
finding, not a violation. If the reports were rendered with
`GEO_AUDIT_GTM_ID=off`, run the check with it set too.

### Phase 9 - Deliver

Report the GEO score, the band, and the local path of the file. Reports are
local HTML and nothing is published anywhere.

Before handing anything over, stamp the banners and rebuild the local index:

```bash
node scripts/inject-banners.js "$GEO_AUDIT_OUT_DIR"
node scripts/move-case-studies.js "$GEO_AUDIT_OUT_DIR"
node scripts/build-index.js "$GEO_AUDIT_OUT_DIR"
```

A rendered report has no conversion path on it until the banner scripts run.

The public **auq.io/audits/** page is a separate repo
(`KirillAuq/auq-geo-audits`) with its own index design and generator. To add
audits there, commit only the `<slug>.html` report files and rebuild with that
repo's `python3 build-index.py`; never copy this engine's `index.html` or any
run evidence (`.data/`, `evidence/`, `*.tgz`) into it. See
`05-output-and-index.md` → "Publishing to the auq.io/audits/ repo".

In chat, give the score and band, then finish with the two insight blocks,
**What it found** (three bullets: where it gets cited, where it's missing, how
the head-to-head queries resolved) and **Pitch** (two short paragraphs, opening
"At a glance, {Brand} scored {score}/100." and "The more interesting piece,
though:"). Ground both in `node scripts/insights.js <domain>` (engine), which uses `analysis.insightFacts` or computes it from `memory.json` when a hand-written canonical omits it. The
format, rules and worked examples are in the skill's `SKILL.md`, step 7. Add any
methodological caveat. Do not paste the report into chat. The user opens it.

If a domain could not be measured, say so. Never emit a zero as if it were a
result.

## 6. House style

The palette and layout live in `templates/roboflow.css` and are applied by the
renderer. Do not restyle per report.

| Role | Value |
|---|---|
| Header fill | `#1F2937` |
| Accent | `#2563EB` |
| Alternating row fill | `#F3F4F6` |
| Muted label | `#6B7280` |

## 7. Writing rules

These apply to every line of client-facing copy. They are requirements.

- **No em dashes.** Periods or commas.
- **No en dashes.** Write "days 1 to 30", not "days 1 - 30".
- **Maximum 2 sentences per paragraph.**
- **Roughly 30 words per paragraph maximum.**
- **No filler.** Short, direct sentences.
- **No third-party tool names.** Never name the search-intelligence platform in
  the deliverable. Say "premium tools" or "search-intelligence data". This rule
  applies to the report only, not to internal notes.
- **"Label. value"**, not "Label: value", in labeled fields.

## 8. Verification checklist

- [ ] `verify.js` reports the domain clean.
- [ ] Em-dash count is zero.
- [ ] En-dash count is zero.
- [ ] No third-party tool names in the report's own prose (`check-reports.js` passes).
- [ ] "What do LLMs say the brand is?" is the homepage line, one description-match percent, and a short miss list, or it says not scored. It does not dump answers or reuse AI Overview citations.
- [ ] The peers section is observed, never seeded from an input list.
- [ ] The band is stated in words next to the number.
- [ ] Every coverage row traces to a query in the tested-queries table.

## 9. Common pitfalls

- **Weak identity file.** No categories means no themes, empty coverage, and a
  meaningless score. This is the single biggest quality lever.
- **Category roots that double.** "IoT platform" plus a platform modifier gives
  "IoT platform platform". Use bare roots.
- **Wrong AI surface for the score.** The 0 to 100 score is Google AI Overviews
  only. Not AI Mode. The section "What do LLMs say the brand is?" does ask
  ChatGPT, Gemini, Claude, and Perplexity. Those answers stay out of the score
  and out of the AI Overview query set. See `06-llm-identity.md`.
- **Seeding peers.** Peers are observed. Passing a competitor list in crosses
  into a different audit.
- **Naming the search-intelligence tool in the report.** Run the check.
- **Em dashes.** Run the check.
- **Long paragraphs.** More than 2 sentences or ~30 words, split it.
- **Calling a theme invisible when no query tested it.** That is "not measured",
  which is a different claim.

## 10. Time and cost

A clean single audit takes about 2 minutes: two rounds of Standard-queue tasks, 60 seconds apart, processed in parallel by DataForSEO. Progress prints queue status lines and then one line per query, and each HTTP request is cut off after `GEO_AUDIT_REQUEST_TIMEOUT_SEC` (default 120). Cost is the AIO reads: 30 to 40
queries at 2 samples is 60 to 80 reads at $0.0024 each with async loading, about
$0.19 per audit, plus up to $0.004 for any read that falls back to Live. The run records the actual spend in `aio.cost`.
Optional Ahrefs enrichment bills by rows returned, so log the units field as you
go or the run's cost is not recoverable.
