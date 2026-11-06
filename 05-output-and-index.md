# 05 — Output and index

Reports are local HTML files. There is no host, no repo, no git, and no upload
step. Everything below runs on the machine that ran the audit.

## Where things land

| | |
|---|---|
| Reports | `$GEO_AUDIT_OUT_DIR/<slug>.html` |
| Index | `$GEO_AUDIT_OUT_DIR/index.html` |
| Batch log | `$GEO_AUDIT_OUT_DIR/_progress.log` |
| Per-domain stdout | `$GEO_AUDIT_OUT_DIR/_<slug>.out` |
| Run data | `$GEO_AUDIT_ENGINE_DIR/.data/runs/<runId>/` |

Slug is the first DNS label, so `acme.com` becomes `acme.html`. Each report is
self-contained: open the file and it renders with no assets alongside it. Offline
it still works, with system fonts and no analytics.

**What a report requests when opened.** Google Fonts, which fall back to system
fonts with no connection, and the AUQ Google Tag Manager container.

Analytics are on by default, on every report, sharing the container used by the
audits index so opens are tracked consistently. Worth being explicit about what
that means now that reports are files rather than pages: the tag fires from the
recipient's machine each time they open the file, wherever that file has been
forwarded to.

Render without a tag when a client agreement calls for it:

```bash
# default: AUQ container
node scripts/audit-one.js acme.com identities/acme.json out/acme.html

# a different container
GEO_AUDIT_GTM_ID="GTM-XXXXXXX" node scripts/audit-one.js acme.com identities/acme.json out/acme.html

# no tag at all
GEO_AUDIT_GTM_ID=off node scripts/audit-one.js acme.com identities/acme.json out/acme.html
```

`check-reports.js` checks the tag against the same variable. By default it fails
a report with no tag, since that usually means a stray `GEO_AUDIT_GTM_ID`. For
reports rendered with `off`, run the check with `off` too:

```bash
GEO_AUDIT_GTM_ID=off node scripts/check-reports.js "$GEO_AUDIT_OUT_DIR"
```

It then requires the opposite and fails any report that still carries a tag.
Keep untracked client reports in their own output folder so one check setting
fits the whole folder.

## Finishing a report

A freshly rendered report has no conversion path on it. Two scripts add one.
Both are idempotent, so running them across the whole output folder is safe and
repeatable.

```bash
cd "$GEO_AUDIT_ENGINE_DIR"
node scripts/inject-banners.js "$GEO_AUDIT_OUT_DIR"
node scripts/move-case-studies.js "$GEO_AUDIT_OUT_DIR"
```

`inject-banners.js` adds the "Work with AUQ" execution banner after the
executive summary, and a four-card case-studies section before the footer. It
skips any file already containing `id="auq-work-banner"`.

`move-case-studies.js` moves that case-studies section above the
`id="tested-queries"` section, or after AI Overview Performance on older files.
On reports rendered by this engine `inject-banners.js` already puts it above
`tested-queries`, so the move script reports them `unchanged`. It matters for
reports stamped by the older banner script, and is safe to run either way.

Both take the target folder as their first argument. With no argument they fall
back to `$GEO_AUDIT_OUT_DIR`, then to their own directory. Neither ever touches
`index.html`.

Output on a fresh folder of three reports:

```
injected: 3, skipped: 0, errors: 0
{ unchanged: 3 }
```

On a second run, `injected: 0, skipped: 3` and `{ unchanged: 3 }`, with every
file byte-identical. That is the idempotency working, not a failure. On older
reports the move script prints `{ moved: N }` the first time.

## Building the index

```bash
node scripts/build-index.js "$GEO_AUDIT_OUT_DIR"
```

Writes `index.html` into that folder: one card per report, sorted by score
descending, in the AUQ index design. Open it in a browser to browse the set.

Card values come from each run's `canonical.json`, matched to a report by slug,
newest run per domain:

