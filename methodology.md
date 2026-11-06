> **Runtime file, not current guidance.** `src/audit-references.js` reads this
> at run time and injects it into agent memory, so it must stay here. For how
> the audit works today, read `geo-audit-handover/01-method.md`.

# Methodology — Brand-Only GEO Audit

## Overview

A focused positioning diagnostic that answers: what do Google's AI Overviews think this brand does, what does it specialize in, and where does it show up vs. go missing in AIO results.

No competitor benchmarking. The audit reads the brand as it stands in AIO, surfaces the gaps, and produces an action plan. Competitor names that appear in the data are reported as observed findings ("AIO-revealed peers"), not as an input.

## Scope

- AI surface: Google AI Overviews only (Ahrefs Brand Radar)
- Input from client: domain only, nothing else
- Output: single .docx report
- Audit type: positioning diagnostic, not benchmark

## Questions answered

**Identity in AIO — "What does AIO think we do?"**

- When AIO describes the brand, what does it say the company does?
- What category does AIO place the brand in? Is it the right one?
- What does AIO say the brand specializes in?
- Which features, products, or use cases does AIO associate with the brand?
- Which parts of the business are invisible or under-attributed?
- Which adjectives and framings recur? Tone positive, neutral, negative?
- Are there factual errors, outdated claims, or wrong-category placements?

**AIO performance — "How does the brand actually appear in AIO?"**

- For which queries does AIO trigger at all? (AIO trigger rate)
- When AIO appears, how often is the brand cited? (AIO citation rate)
- When cited, what position is the brand in the source list?
- Which of the brand's own pages get pulled into AIO?

**Content & entity coverage — "What are we associated with?"**

- What features, use cases, and topics is the brand linked to in AIO answers?
- What buyer-journey questions (problem-aware, solution-aware, alternatives) does the brand appear in?
- Which category-defining entities is the brand missing from?

**Citation sources — simplified**

- Which of the brand's own pages get cited by AIO?
- Which external domains does AIO cite when answering about the brand or its category?

**AIO-revealed peers — observed, not input**

- When AIO answers a category query and doesn't cite the brand, who does it cite?
- These names are the de facto competitive set as Google's AIO sees it.

**Strategic output**

- Baseline GEO score (brand-only).
- Top 3–5 highest-leverage moves for the next 30 days.
- 90-day roadmap.
- Success metrics and reporting cadence.

## How it works

1. **Site extraction.** Fetch the domain's homepage plus a small set of structurally important pages (about, products, pricing, customers). Auto-extract: brand name, one-line description, category, primary use cases, audience signals.
2. **Keyword universe.** Query Ahrefs Site Explorer on the domain to pull organic keywords and top pages by traffic. This grounds the prompt set in queries the brand already engages with.
3. **Prompt set generation.** Programmatically build 20–40 prompts across three layers (see below).
4. **AIO data pull.** Fire Brand Radar AIO endpoints on the prompt set: AI response capture, cited domains, cited pages, mentions, by-entity views.
5. **Analysis.** Compute trigger rate, citation rate, position-when-cited. Extract identity statements. Identify content/entity gaps. Surface AIO-revealed peers.
6. **Report generation.** Produce .docx using the docx skill and the house style rules.

## Prompt set logic (20–40 prompts, three layers)

**Layer 1 — Brand-name queries (~5–8 prompts)**

Patterns: "what is [brand]", "[brand] reviews", "[brand] pricing", "is [brand] good for [use case]", "how does [brand] work", "[brand] alternatives".

Purpose: identity findings. Note that AIO often doesn't trigger on pure brand-name queries — absence is itself a data point.

**Layer 2 — Category queries (~12–22 prompts)**

Derived from extracted category, use cases, and top Ahrefs keywords (prioritize highest-traffic terms; do not exceed the layer cap).

Patterns: "best [category] for [audience]", "[category] software", "how to [problem]", "[category] tools comparison".

Purpose: trigger rate, citation rate, content gap analysis. Highest AIO trigger volume lives here.

**Layer 3 — Alternatives and comparison queries (~5–10 prompts)**

Seeded only by the brand name: "alternatives to [brand]", "[brand] vs", "[brand] competitors".

Purpose: surfaces AIO-revealed peers. AIO fills in the comparison side itself.

## Trade-offs

**Strengths**
- Zero client homework — runs from one input.
- Faster and cheaper to run.
- Cleaner narrative: it's a positioning audit, not a leaderboard.
- AIO-revealed peers is often more honest than client-supplied competitor lists.

**Weaknesses**
- No share-of-voice benchmarking.
- No head-to-head "who beats us on this query" data.
- Less commercially compelling for clients who specifically want to know "how am I doing vs. X".
- Off-site source recommendations are based on category citations alone, not on what competitors do well.

## When to use this version

- One-off positioning audits.
- Clients who don't have a clear competitive set.
- Sales-cycle teaser reports (low effort, fast turnaround).
- When the goal is to surface surprises about how AIO frames the brand.
