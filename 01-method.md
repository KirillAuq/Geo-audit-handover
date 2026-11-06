# 01 — Method

What the audit measures, how the query set is built, how a query is classified,
and how the score is computed. This is the reasoning; `02-running-an-audit.md`
is the button-pushing.

## Surface

Google AI Overviews only. Not AI Mode, not ChatGPT, not Perplexity, not Gemini.
If the SERP reader cannot return AI Overview data, stop and say so. There
is no acceptable substitute: neither the Google Search API nor the Gemini API
reads AIO.

(The report at auq.io/audits/8020rei.html also carries ChatGPT columns. That one
is hand-authored, not engine output. Nothing in this bundle reads any engine but
Google AI Overviews. See `04-bundle-map.md`.)

## Stage 1 — Identity extraction

Fetch the homepage plus at most two or three of `/about`, `/products`,
`/pricing`, `/customers`. This is identity grounding, not a crawl.

Extract: brand name, one-line value proposition, the category the brand claims
for itself, product and module names, use cases, audience signals, proof points,
and any named on-site competitors ("Compare with X" pages).

Write it to `identity.json`. The schema:

```json
{
  "brand": "Acme",
  "products": ["Acme Shield", "Acme Cloud"],
  "categories": ["endpoint security", "threat detection", "cloud security",
                 "vulnerability management", "incident response"],
  "competitors": ["CrowdStrike", "SentinelOne", "Wiz"]
}
```

This file drives every query, so it decides the score. Rules that were learned
the hard way:

- **`categories`** — 4 to 6 non-branded terms a buyer would actually search.
  These are the theme roots the query builder multiplies by intent modifiers.
  Use **bare roots**. Never end one in "software", "platform", "solutions" or
  "tools", because a modifier will double it ("IoT platform platform"). Write
  "IoT" or "device management", not "IoT platform". Make them distinct and true.
- **`brand`** — the real brand name, which often differs from the domain. Watch
  brand-versus-product naming: if the domain is `acme.com` but the product is
  "AcmeShield Pro", the comparison layer needs the product name.
- **`products`** — 0 to 3. Used for differentiator text, and also matched as brand aliases: an AI answer containing a product name counts as "mentioned, not cited". List only distinctive names ("AcmeShield"). Never a common word like "Evaluate" or "Observe"; leave the list empty rather than risk false mentions. Never used to build queries.
- **`competitors`** — 2 to 3 real head-to-head names. They seed the comparison
  layer only. They are never scoring input.

A run without categories produces empty coverage and a meaningless score. Best
practice: run collection once to fetch the site, derive `identity.json` from the
`site` memory, then re-run with it.

## Stage 2 — Query set construction

A thinking step, not a data pull. Never build the set from a keyword index
ranked by traffic.

**Category layer (the core, ~35 queries).** Cross each category term with the
decision-stage modifier set, about 7 per theme:

```
best {t}          {t} vendors        {t} solutions      {t} software
{t} platform      top {t} providers  {t} comparison
```

**Comparison layer (lean, ~4 queries).** `alternatives to {brand}` and
`{brand} vs {competitor}` for the top 2 or 3 competitors. Peer discovery only.

Target 30 to 40 queries total.

There is deliberately **no branded layer**. "What is {brand}", "{brand}
reviews", "{brand} pricing" are trivially won and inflate the score with
meaningless data.

Optional volume weighting: pass the already-built list to a keyword tool for
volume to prioritize it. Never let a keyword tool generate or reorder the set.

Save the query set to a file for traceability. Do not deliver it to the client
unless asked.

## Stage 3 — AIO read

For each query, read the Google AI Overview from a real Google SERP. US location,
`en`, desktop. Query-anchored, so it works whether or not the brand ranks.

**How the reads are made.** DataForSEO's Standard queue at high priority
(`serp/google/organic/task_post` with `priority: 2`). Every query for a sample
round goes in one request, DataForSEO processes them in parallel, and the engine
collects results with `tasks_ready` and `task_get/advanced`. High priority
averages about a minute; in practice most reads are back within 30 seconds.

A read that the queue cannot deliver cleanly is re-read over Live
(`serp/google/organic/live/advanced`): a task the queue refused, a failed task,
an AI Overview that came back unreadable, or a task still queued after 90 seconds
(`GEO_AUDIT_STRAGGLER_SEC`). Live re-requests an unreadable AI Overview up to 3
times, 6 seconds apart. So no read waits on the queue indefinitely, and an
unreadable answer gets the same retry treatment it always had.

Capture per query: did an `ai_overview` element appear, the answer text, and
every cited URL with its registrable domain.

The rules:

- **Sample each query 2 to 3 times.** AIO triggering is volatile. Treat a query
  as triggered if it fired on any sample, and record the per-query trigger rate.
  `audit-one.js`, `collect-only.js` and `scripts/aio-read.js` all pass
  `AIO_SAMPLES || 2`, so **2 is the default** on every path.
