# 03 — Report spec

The deliverable is one self-contained HTML file in the AUQ house design.

Reference render, for the hand-authored format only:
**https://auq.io/audits/8020rei.html**

**That page is not engine output.** The engine's renderer produces a different,
narrower report. Both are described below. Read the last section before assuming
a change belongs in the renderer.

Where that specific page was authored is unconfirmed. It is not in any local
checkout: no `8020rei.html` and no "size of the gap" markup exists anywhere on
this machine. What is confirmed is that hand-authored audits in this style do
exist, under `~/Claude Code Projects/kirillauq-repo/`, and two of them use band
wording ("Barely visible") the engine's scorer never emits.

## Section order — lineage B, the hand-authored report

| # | Section | What it holds |
|---|---|---|
| — | Top nav | AUQ logo to auq.io, centered links (AUQ GEO, GEO Analytics, Pricing, Our Team), Contact Us CTA right. Sticky, collapses to logo plus CTA below 820px. Injected automatically. |
| — | Hero | Brand, domain, "GEO AUDIT · BRAND-ONLY", date prepared, prepared by AUQ, and the **AI Visibility Score** out of 100 with its band. |
| 1 | Executive summary | Two or three framing paragraphs. |
| 2 | What's in the score | The four weighted components, each with its value. Makes the score reproducible. |
| 3 | Identity in AI Overviews | The centerpiece. What the brand says about itself, what the answer engines say, the core gap, entities the rivals own, entities attached to the brand. Quote blocks, side by side. |
| 4 | The size of the gap | Table: Brand, Domain, Google AIO mentions, Google AI search volume, ChatGPT mentions, ChatGPT AI search volume. |
| 5 | Every AI answer that cites the brand | Table: Engine, Query, AI search volume, Status, Page. |
| 6 | Content and entity coverage | Table: Theme, Presence in AI answers, Buyer intent. Plus a buyer-journey coverage block. |
| 7 | How to read this | Method and limits, the query set, captured versus uncaptured answers, why the limitation does not change the conclusion, the cited/named/absent definitions, what AI search volume means. |
| 8 | Queries we tested | Every query run, whether the brand was in the AI answer, and the top sources cited. Three columns: Query, Brand in the AI answer, Top sources cited. There is no Type column; the query's layer stays in `analysis.testedQueries` but is not shown. The 8020REI run shows 39 rows. |
| 9 | Three findings that matter | Finding 01, 02, 03. |
| 10 | Top three moves | Move 01, 02, 03. |
| 11 | Where the answer engines get their answers | Table: Domain the AI cites, Appearances, Context. Plus a reading. |
| 12 | AI-revealed peers | Table: Peer, Domain, How the answer engines carry it. Plus a key observation. |
| 13 | 90-day roadmap | Month 1 days 1 to 30, Month 2 days 31 to 60, Month 3 days 61 to 90. |
| — | Footer | Brand lowercase, "GEO AUDIT · BRAND-ONLY · {DATE}", "PREPARED BY AUQ · ANALYTICS@AUQ.IO". |

Data-driven sections carry a jump-link CTA into section 8, so any claim can be
traced to the query that produced it.

## Canonical JSON the renderer consumes

The renderer reads one object. You author it during the analysis stage.

```jsonc
{
  "meta": {
    "domain": "acme.com",
    "completedAt": "2026-09-07T00:00:00Z"
  },

  "geoScore": {
    "brand": "Acme",
    "overallScore": 10,
    "band": "Absent",
    "bandDescription": "short sentence shown under the score",
    "components": [
      { "label": "Your pages being quoted",        "weightPct": 35, "scoreOutOf100": 11 },
      { "label": "Inclusion in category answers",  "weightPct": 25, "scoreOutOf100": 11 },
      { "label": "How AI describes the brand",     "weightPct": 20, "scoreOutOf100": 17 },
      { "label": "Topic coverage breadth",         "weightPct": 20, "scoreOutOf100": 17 }
    ],
    "topLeverageMoves": [ /* the top three moves */ ],
    "roadmap90Day": { /* three sprints */ },
    "successMetrics": [ /* metric, baseline, target */ ]
  },

  "analysis": {
    "identityGap": { /* brand-says vs AI-says, quotes, descriptors, gap */ },
    "contentCoverage": { /* theme rows, buyer-journey coverage */ },
    "aioPerformance": {
      "aioTriggerCount": 0,
      "aioTriggerRate": 0,
      "aioTriggerRatePct": 0,
      "brandCitedInAioCount": 0,
      "brandCitationRate": 0,
      "brandCitationRatePct": 0,
      "brandPositionWhenCited": null,
      "mentionsTotal": 0,
      "trackedKeywords": 0,
      "highValueMissedKeywords": [],
      "aioAppearanceNotes": "",
      "context": ""
    },
    "citationLandscape": { /* external domains cited, grouped */ },
    "aioRevealedPeers": { "peers": [], "keyObservation": "", "note": "" },
    "testedQueries": [
      { "query": "best endpoint security", "layer": "positioning",
        "bucket": "invisible", "citedTop": ["g2.com", "gartner.com", "csoonline.com"] }
      // layer is "positioning" or "comparison" (the engine emits no branded layer)
      // bucket is "owned" | "mentioned_not_cited" | "invisible" | "aio_pending" | "no_aio"
    ],
    "insightFacts": {
      // Not rendered. Grounding for the "What it found" and "Pitch" chat step.
      // Built by src/insights.js; normalize_aio.js adds it on every run.
      "brand": "Felt", "domain": "felt.com", "score": 43, "band": "Low",
      "triggerRatePct": 97, "queryCount": 39,
      "counts": { "cited": 12, "namedNotCited": 1, "absent": 25, "noAio": 1 },
      "homepageTitle": "Cloud-Native GIS Software & Online Mapping Platform",
      "homepageUrl": "https://felt.com",
      "categories": [], "competitors": [],
      "themes": [
        { "theme": "cloud gis", "verdict": "missing", "queries": 7, "cited": 1,
          "citedOn": ["cloud gis platform"],
          "citedInstead": [{ "domain": "carto.com", "count": 6 }] }
        // verdict is "strong" | "missing" | "named_only", same rule as contentCoverage
      ],
      "brandedQueries": [],
      "comparisonQueries": [
        { "query": "Felt vs CARTO", "bucket": "owned", "ownSourcePosition": 1,
          "topSources": ["felt.com", "carto.com", "sourceforge.net", "youtube.com"] }
      ],
      "topDomainsWhereAbsent": [{ "domain": "esri.com", "count": 16 }],
      "wikipediaCitedOn": ["cloud gis vendors"]
    },
    "analyzedAt": "2026-09-07T00:00:00Z"
  }
}
```

