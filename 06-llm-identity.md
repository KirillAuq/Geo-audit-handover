# 06 — What do LLMs say the brand is?

A separate qualitative check. It does not change the Google AI Overview score,
the 38-query set, or the four weights in `scripts/normalize_aio.js`.

The 20% component labelled "How AI describes the brand" in that scorer, and
"Identity accuracy" in `01-method.md`, is theme presence. A theme counts when
any query in it cites the domain or names the brand. It is not a judgment that
an answer is correct.

## What to ask

Exact prompt, and nothing else:

```
What does {Brand} do?
```

No system message. No dossier. No homepage text. No examples. `user_prompt` is
limited to 500 characters on these endpoints.

Target at least 3 providers, with 2 snapshots each. Fewer successful providers,
or one snapshot where two were requested, is **Partial**. A provider that was
not called, or whose call failed, is **Not tested**. Do not fill that slot
with Google AI Overview citations, peer domains, or a generic description.

## Transport

DataForSEO AI Optimization, LLM Responses, Live method. Official overview:
https://docs.dataforseo.com/v3/ai_optimization/llm_responses/overview/

The same account as the AI Overview reads. Names only, in `engine/.env`:

- `GEO_AUDIT_DATAFORSEO_LOGIN`
- `GEO_AUDIT_DATAFORSEO_PASSWORD`

`DATAFORSEO_LOGIN` and `DATAFORSEO_PASSWORD` are accepted aliases. Never print
the values, never put them on the command line, and never write them into the
output JSON.

| Provider | Live | Models |
|---|---|---|
| ChatGPT | `POST /v3/ai_optimization/chat_gpt/llm_responses/live` | `GET /v3/ai_optimization/chat_gpt/llm_responses/models` |
| Gemini | `POST /v3/ai_optimization/gemini/llm_responses/live` | `GET /v3/ai_optimization/gemini/llm_responses/models` |
| Claude | `POST /v3/ai_optimization/claude/llm_responses/live` | `GET /v3/ai_optimization/claude/llm_responses/models` |
| Perplexity | `POST /v3/ai_optimization/perplexity/llm_responses/live` | `GET /v3/ai_optimization/perplexity/llm_responses/models` |

Perplexity in this API supports Live only. ChatGPT, Gemini, and Claude also
have a Standard method. This check uses Live for all four so the calls match.
Live concurrency is capped at 30 requests per account per platform. `user_prompt`
max is 500 characters.

Resolve `model_name` from that provider's Models endpoint, then record the
`model_name` returned on the task result. If the two differ, the report shows
the returned id. If the Models endpoint returns nothing, that provider is
Not tested. Do not invent a model id.

Each stored snapshot keeps provider, returned model id, UTC time, whether web
search was on, the answer text, citation title and URL, reported cost, and the
failure message when the call did not return text. Search-result snippets are
page extracts, not the model's answer, and are not stored.

These are API responses. They are not screenshots of the consumer chat apps.
The public HTML says that in those words. It does not name the measurement
vendor, because `check-reports.js` treats that name as tooling. The endpoint
paths stay in this doc and in the collector.

## Gemini country field

ChatGPT Live documents optional `web_search_country_iso_code`. Gemini Live does
not. Sending it to Gemini returns status `40501`. This check omits the field
for every provider, including ChatGPT, so a ChatGPT example cannot be copied
onto Gemini. `identityRequestBody()` drops it even if a caller passes it.

## Brand-owned baseline

Fetch it in the same session, after or before the model calls, and store it in
a different file from the prompt. Minimum is the homepage. Also take `/about`
and `/llms.txt` when they exist. Keep the URL, the fetch date, and short
quotes. Note slogan variants when the site itself uses more than one category
label.

The baseline is the comparison source. It is never placed in `user_prompt`.

## Comparison

Qualitative only. No confidence percentage.

Vocabulary:

- `exact_or_near_slogan`, the answer contains the brand's own category phrase
- `semantic_alignment`, same meaning, and a person made that judgment
- `omission`, a supplied baseline theme is absent
- `contradiction`, a clear conflict with a brand-owned claim
- `unknown`, not enough evidence

The automatic helper only does phrase overlap. It may say
`exact_or_near_slogan` when a supplied category label is contained in the
answer, and `omission` when a supplied phrase is absent. It does not emit
`semantic_alignment` or `contradiction`. Factual stays `unknown`, with the
sentence "This check does not verify every generated factual claim." A reviewer
may attach the other verdicts. The report labels those as a reviewer note.

## Report

Section title: **What do LLMs say {brand} is?**

Show the dated baseline, then one card per provider. Quote a short excerpt of
the actual answer with provider, returned model id, UTC time, and whether web
search was on. A failed or missing provider says **Not tested** and nothing else
in that card.

`audit-one.js` does not run this check. A one-shot HTML file says Not tested
until you collect and re-render. That is intentional. The score command must
not gain a hidden billable call.

## Command

From `engine/`, after the AI Overview run has written `canonical.json`:

```bash
node scripts/collect-identity.js acme.com "Acme" \
  --baseline /path/to/acme.baseline.json \
  --samples 2 \
  --out /path/to/run/llm-identity.json
node scripts/render-roboflow.js /path/to/run out/acme.html
```

`--baseline` is a JSON object with `fetchedAt`, `sources[]` (`url`, `title`,
`quotes`), and optional `categoryLabels`, `buyerPhrases`, `capabilityPhrases`,
`positioningPhrases`. If the credentials are unset, the script writes status
`not_tested` and exits 2. It does not call the network.

Offline check, no API calls:

```bash
node scripts/test-llm-identity.js
```

The fixture under `engine/fixtures/llm-identity/` is one sanitized run. It is
not a default brand and it is not reused as another company's answers.
