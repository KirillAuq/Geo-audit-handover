# Ahrefs API Notes — Brand-Only Audit

These are the Ahrefs MCP tools the brand-only audit actually uses, in call order, plus the mistakes that cost retries on the first real run. Read this before calling the API.

## Tools used

**Site Explorer (keyword universe)**
- `site-explorer-organic-keywords` — the brand's ranking keywords, to ground the prompt set.
- `site-explorer-top-pages` — top pages by traffic, useful for identity and content-gap context.

**Brand Radar — AI Overviews (the core data)** — use the `-entities` variants so you query by brand entity:
- `brand-radar-mentions-overview-entities` — total mentions, impressions, question volume.
- `brand-radar-impressions-overview-entities` — impression totals.
- `brand-radar-ai-responses-entities` — the full AIO response text. This is the big payload; see "Handling large responses."
- `brand-radar-cited-domains-entities` — external domains AIO cites.
- `brand-radar-cited-pages-entities` — specific pages AIO cites, including the brand's own.

**Config / setup**
- `management-brand-radar-reports` — check whether custom Brand Radar reports/prompt sets exist. Typically free. If none are configured, you query against Ahrefs' default prompt database.
- Confirm `google_ai_overviews_keywords` is available before pulling. **Use this source for Brand Radar entity pulls.** The `google_ai_overviews` source tracks brand mentions inside answer text; many domains (e.g. `microblink.com`) have keyword-triggered citations but show `total: 0` on the classic source. Do not mix both sources in one request (API error: mixed models).

The `doc` tool (Ahrefs MCP documentation) is for looking up parameters and is not a billable data pull.

## Gotchas that cost retries last time

1. **Wrong `data_source`.** Defaulting to `google_ai_overviews` yields false "no mentions" for brands that do appear as cited sources. The workflow uses `google_ai_overviews_keywords` instead.

2. **Empty `select` / wrong column names.** The first `brand-radar-cited-domains-entities` and `brand-radar-cited-pages-entities` calls returned empty because the requested columns didn't match the API's actual field names. This wasted two billable calls. Before pulling these two, use `doc` to confirm the exact column names for the cited-domains and cited-pages endpoints, then request those. Valid cited-pages fields include `url`, `responses`, `volume`, `mentions`.

3. **AI responses are huge.** `brand-radar-ai-responses-entities` returns very large payloads. Don't try to hold the full thing in context. Save it to a file and query it with `jq` / bash (extract the response text per query, the cited sources, and positions).

4. **`www.` prefix breaks web_fetch.** When fetching the site in stage 1, use the bare domain (`acme.com`), not `www.acme.com`.

## Credit / cost note

Ahrefs bills these endpoints by **rows returned**, not by request, so call count alone does not equal credit cost. The MCP responses carry a units/credit figure in the response metadata, but that figure is not preserved in session transcripts after the fact.

To make this answerable later: **log the units field from each Ahrefs response as you go** — write it to your working `data.json` (e.g. an `api_usage` array of `{tool, units}`) so the run's total credit cost is recoverable. You can also call `subscription-info-limits-and-usage` before and after a run to see quota consumed, though that reflects the whole account, not just this run.

As a rough shape, a single brand-only run is on the order of 6–9 billable Brand Radar / Site Explorer requests (plus any retries), dominated by the AI-responses pull.
