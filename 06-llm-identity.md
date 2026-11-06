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

## Homepage claim list

Before reading the model answers, write a short checklist of distinct factual
claims from the homepage only. About, `llms.txt`, and phrases copied out of an
answer are not the benchmark. Each claim has equal weight. Store `id` and
`text` on `claims`, and a one or two sentence `homepage.says` for the public
line. The prompt still does not include this list.

## Description-match percent

This number is a reproducible count. It is not a confidence score, not a
factual-accuracy rate, and not a model similarity.

On each answer, a person marks every homepage claim:

- `matched`, including a justified semantic equivalent, with a short excerpt and note
- `missed`, the claim is absent (an omission, not a contradiction)
- `contradiction`, the answer states a conflicting fact, with a note
- `not_reviewed`, left out of the math

`src/llm-identity-match.js` then, for each provider, divides matched
checks by evaluated checks. `matched` counts. `missed` and `contradiction`
count as evaluated and not matched. `not_reviewed` is dropped. Providers are
then averaged with equal weight, so two samples do not outweigh one sample.
Round to a whole percent.

Unreviewed answers and missing evidence are not scored. They are not zero.
A provider with no reviewed checks is excluded. A failed provider is excluded
and the public line uses the answers and models that were actually scored.

Phrase overlap in `llm-identity-compare.js` must not create these decisions or
this percent.

Keep the claim list, each decision, the excerpt, and the per-provider
numerator and denominator in `llm-identity.json`. That file stays in the run
directory. It is not uploaded next to `{brand}.html`.

## Public report

One section, about 100 to 160 words when a percent is shown. Three parts only:

1. What the brand says it is, from `homepage.says`.
2. The percent, with one line such as "Share of homepage claims reflected across 6 answers from 3 models." If a model returned no answer, add that it is left out.
3. What the models got wrong or missed. If no contradiction was recorded, say no clear factual errors, then name the concrete omissions. Do not call an omission a contradiction. Do not say every statement in the answers was verified.

Do not publish provider dumps, model ids, timestamps, transport, costs, search
citations, `llms.txt`, or the Google AI Overview citation table. Do not add a
collapsed copy of the answers.

The Google AI Overview score is untouched. Its 20% component is theme presence
in that query set. This percent is a different number.

`audit-one.js` does not run this check. Until a reviewed `llm-identity.json`
is merged at render time, the section says not scored and shows no percent.

## Command

From `engine/`, after the AI Overview run has written `canonical.json`:

```bash
node scripts/collect-identity.js acme.com "Acme" \
  --samples 2 \
  --out /path/to/run/llm-identity.json
node scripts/render-roboflow.js /path/to/run out/acme.html
```

Collect stores the raw answers. A person then adds `homepage`, `claims`, and
per-answer `claims` decisions before the render that clients see. If the
credentials are unset, the script writes status `not_tested` and exits 2. It
does not call the network.

Offline check, no API calls:

```bash
node scripts/test-llm-identity.js
```

The fixture under `engine/fixtures/llm-identity/` is one sanitized run. It is
not a default brand and it is not reused as another company's answers. Without
reviewed claim decisions it renders as not scored.
