---
name: geo-audit
description: Run brand-only GEO (Generative Engine Optimization) audits for one or more domains supplied by the user, measuring how Google AI Overviews (AIO) represent each brand, and produce a polished HTML report per domain (AUQ house design). Use whenever the user provides a domain or a list of domains to audit — e.g. "run GEO audits for acme.com, beta.io", "audit these domains", "GEO score for these prospects". Reads Google AI Overviews per positioning query via DataForSEO's Standard queue at high priority, about 2 minutes and $0.19 per audit (no metered Anthropic key). Reports are written as local HTML files and indexed locally. Nothing is published to a host and no step uses git. Portable: all machine-specific paths and keys come from environment/config, nothing is hardcoded.
---

# GEO Audit — brand-only, multi-domain, on-demand

Given a list of domains from the user, this skill produces one AIO positioning report (`.html`) per domain, plus a local index page. It is the packaged, repeatable form of the audit pipeline. Everything machine-specific is read from config so the skill can be handed to other Claude Code users.

## What it produces

For each domain: a single self-contained HTML report scoring how Google's AI Overviews represent the brand — trigger rate, citation rate, identity match, topic breadth — rolled into an overall GEO score (0–100) with a band (Absent / Low / Competitive / Dominant). The report uses the AUQ house design and renders the AUQ top-nav, an "AI Overview Performance" section immediately followed by the "Queries We Tested" log (columns: Query, brand in the AI answer, top sources cited; no Type column), key findings, identity gap, citations, and an observed-peers set. It does **not** include a "30-Day Priority Moves" or a "Success Metrics" section, and it never calls the metered console.anthropic.com key.

## Prerequisites (one-time — see SETUP.md)

This skill drives an external engine and needs three things configured. If any are missing, read `SETUP.md` in this skill folder and walk the user through it before running.

Config is read from environment variables (a user can keep them in a shell profile or a `config.sh` they source):

| Variable | Required | Meaning |
|---|---|---|
| `GEO_AUDIT_ENGINE_DIR` | **yes** | Absolute path to the engine directory, `engine/` in this bundle (contains `scripts/audit-one.js` and `.env` with the DataForSEO keys). |
| `GEO_AUDIT_OUT_DIR` | no | Where rendered `.html` reports are written. Default: `$GEO_AUDIT_ENGINE_DIR/../audit-output`. |
| `GEO_AUDIT_IDENTITY_DIR` | no | Where per-domain identity JSON files are written/read. Default: `$GEO_AUDIT_OUT_DIR/identities`. |
| `AIO_SAMPLES` | no | Samples per query. Default and tested value is **2**. Higher is more stable and more expensive. |
| `GEO_AUDIT_MAXJOBS` | no | Batch concurrency. Default **2**; the runner clamps to 2 (see the DataForSEO limits note). |
| `GEO_AUDIT_STAGGER` | no | Seconds between audit launches. Default **4**. |
| `GEO_AUDIT_AIO_MODE` | no | How AI Overviews are read. `standard` (default): DataForSEO Standard queue at high priority. `live`: one Live request at a time, about 7x slower; for comparison runs only. |
| `GEO_AUDIT_PRIORITY` | no | Standard queue priority. `2` = high (default, about 1 minute turnaround). `1` = normal (about 5 minutes, half the price). |
| `GEO_AUDIT_SAMPLE_STAGGER_SEC` | no | Seconds between posting sample round 1 and round 2. Default **60**, so the two samples are not taken at the same instant. |
| `GEO_AUDIT_STRAGGLER_SEC` | no | A queued read not back after this many seconds is re-read Live. Default **90**. |
| `GEO_AUDIT_POLL_SEC` | no | Seconds between `tasks_ready` checks. Default **10** (6 calls a minute; the account-wide limit is 20). |
| `GEO_AUDIT_REQUEST_TIMEOUT_SEC` | no | Time limit per DataForSEO HTTP request. Default **120**, which is what DataForSEO recommends for SERP calls. |

**DataForSEO credentials are required and are provided by AUQ**, separately from this bundle. Put them in `engine/.env` (copy `.env.example`), as `SETUP.md` describes. Without them every query returns "fetch failed" and the audit scores 0. If AUQ instead supplies a shared `team-config.env` at the skill root, `run-batch.sh` sources it and its values win over the engine `.env`.

