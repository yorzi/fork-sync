#!/usr/bin/env bash
# Sync yorzi's forks of upstream repos he has opened PRs on.
set -uo pipefail
ME="${OWNER:-yorzi}"
OUT="last-run.json"
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Upstream repos where $ME has authored PRs (excluding own repos)
upstreams=$(gh api -X GET search/issues --paginate \
  -f q="author:$ME is:pr -user:$ME" -f per_page=100 \
  --jq '.items[].repository_url' | sed 's#https://api.github.com/repos/##' | sort -u)

# Forks owned by $ME with their parent
forks=$(gh repo list "$ME" --fork --limit 500 --json nameWithOwner,parent,defaultBranchRef \
  --jq '.[] | select(.parent != null) | "\(.nameWithOwner) \(.parent.owner.login)/\(.parent.name) \(.defaultBranchRef.name)"')

results="[]"
while read -r fork parent branch; do
  [ -z "${fork:-}" ] && continue
  grep -qxi "$parent" <<<"$upstreams" || continue
  behind=$(gh api "repos/$fork/compare/$branch...${parent%%/*}:$branch" --jq '.ahead_by' 2>/dev/null || echo "?")
  ahead=$(gh api "repos/$fork/compare/$branch...${parent%%/*}:$branch" --jq '.behind_by' 2>/dev/null || echo "?")
  if [ "$behind" = "0" ]; then
    status="up-to-date"; msg=""
  elif [ "$ahead" != "0" ]; then
    status="skipped-diverged"; msg="fork default branch has its own commits; not touched"
  else
    if resp=$(gh api -X POST "repos/$fork/merge-upstream" -f branch="$branch" 2>&1); then
      status="synced"; msg=$(jq -r '.merge_type // .message // ""' <<<"$resp" 2>/dev/null || echo "")
    else
      status="failed"; msg=$(tr '\n' ' ' <<<"$resp" | cut -c1-300)
    fi
  fi
  echo "$fork <- $parent [$branch]: $status (behind=$behind, ahead=$ahead) $msg"
  results=$(jq --arg f "$fork" --arg p "$parent" --arg b "$branch" --arg s "$status" \
    --arg bh "$behind" --arg ah "$ahead" --arg m "$msg" \
    '. + [{fork:$f, upstream:$p, branch:$b, status:$s, behind_before:$bh, fork_ahead:$ah, message:$m}]' <<<"$results")
done <<<"$forks"

jq -n --arg t "$now" --argjson r "$results" '{run_at:$t, results:$r}' > "$OUT"
{
  echo "## Fork sync $now"
  jq -r '.results[] | "- \(.fork) <- \(.upstream): **\(.status)** (behind \(.behind_before))"' "$OUT"
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