- **Space the samples out.** Round 2 is posted 60 seconds after round 1
  (`GEO_AUDIT_SAMPLE_STAGGER_SEC`). Two reads submitted at the same instant are
  less independent than two reads a minute apart, which defeats the point of
  sampling.
- **Set `load_async_ai_overview: true`.** Without it roughly one query in three
  returns an unreadable `asynchronous_ai_overview` stub, and re-polling does not
  fix it. It adds $0.0006 per read on the Standard queue and is required for
  trustworthy coverage. It works on both the Standard queue and Live.
- **Every HTTP request has a time limit.** 120 seconds by default
  (`GEO_AUDIT_REQUEST_TIMEOUT_SEC`), as DataForSEO recommends for SERP calls. A
  request that stalls past it fails that read, which then falls back to Live or
  is recorded as an errored query, so one stuck connection cannot hold the
  audit.

Decide "is the brand cited" by matching the citation's registrable domain to the
target domain. Never by string-matching the brand name in the answer text.

## Stage 4 — Deterministic bucketing

Classify every query mechanically, before any judgment. The value in brackets is
what `src/aio-read.js` writes into `bucket`:

| Bucket | Condition |
|---|---|
| **owned** (`owned`) | Brand's domain cited as a source in the AIO. |
| **mentioned, not cited** (`mentioned_not_cited`) | Brand named in the answer text, domain not cited. |
| **invisible** (`invisible`) | AIO fired, brand neither named nor cited. Log who was cited instead. |
| **pending** (`aio_pending`) | AIO present but rendered async and unreadable. Retry. Never "invisible". |
| **not an AIO query** (`no_aio`) | No AIO across all samples. This is not "invisible" either. |

The mention-versus-citation split is the one that matters commercially. A brand
can be the named answer while its own domain is not a source. That is a citation
gap, not a presence gap, and the fix is different.

**Grounding rule.** Every row in the coverage table must trace to a query that
was actually read. A theme the brand sells but no query tested is
"not measured (recommend tracking)", never "invisible".

## Stage 5 — Analysis

From the buckets and the answer texts:

- **Rates.** AIO trigger rate, brand citation rate, position when cited.
- **Identity statements.** Verbatim sentences where AIO describes the brand.
  These become quote blocks, set side by side with the brand's own language.
- **Recurring descriptors.** Words AIO consistently attaches to the brand.
- **Notably absent descriptors.** The brand's own pillars that appear in no AIO
  answer where it was cited. This gap is the heart of the report.
- **Buyer-journey coverage.** Owned / partial / invisible counts per stage.
- **Off-site sources.** External domains AIO pulls from in the category, grouped
  into listicle publishers, educational hubs, review sites, communities.
- **AI-revealed peers.** The brands AIO cites on queries where this brand is
  absent, plus how AIO frames each one (default reference point, enterprise
  alternative, free option, and so on).

## Stage 6 — The GEO score

A transparent four-component weighted index, 0 to 100. No brand-query component,
because the query set is category-only.

| Component | Weight | Formula |
|---|---|---|
| In-Overview inclusion | 35% | owned / triggered. The core citation rate. |
| Category presence | 25% | (owned + mentioned-not-cited) / triggered. |
| Identity accuracy | 20% | Share of category themes where the brand appears at all. |
| Topic coverage breadth | 20% | Share of category themes the brand owns outright. |

Each component is scored 0 to 100, then weighted.

**Bands**

| Range | Band |
|---|---|
| 0 to 25 | Absent |
| 26 to 50 | Low |
| 51 to 75 | Competitive |
| 76 to 100 | Dominant |

State the components in the report so the score is reproducible. The band label
is printed in words next to the number.

These four components and these band labels are what `scripts/normalize_aio.js`
actually computes. Verified against the code.

The report shows exactly these four components, each labelled with its weight,
so the breakdown reconciles with the total. Verified: on a real run scoring 13,
the weighted components sum to 13.

Two components the scorer used to display were removed in the 2026-09-14
cleanup, because neither fed the total: "How often AI answers appear" (the
trigger rate, still reported in the AI Overview Performance section) and
"Quality of placement when cited" (which was never measured, only hardcoded).

The published auq.io reports use different band wording, including "Barely
visible". Those reports are hand-authored, not engine output. See the two
lineages note in `04-bundle-map.md`.

## Trade-offs, stated plainly

**Strengths.** Zero client homework, one input. Fast and cheap. A positioning
narrative rather than a leaderboard. Observed peers are usually more honest than
a client-supplied competitor list.

**Weaknesses.** No share of voice. No head-to-head "who beats us on this query".
Less commercially compelling for a client who specifically wants "how am I doing
versus X". Off-site recommendations come from category citations alone, not from
what competitors do well.

**Use it for.** One-off positioning audits, clients without a clear competitive
set, sales-cycle teaser reports, and any time the goal is to surface surprises
about how AI frames the brand.