Nothing needs installing: the audit pipeline has no npm dependencies and runs on a stock Node install.

## Inputs

A list of bare domains from the user (`acme.com beta.io ...`), passed as skill arguments or in the message. De-duplicate first. Optionally a user may pass `domain:slug` to override the output slug; otherwise slug = the first DNS label (`acme.com` → `acme`).

## Workflow

### 1. Resolve config and sanity-check the engine
- Confirm `GEO_AUDIT_ENGINE_DIR` is set and contains `scripts/audit-one.js`. If not, stop and go to `SETUP.md`.
- Confirm `engine/.env` has the DataForSEO credentials AUQ provided (or that a `team-config.env` sits at the skill root). If neither is true, stop and go to `SETUP.md` — otherwise every query returns "fetch failed" (score 0).
- Create `GEO_AUDIT_OUT_DIR` and `GEO_AUDIT_IDENTITY_DIR` if missing.

### 2. Derive one identity file per domain (quality-critical)
For each domain, build an identity JSON at `$GEO_AUDIT_IDENTITY_DIR/<slug>.json`. This drives every query, so it must be accurate. Derive it from the brand's own site (fetch the homepage + a product/about page) — use `templates/identity.example.json` as the schema:

```json
{
  "brand": "Acme",
  "products": ["Acme Shield", "Acme Cloud"],
  "categories": ["endpoint security", "threat detection", "cloud security", "vulnerability management", "incident response"],
  "competitors": ["CrowdStrike", "SentinelOne", "Wiz"]
}
```

Rules that matter (learned from real runs):
- **`categories`**: 4–6 *non-branded* category terms that a buyer would search. These are the theme roots the query builder multiplies by intent modifiers.
  - Use **bare roots**. Do **not** end a category in a word the modifier will double — no trailing "software", "platform", "solutions", "tools". "IoT platform" + a "platform" modifier renders "IoT platform platform". Write "IoT" / "device management", not "IoT platform".
  - Make them distinct from each other and genuinely reflect what the brand does.
- **`brand`**: the real brand name, which often differs from the domain (watch brand-vs-product naming).
- **`products`**: 0–3. Also matched as brand aliases, so an AI answer containing a product name counts as "mentioned, not cited". Only distinctive names; never common words like "Evaluate". Leave it empty if in doubt.
- **`competitors`**: 2–3 real head-to-head names (observed, never used to score — they only seed the comparison query layer).

### 3. Run the batch
Run the bundled runner from this skill folder. It calls `audit-one.js` once per domain, writing `<slug>.html` into the output dir, at safe concurrency:

```bash
GEO_AUDIT_ENGINE_DIR="$GEO_AUDIT_ENGINE_DIR" \
GEO_AUDIT_OUT_DIR="$GEO_AUDIT_OUT_DIR" \
GEO_AUDIT_IDENTITY_DIR="$GEO_AUDIT_IDENTITY_DIR" \
AIO_SAMPLES="${AIO_SAMPLES:-2}" GEO_AUDIT_MAXJOBS="${GEO_AUDIT_MAXJOBS:-2}" GEO_AUDIT_STAGGER="${GEO_AUDIT_STAGGER:-4}" \
bash "<skill-dir>/scripts/run-batch.sh" acme.com beta.io ...
```

**DataForSEO limits note:** reads go through the Standard queue at high priority. Each audit posts 2 rounds of tasks (60s apart) and polls `tasks_ready`, which DataForSEO limits to 20 calls a minute for the whole account; each audit uses 6. Keep `GEO_AUDIT_MAXJOBS` at 2 (the runner clamps to it). One audit takes about 2 minutes and costs about $0.19. Anything the queue cannot deliver cleanly, or that is still queued after 90 seconds, is re-read over Live automatically. Run batches in the background. Each domain prints queue status lines and then a line per query to `$GEO_AUDIT_OUT_DIR/_<slug>.out`; check that file before assuming a run is stuck.

### 4. Verify — never hand over a degraded audit
After the batch, run the verifier to catch failed or unfinished runs:

