# actions-runner-image

Images for the self-hosted GitHub Actions runners (ARC runner scale sets) used by webitel repositories.

| Image | Scale set | Adds on top of `base` |
|---|---|---|
| `ghcr.io/webitel/actions-runner-image/base` | `arc-runner-set` | — |
| `ghcr.io/webitel/actions-runner-image/backend` | `arc-backend-runner-set` | Go, golangci-lint, C toolchain for cgo (amd64 and arm64 cross) |
| `ghcr.io/webitel/actions-runner-image/frontend` | `arc-frontend-runner-set` | Node.js, npm, pnpm, yarn |
| `ghcr.io/webitel/actions-runner-image/python` | `arc-python-runner-set` | uv and preinstalled CPython versions |
| `ghcr.io/webitel/actions-runner-image/c` | `arc-c-runner-set` | gRPC, abseil, google-cloud-cpp, FreeSWITCH and PostgreSQL headers |

`base` is Debian bookworm with the GitHub Actions runner, the Kubernetes container hooks, docker CLI and daemon binaries, buildx, gh, nFPM, osv-scanner and deb-s3. The runner itself is copied from the official `ghcr.io/actions/actions-runner` image.

## Versions

Tool versions live only in the Dockerfiles:

- tools that ship as images are taken with `FROM <image>:<tag>@sha256:<digest>`, and Dependabot opens PRs for new tags and digests;
- files downloaded over HTTP (docker static binaries, container hooks) use `ADD --checksum`, so a new version needs both the URL and the checksum updated;
- pnpm, yarn, deb-s3, Python versions and the C libraries are plain `ARG`s or git tags and are updated by hand.

The runner version is the tag of `ghcr.io/actions/actions-runner` in `base.Dockerfile`. A runner that falls too far behind the latest release is rejected by GitHub, so merge runner updates promptly.

## Release

Run the **Release image** workflow on `main`. It reads the runner version from `base.Dockerfile`, builds `base` and then the other images on top of it, and pushes each with three tags:

- `<runner version>` — moves to the latest build;
- `<runner version>-<run number>` — never overwritten, use it in the scale set to be able to roll back;
- `sha-<commit>`.

Every image is shared by all repositories and branches, including old release branches, so a toolchain update (Go, golangci-lint, Node, uv) changes it for all of them at once.

## Local build

```bash
docker build --platform linux/amd64 -f base.Dockerfile -t ghcr.io/webitel/actions-runner-image/base:2.338.2 .
docker build --platform linux/amd64 -f backend.Dockerfile -t backend .
```

`c.Dockerfile` needs a SignalWire token for the FreeSWITCH repository:

```bash
docker build --platform linux/amd64 --secret id=SIGNALWIRE_TOKEN,env=SIGNALWIRE_TOKEN -f c.Dockerfile -t c .
```