`analysis.testedQueries` is mandatory. Without it the renderer falls back to raw
`aio.results`, which is lossier.

`analysis.insightFacts` is optional and never rendered. The one-shot path always
writes it. A hand-written canonical can omit it: `scripts/insights.js` computes
the same object from `memory.json` when the key is missing.

Rendering is a pure function of this object. If a section looks wrong, fix the
JSON first, not the template.

## Writing rules

These apply to every line of client-facing copy. They are requirements, not
preferences. Run the checks before delivering.

- **No em dashes.** Periods or commas.
- **No en dashes.** Write "days 1 to 30", not "days 1 - 30".
- **Maximum 2 sentences per paragraph.**
- **Roughly 30 words per paragraph maximum.**
- **No filler.** Short, direct sentences.
- **No third-party tool names.** Never name the search-intelligence platform in
  the deliverable. Say "premium tools" or "search-intelligence data". This rule
  is for the report only, not for these internal docs.
- **"Label. value"**, not "Label: value", in labeled fields and inline
  annotations. `Domain.` `Reading.` `Note.`

Check before shipping:

```bash
node scripts/check-reports.js "$GEO_AUDIT_OUT_DIR"
```

**What counts as a tool-name violation.** The rule is about the report naming
our tooling in its own prose. It is not about the data. A citation listing
`semrush.com` is the audit reporting what Google's AI cited, which is the
finding. So before matching names, the checker removes three kinds of measured
data:

- the sections "Where Google's AI gets its answers", "AI-revealed peers" and
  "Queries we tested"
- any domain-shaped token anywhere in the report (`semrush.com`,
  `enterprise.semrush.com`), since those only appear as cited sources, including
  the "Appears alongside ..." lines in the identity section
- `<blockquote>` bodies, which quote the brand's site or Google's AI verbatim

The dash rules still apply to the whole document.

Names match case-insensitively, so "Semrush" and "SEMrush" both fail. CSS
vendor prefixes like `-moz-` cannot trip it because `<style>` and `<script>`
bodies are removed before any matching.

The checker also checks the analytics tag against the render setting. By
default every report must carry it. Run with `GEO_AUDIT_GTM_ID=off` and it
requires the opposite: no tag, so a client report that must be untracked passes,
and one that leaked a tag fails.

Note that nothing in the engine uses Semrush. It sits in the blocklist only so
the name cannot reach a deliverable; the engine's data comes from DataForSEO,
with Ahrefs optional.

## House palette

Defined in `engine/templates/roboflow.css` and applied by the renderer. Do not
restyle per report.

| Role | Value |
|---|---|
| Header fill | `#1F2937` |
| Header text | `#FFFFFF` |
| Accent (score number, quote bar) | `#2563EB` |
| Alternating row fill | `#F3F4F6` |
| Muted label | `#6B7280` |
| Table border | `#BFBFBF` |

## Section order — lineage A, what the engine renders

`engine/scripts/render-roboflow.js`, in call order:

1. Top nav
2. Hero, with the AI Visibility Score and band
3. Executive summary
4. Identity in AI Overviews
5. Content and entity coverage
6. AI Overview performance, plus high-value queries where the brand ranks but is not quoted
7. Queries we tested
8. Three findings that matter, then top three moves
9. Where Google's AI gets its answers
10. AI-revealed peers
11. 90-day roadmap
12. Footer

Google AI Overviews only. No ChatGPT columns, no AI search volume.

## The gap between the two

Lineage B has three sections the engine does not render at all: "The size of
the gap", "Every AI answer that cites the brand", and "How to read this". It is
also multi-engine. ("What's in the score" does exist in engine output, inside
the executive summary's score block.)

Nothing in the engine produces those. If you want them in engine output,
they have to be built. Until then an engine-produced report and a hand-authored
one are different documents, and anyone comparing them will notice.

`moves()` and `metrics()`, the dead builders for 30-Day Priority Moves and
Success Metrics, were deleted in the 2026-09-14 cleanup. The canonical JSON
still carries `topLeverageMoves` and `successMetrics`; the top three moves are
rendered inside the findings section, and success metrics are not rendered at
all.