| Card field | Source |
|---|---|
| link | `<slug>.html` |
| brand | `geoScore.brand` |
| domain | `meta.domain` |
| score | `geoScore.overallScore` |
| band | `geoScore.band` plus the word "band" |

If no `canonical.json` exists for a report, the values are read back out of the
rendered HTML instead, so an index can still be built from a folder of reports
alone. The script prints which ones it had to fall back on.

Rebuild the index whenever you add reports. It is regenerated from whatever is
in the folder, so nothing is lost by running it again.

> **Publishing to auq.io/audits/?** That public page is a *separate* repo with
> its own index design and its own generator. Do **not** commit this
> `build-index.js` output — or any run evidence — into it. See
> "Publishing to the auq.io/audits/ repo" at the end of this doc.

## Full sequence after a batch

```bash
cd "$GEO_AUDIT_ENGINE_DIR"

# 1. verify — never finish a degraded run
GEO_AUDIT_ENGINE_DIR="$GEO_AUDIT_ENGINE_DIR" \
  node ~/.claude/skills/geo-audit/scripts/verify.js acme.com beta.io

# 2. add the banners
node scripts/inject-banners.js "$GEO_AUDIT_OUT_DIR"
node scripts/move-case-studies.js "$GEO_AUDIT_OUT_DIR"

# 3. rebuild the index
node scripts/build-index.js "$GEO_AUDIT_OUT_DIR"

# 4. check the writing rules held
node scripts/check-reports.js "$GEO_AUDIT_OUT_DIR"

# 5. fact sheet for the "What it found" and "Pitch" chat write-up
node scripts/insights.js acme.com beta.io
```

Step 5 prints facts, not prose. The session writes the two chat blocks from it,
per `skill/SKILL.md` step 7.

Anything that prints FAIL has an em dash, an en dash, a third-party tool name in
its prose, or an analytics tag that does not match `GEO_AUDIT_GTM_ID`. Fix the
source strings and re-render that domain. Measured data is exempt (the data
sections, cited domains, and quotes), so a cited `semrush.com` is a finding, not
a violation. Details in `03-report-spec.md`.

## Sharing a report

The files are local, so sending one means sending the file. Each report is a
single self-contained HTML document, so it attaches to an email or a message and
opens anywhere.

If you later want links instead of attachments, that is a hosting decision, not
an engine change: point any static host at `$GEO_AUDIT_OUT_DIR`. Nothing in the
engine or the skill assumes one, and nothing needs to change to add one.

## Publishing to the auq.io/audits/ repo

The public audits page at **auq.io/audits/** is its own GitHub Pages repo
(`KirillAuq/auq-geo-audits`). It is **not** the local folder this engine builds,
and two differences cause real breakage if ignored:

- **It has its own index.** The public page is a dark, sortable and filterable
  table of *every* audit in that repo, generated by **that repo's own**
  `build-index.py` (from `index.template.html`). The engine's `build-index.js`
  produces a different, older card-grid design and lists only the reports in one
  output folder. **Never copy the engine's `index.html` into the Pages repo** —
  it overwrites the full table and collapses the page to a single batch.
- **It holds published reports only.** Commit just the `<slug>.html` report
  file(s). **Do not commit run evidence** — `.data/`, `evidence/`, `*.tgz`, raw
  JSON. It is internal working-data, it does not belong on a public URL, and a
  stray `evidence/` directory has **errored the GitHub Pages build** (the site
  will not deploy until it is removed).

### Adding audits to the Pages repo

```bash
# in a checkout of KirillAuq/auq-geo-audits
cp "$GEO_AUDIT_OUT_DIR"/<slug>.html .   # the report file(s) only — no evidence
python3 build-index.py                  # rebuild the full dark index
git add -A && git commit -m "Add audits + rebuild index" && git push
```

`build-index.py` reads every `*.html` report in the repo and rewrites
`index.html` (rows plus all counts: total, band pills, stat cards, median,
high/low). It is idempotent. Details in that repo's `README-INDEX.md`.