```bash
GEO_AUDIT_ENGINE_DIR="$GEO_AUDIT_ENGINE_DIR" node "<skill-dir>/scripts/verify.js" acme.com beta.io ...
```

It reports, per domain, the AIO trigger rate and errored-query count from the latest run. A domain is **clean** when `trigger > 0` and errored queries are few (≤5 of ~39). Any domain flagged **BAD** (trigger 0, or many errored queries) had DataForSEO failing or refusing reads, including their Live fallbacks. **PART** means the latest run is still collecting or was stopped part-way. **Re-run** either solo and re-verify:

```bash
GEO_AUDIT_ENGINE_DIR="$GEO_AUDIT_ENGINE_DIR" AIO_SAMPLES="${AIO_SAMPLES:-2}" \
node "$GEO_AUDIT_ENGINE_DIR/scripts/audit-one.js" acme.com "$GEO_AUDIT_IDENTITY_DIR/acme.json" "$GEO_AUDIT_OUT_DIR/acme.html"
```

Do not report scores or hand over files until every requested domain is clean.

### 5. Finish the reports (local, no host)
Reports stay on disk. There is no publish target, no repo, and no network step.

Every report carries the AUQ GTM container, so opens are tracked. Render with `GEO_AUDIT_GTM_ID=off` for a client whose agreement forbids a tag.

Stamp the conversion banners onto every report, then rebuild the local index:

```bash
node "$GEO_AUDIT_ENGINE_DIR/scripts/inject-banners.js" "$GEO_AUDIT_OUT_DIR"
node "$GEO_AUDIT_ENGINE_DIR/scripts/move-case-studies.js" "$GEO_AUDIT_OUT_DIR"
node "$GEO_AUDIT_ENGINE_DIR/scripts/build-index.js" "$GEO_AUDIT_OUT_DIR"
node "$GEO_AUDIT_ENGINE_DIR/scripts/check-reports.js" "$GEO_AUDIT_OUT_DIR"
```

If the reports were rendered with `GEO_AUDIT_GTM_ID=off`, run `check-reports.js` with it set too. The first three are idempotent and safe to run across the whole folder. A rendered
report has no CTA until the banner scripts run, so do not skip them. The index
is regenerated from whatever reports are in the folder, so rebuild it after
every batch.

