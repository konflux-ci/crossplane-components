# crossplane-components

Aggregate repository for Crossplane core, composition functions, provider-kubernetes, and a production-oriented Helm chart, built and released through Konflux with supply-chain controls (prefetch, hermetic builds, signed artifacts where configured).

## Layout

| Path | Upstream |
|------|----------|
| `core/crossplane` | [crossplane/crossplane](https://github.com/crossplane/crossplane) |
| `functions/go-templating` | [crossplane-contrib/function-go-templating](https://github.com/crossplane-contrib/function-go-templating) |
| `functions/auto-ready` | [crossplane-contrib/function-auto-ready](https://github.com/crossplane-contrib/function-auto-ready) |
| `functions/patch-and-transform` | [crossplane-contrib/function-patch-and-transform](https://github.com/crossplane-contrib/function-patch-and-transform) |
| `providers/kubernetes` | [crossplane-contrib/provider-kubernetes](https://github.com/crossplane-contrib/provider-kubernetes) |
| `charts/crossplane` | Vendored from `core/crossplane/cluster/charts/crossplane` with image defaults for this project (`charts/crossplane/README.md`) |
| `build-helm` | Minimal Go module to build the Helm CLI from source in the controller image (see `Containerfile`) |

## Components

- **Controller** — Crossplane core binary, CRDs, and webhook configuration in the OCI image defined by `Containerfile`.
- **Functions** — Go templating, auto-ready, patch-and-transform (published as OCI packages per pipeline configuration).
- **Provider** — Kubernetes provider (separate build and package lifecycle from the controller image).
- **Helm chart** — Install path for the controller; see `charts/crossplane/README.md`.

## Usage

Install and configure the controller with Helm: [charts/crossplane/README.md](charts/crossplane/README.md).

## Dependency updates

**Renovate** (`renovate.json`) drives MintMaker: submodule updates follow **semver tags** only; digest-only bumps are disabled to keep upgrades reviewable.

## Clone

```bash
git clone --recurse-submodules https://github.com/konflux-ci/crossplane-components.git
```

Already cloned:

```bash
git submodule update --init --recursive
```

## Controller image (`Containerfile`)

The image uses a **multi-stage** build:

1. **Build stage** — Static Helm CLI from `build-helm`; `helm lint` and `helm package` for `charts/crossplane`; `go build` for three composition functions and `make go.build` for provider-kubernetes (compile verification); `go build` for `crossplane` from `core/crossplane`. Outputs under `/workspace/dist` except `/tmp/crossplane` consumed by the final stage.
2. **Runtime stage** — Red Hat UBI Minimal (digests pinned in the `Containerfile`). Contains `/usr/local/bin/crossplane`, `/crds`, and `/webhookconfigurations` only.

Required submodules: `core/crossplane`, all `functions/*` paths used in the build, and `providers/kubernetes`.

Networked local build (no prefetch):

```bash
podman build -f Containerfile -t crossplane-components:local .
```

Build stage only (artifacts under `/workspace/dist` in the resulting image):

```bash
podman build -f Containerfile --target build -t crossplane-components:build .
```

Runtime smoke test:

```bash
podman run --rm localhost/crossplane-components:local --help
```

Rebuild the UBI base digests in `Containerfile` only when intentionally moving to newer UBI image builds (verify with your scanner and release process).

### Build arguments

| Argument | Purpose |
|----------|---------|
| **`CROSSPLANE_VERSION`** | Optional `v…` string for embedded binary version. If unset, read from `charts/crossplane/Chart.yaml` `appVersion`. |

### Hermetic / prefetch (Konflux)

Hermeto prefetches **Go modules only** (`/cachi2/cachi2.env`).
Build tools (`git`, `make`, `bash`, `ca-certificates`) come from the
pinned `ubi9/go-toolset` base image.

`prefetch-input` lists every `gomod` root compiled by the `Containerfile`:
`core/crossplane`, `build-helm`, `functions/go-templating`,
`functions/auto-ready`, `functions/patch-and-transform`,
`providers/kubernetes`.

Offline local reproduction requires a full gomod cachi2 tree covering all listed paths. Partial caches fail at the first missing module.

### Pipeline parameters (`hermetic`)

The pipeline parameter `hermetic` (default `"true"`) is passed to the buildah and related tasks for **network-isolated** builds; it is not a `Containerfile` build-arg.

Local analogue: `podman build -f Containerfile .` (networked, no cachi2) vs `podman build --network=none` with a complete gomod cachi2 tree at `/cachi2`.
