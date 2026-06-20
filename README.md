# containers

[![Managed by Forgejo](https://img.shields.io/badge/managed%20by-Forgejo%20CI-blue?logo=forgejo)](https://github.com/JanRK/containers)

Automatically built and mirrored container images, published to the **GitHub Container Registry** under
[`ghcr.io/janrk`](https://github.com/JanRK?tab=packages).

> **This repository is generated.** Its contents are mirrored from a private Forgejo control repo and the
> build receipts under `state/` and `history/` are written by CI. Do not edit files here by hand — changes
> are overwritten on the next sync.

## How it works

A scheduled check (every 6 hours) detects new upstream releases, resolves a fully-pinned build plan per
job under `desired/`, and triggers the GitHub Actions workflow in `.github/workflows/build.yaml`. The
workflow builds (or mirrors) each changed job as a **multi-arch** image (`linux/amd64`, `linux/arm64`),
smoke-tests it, pushes it to `ghcr.io/janrk`, and records the result in `state/<job>.json` (latest
receipt) and `history/<job>.json` (last 30 builds).

## Images

| Job | Image | Tags |
| --- | --- | --- |
| `multica-agent` | `ghcr.io/janrk/multica-agent` | `m{multica}-o{opencode}-h{hermes}`, `latest` |

```bash
docker pull ghcr.io/janrk/multica-agent:latest
```

## Repository layout

| Path | What it is |
| --- | --- |
| `jobs/<name>/` | Per-job config (`job.yaml`) and build context (`Dockerfile`, etc.). |
| `desired/<name>.json` | The resolved build plan for a job (machine-written). |
| `scripts/` | Shell helpers the build workflow calls. |
| `.github/workflows/build.yaml` | The build / mirror pipeline. |
| `state/<name>.json` | Latest build receipt (written by CI). |
| `history/<name>.json` | Recent build log, capped at 30 entries (written by CI). |

## License

MIT
