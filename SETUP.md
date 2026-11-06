# GEO Audit skill — one-time setup

This skill drives the **engine** that ships beside it in the bundle (`engine/`) and needs DataForSEO keys. Do this once per machine, then the skill runs on-demand for any domain list.

## 1. Get the engine

The engine is the Node project whose entrypoint is `scripts/audit-one.js`. It ships inside this bundle, at `engine/`. Put the bundle somewhere
stable. **There is nothing to install and nothing to clone.**

The audit pipeline has no npm dependencies. It runs on a stock Node 18 or newer
install, straight out of the folder:

```bash
cd /path/to/audit-handover/engine
node --version && node --check scripts/audit-one.js && echo "engine is ready"
```

`npm install` is only needed if you also want the optional web app
(`npm start`), which uses express. The audits themselves never touch it.

`GEO_AUDIT_ENGINE_DIR` must point at that `engine/` directory: the one containing `scripts/`, `src/`, `templates/`, `package.json` and `.env`. (An older internal checkout called the same directory `workspace/`. If you have that one instead, point at it.)

> The engine is kept outside the skill folder so the skill can be installed into `~/.claude/skills` while the engine stays with the bundle. Each machine points `GEO_AUDIT_ENGINE_DIR` at its own copy.

## 2. Keys — AUQ provides them

**Your DataForSEO login and password come from AUQ.** Ask whoever handed you this
bundle. There is no signup step and no shared key file inside the bundle: keys
are never included in a handoff, so they reach you separately.

Once you have them:

```bash
cd "$GEO_AUDIT_ENGINE_DIR"
cp .env.example .env
# edit .env:
#   GEO_AUDIT_DATAFORSEO_LOGIN=<provided by AUQ>
#   GEO_AUDIT_DATAFORSEO_PASSWORD=<provided by AUQ>
```

Nothing runs without this. Every query comes back "fetch failed" and the audit
scores 0.

DataForSEO is the only required service. The same login and password run the
AI Overview queue and, separately, `scripts/collect-identity.js`. Ahrefs is
optional and only weights queries by search volume. The Anthropic key in
`.env.example` is never used: analysis runs on the local Claude Code session.
`DATAFORSEO_LOGIN` and `DATAFORSEO_PASSWORD` are accepted aliases and must not
be printed or passed on the command line.

Treat `.env` as a secret. Do not commit it, paste it into a ticket, or forward
it. If it leaks, tell AUQ so the keys can be rotated.

> If AUQ instead hands you a shared `team-config.env`, put it at the skill root
> (`~/.claude/skills/geo-audit/team-config.env`) and `chmod 600` it.
> `run-batch.sh` sources it automatically and its values override the engine
> `.env`, so you would not need to create one.

## 2b. Install the skill

Claude Code finds skills by scanning `~/.claude/skills/*/SKILL.md`. Copy this
folder in, named `geo-audit` to match the `name:` in its frontmatter:

```bash
mkdir -p ~/.claude/skills
cp -R /path/to/audit-handover/skill ~/.claude/skills/geo-audit
```

This is a snapshot. Re-copy after updating the bundle, or symlink it instead:

```bash
ln -s /path/to/audit-handover/skill ~/.claude/skills/geo-audit
```

Optional. It is what lets Claude Code run audits on request. The engine scripts
work by hand either way.

## 3. Set the skill's config env vars

Put these in your shell profile (`~/.zshrc`) or a `config.sh` you `source` before running:

```bash
export GEO_AUDIT_ENGINE_DIR="/path/to/audit-handover/engine"  # required
export GEO_AUDIT_OUT_DIR="$HOME/geo-audit-output"              # optional (default: engine/../audit-output)
export GEO_AUDIT_IDENTITY_DIR="$GEO_AUDIT_OUT_DIR/identities"  # optional
export AIO_SAMPLES=2                                           # optional (2 is the tested default)
export GEO_AUDIT_MAXJOBS=2                                     # optional — runner clamps to 2
export GEO_AUDIT_STAGGER=4                                     # optional
```

## 4. Output is local

There is nothing to configure. Reports are written to `GEO_AUDIT_OUT_DIR` as
self-contained HTML files, and `scripts/build-index.js` writes an `index.html`
beside them. No host, no repo, no git, no tokens.

If you want links rather than files later, point any static host at that folder.
Nothing in the skill or the engine needs to change.

## 5. Smoke test

```bash
bash "$HOME/.claude/skills/geo-audit/scripts/run-batch.sh" example.com
GEO_AUDIT_ENGINE_DIR="$GEO_AUDIT_ENGINE_DIR" node "$HOME/.claude/skills/geo-audit/scripts/verify.js" example.com
```

A run takes about 2 minutes and costs about $0.19. It prints queue status lines, then a line per query, into `$GEO_AUDIT_OUT_DIR/_example.out`. A clean run prints a non-zero GEO score and `OK` in the verifier. If every query errors (score 0), the DataForSEO keys are wrong or the account has no balance: check `.env` and the DataForSEO dashboard.
