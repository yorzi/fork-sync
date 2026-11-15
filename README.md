# fork-sync

Daily GitHub Actions job that keeps yorzi's forks in sync with upstream — only for upstream repos yorzi has opened pull requests on. The list is computed on each run, so new contributions are picked up automatically.

- Fast-forwards the fork's default branch via the `merge-upstream` API.
- Forks whose default branch has its own commits and can't fast-forward are reported as `skipped-diverged` and left untouched (no merge commits).
- Results are written to `last-run.json` and the job summary.
- Needs repo secret `FORK_SYNC_TOKEN` (contents + workflows write on yorzi's forks, read on public repos).