Publishing to the **auq.io/audits/** page is a separate step with its own rules:
that is its own repo (`KirillAuq/auq-geo-audits`) with its own index design and
generator. Commit only the `<slug>.html` report files there and rebuild with
that repo's `python3 build-index.py` — never copy this engine's `index.html` or
any run evidence (`.data/`, `evidence/`, `*.tgz`) into it. See
`05-output-and-index.md` → "Publishing to the auq.io/audits/ repo".

### 6. Report back
Give the user a table of every domain with its GEO score and band, plus the local file path of each report and of the index. Call out notable results (Dominant / Absent). Report failures honestly — if any domain could not be measured, say so rather than emitting a 0. Then do step 7.

### 7. Insights in chat: "What it found" and "Pitch" (final step, every audit)
After the table, write two blocks **per clean domain**, directly in the chat. This is the last thing the user sees. Skip any domain that is not clean.

First print the fact sheet, which is the only source these blocks may draw on:

```bash
GEO_AUDIT_ENGINE_DIR="$GEO_AUDIT_ENGINE_DIR" node "<skill-dir>/scripts/insights.js" acme.com beta.io ...
```

This is a thin wrapper over the engine's `scripts/insights.js` (logic in `src/insights.js`). Every run made by `audit-one.js` or `normalize_aio.js` stores these facts in `canonical.json` as `analysis.insightFacts`; for older runs the script computes them from `memory.json`. Add `--json` for the structured object. It reads the latest complete run per domain (no network) and prints the score, each theme's verdict (same rule as the report's coverage table) with the domains cited instead, every comparison and branded query with its top sources, the domains that win where the brand is absent, any Wikipedia citations, and the homepage title.

**What it found**: exactly three bullets, in this order and with these bold labels:
- **Where {Brand} gets cited:** the STRONG themes, plus the branded or comparison queries it owns.
- **Where it's missing:** the MISSING themes. If one of them is what the brand leads with on its own homepage (compare with the homepage title), say that this is the biggest gap.
- **Head-to-head queries:** how the "{Brand} vs X" and "alternatives to {Brand}" queries resolved, naming them in quotes.

**Pitch**: two short paragraphs, conversational, written as AUQ talking to the prospect.
1. Start with "At a glance, {Brand} scored {score}/100." Then say what makes this audit different from the usual picture, in one or two sentences.
2. Start with "The more interesting piece, though:" and give the single most striking finding, then what it costs the brand, naming the domains or brands that take the queries instead.

What makes a good "most interesting piece", strongest first:
- **The brand name means something else.** Branded or comparison queries cited by off-topic sources (for Felt, "alternatives to Felt" cites crafts.stackexchange.com and a roofing store, because felt is also a material), or Wikipedia on a branded query. The identity is displaced before the category conversation starts.
- **The headline category is missing.** The homepage leads with a category the brand is absent from.
- **A strong brand not getting cited.** If an SEO data connector is available (Ahrefs or Semrush), check the domain's top organic keywords. A brand that ranks organically for a category but is absent from the AI answers is a strong angle ("it's just not making the jump into AI citations"). Only use this when you pulled the data in this session.
- **One peer takes everything.** A single domain that dominates the queries where the brand is absent.

Rules:
- Every claim must trace to the fact sheet, or to data you fetched in this session. Never say what the AI answer said beyond what its cited sources show. The run stores cited domains, not answer text.
- Use the report's numbers exactly. Do not round the score or recount citations.
- Name cited domains as they appear, or as the brand behind them (esri.com as Esri) when it is obvious.

Example 1, felt.com (43/100, Low), grounded only in the fact sheet:

**What it found**
* **Where Felt gets cited:** answers about web mapping (5 of 7 queries) and geospatial data visualization.
* **Where it's missing:** answers about cloud GIS (cited on 1 of 7), online map maker and spatial analysis (0 of 7 each). "Cloud-Native GIS" is the headline on Felt's own homepage, so being missing there is the biggest gap.
* **Head-to-head queries:** "Felt vs Esri ArcGIS Online", "Felt vs CARTO" and "Felt vs Mapbox" all put felt.com as the first source. "Alternatives to Felt" names Felt but doesn't cite its site.

**Pitch**

> At a glance, Felt scored 43/100. It's a split picture: Felt is the first source Google's AI cites when someone compares it head-to-head with Esri, CARTO or Mapbox, and it holds its own on web mapping. It's the broader category searches where it drops out.
>
> The more interesting piece, though: Felt's homepage leads with "cloud-native GIS", and that's exactly where the AI leaves it out. Felt is cited on 1 of 7 cloud GIS queries, and CARTO, GIS Cloud and Esri take the rest. "Online map maker" goes to Canva and Inkarnate, and spatial analysis goes to Esri and QGIS. Even "alternatives to Felt" cites a crafts forum and a roofing store alongside Reddit, so the name competes with the material too.

Example 2, Pitch only, sangoma.com (44/100). It uses organic ranking data pulled in the same session, which is the "ranks organically but not cited" angle:

> At a glance, Sangoma scored 44/100. This one's a slightly different picture than most audits we run: the product itself ranks organically on a lot of high-value queries (unified communications as a service, hotel phone systems), it's just not making the jump into AI citations.
>
> The more interesting piece, though: on the single highest-volume query for the brand name itself, Google's AI answers with the Zulu term for a traditional healer, not the company — Wikipedia owns that space. It means the identity gets displaced before the UCaaS conversation even starts, and category queries like "best UCaaS providers" go to Vonage, 3CX, and Ooma instead.

## Notes
- The renderer already injects the AUQ top-nav, the Queries-We-Tested section under AI Overview Performance, and omits the 30-Day Moves / Success Metrics sections. No post-processing is needed for layout.
- `audit-one.js` writes `.data/runs/<runId>/{memory.json,canonical.json}` in the engine dir — that is the source of truth for verification and index cards.
- This is brand-only: peers that surface in the data are reported as observed, never taken as scoring input.
