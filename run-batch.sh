#!/bin/bash
# Portable GEO-audit batch runner. Wraps <engine>/scripts/audit-one.js.
# Everything machine-specific comes from env — nothing is hardcoded.
#
# Usage:
#   GEO_AUDIT_ENGINE_DIR=/path/to/audit-handover/engine \
#   [GEO_AUDIT_OUT_DIR=...] [GEO_AUDIT_IDENTITY_DIR=...] \
#   [AIO_SAMPLES=2] [GEO_AUDIT_MAXJOBS=2] [GEO_AUDIT_STAGGER=4] \
#   run-batch.sh domain1.com domain2.com[:slug] ...
#
# Slug rule: first DNS label (acme.com -> acme). Override per-domain with domain:slug.
# Reads identity from $GEO_AUDIT_IDENTITY_DIR/<slug>.json (warns if absent).
# Writes report to $GEO_AUDIT_OUT_DIR/<slug>.html and progress to $GEO_AUDIT_OUT_DIR/_progress.log
set -u

# Auto-load shared TEAM keys if present (skill-root/team-config.env), so teammates
# run with zero personal keys. set -a exports whatever it defines to the node child,
# which wins over the engine's .env (src/load-env.js never overrides existing env vars).
SKILL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -f "$SKILL_ROOT/team-config.env" ]; then
  set -a; . "$SKILL_ROOT/team-config.env"; set +a
fi

ENGINE="${GEO_AUDIT_ENGINE_DIR:?set GEO_AUDIT_ENGINE_DIR to the engine/ dir}"
[ -f "$ENGINE/scripts/audit-one.js" ] || { echo "ERROR: $ENGINE/scripts/audit-one.js not found — is GEO_AUDIT_ENGINE_DIR correct?"; exit 1; }

OUT="${GEO_AUDIT_OUT_DIR:-$ENGINE/../audit-output}"
IDDIR="${GEO_AUDIT_IDENTITY_DIR:-$OUT/identities}"
SAMPLES="${AIO_SAMPLES:-2}"
MAXJOBS="${GEO_AUDIT_MAXJOBS:-2}"
STAGGER="${GEO_AUDIT_STAGGER:-4}"
mkdir -p "$OUT" "$IDDIR"
LOG="$OUT/_progress.log"; : > "$LOG"

# Safety: each audit polls DataForSEO's tasks_ready every GEO_AUDIT_POLL_SEC (10s,
# so 6 calls/min), and tasks_ready is limited to 20 calls/min for the whole account.
# Two audits stay well inside that, and 2 is the concurrency that has been tested.
if [ "$MAXJOBS" -gt 2 ]; then
  echo "WARN: GEO_AUDIT_MAXJOBS=$MAXJOBS exceeds the tested max of 2; clamping to 2 (tasks_ready allows 20 calls/min account-wide)." | tee -a "$LOG"
  MAXJOBS=2
fi

[ "$#" -ge 1 ] || { echo "usage: run-batch.sh domain1.com domain2.com[:slug] ..."; exit 1; }

export AIO_SAMPLES="$SAMPLES"

slug_of(){ # arg may be "domain" or "domain:slug"
  case "$1" in
    *:*) echo "${1##*:}" ;;
    *)   echo "${1%%.*}" ;;   # first DNS label
  esac
}
domain_of(){ echo "${1%%:*}"; }

run_one(){
  local d="$1" s="$2" id="$IDDIR/$2.json" idarg
  if [ -f "$id" ]; then idarg="$id"; else
    idarg="-"; echo "$(date +%H:%M:%S) WARN no identity $id for $d — coverage will be empty (brand inferred only)" >> "$LOG"
  fi
  node "$ENGINE/scripts/audit-one.js" "$d" "$idarg" "$OUT/$s.html" >> "$OUT/_$s.out" 2>&1
  echo "$(date +%H:%M:%S) DONE $s -> $(tail -1 "$OUT/_$s.out")" >> "$LOG"
}

echo "$(date +%H:%M:%S) START $# domains (concurrency $MAXJOBS, stagger ${STAGGER}s, samples $SAMPLES)" | tee -a "$LOG"
for arg in "$@"; do
  d="$(domain_of "$arg")"; s="$(slug_of "$arg")"
  while [ "$(jobs -rp | wc -l | tr -d ' ')" -ge "$MAXJOBS" ]; do sleep 3; done
  run_one "$d" "$s" &
  sleep "$STAGGER"
done
wait
echo "$(date +%H:%M:%S) ALL DONE ($(grep -c DONE "$LOG") completed)" | tee -a "$LOG"
echo ""
echo "Reports in: $OUT"
echo "Now verify:  node \"$(cd "$(dirname "$0")" && pwd)/verify.js\" $*"
echo "Then, after finishing the reports, the insight fact sheet:  node \"$(cd "$(dirname "$0")" && pwd)/insights.js\" $*"
