# AGENTS.md

## Project Overview

Aggregate repository for **Crossplane** core, composition functions, provider-kubernetes, and a production Helm chart. Built and released through **Konflux** with supply-chain controls: hermetic Go module prefetch via Cachi2, pinned base image digests, and separate pipeline lifecycles per component.

This repo intentionally contains **minimal first-party code**. Its job is to:
1. Pin upstream components as Git submodules at reviewed semver releases.
2. Build purpose-built OCI images on Red Hat UBI via `Containerfile`.
3. Maintain a Helm chart (`charts/crossplane/`) with registry defaults for this project.
4. Publish each component through its own Konflux pipeline in `.tekton/`.

There is no root `Makefile`. The build contract is `Containerfile` + `.tekton/` pipelines.

## Layout

| Path | Purpose |
|------|---------|
| `core/crossplane` | Submodule → [crossplane/crossplane](https://github.com/crossplane/crossplane) — controller source, CRDs, webhook configs |
| `functions/go-templating` | Submodule → [crossplane-contrib/function-go-templating](https://github.com/crossplane-contrib/function-go-templating) |
| `functions/auto-ready` | Submodule → [crossplane-contrib/function-auto-ready](https://github.com/crossplane-contrib/function-auto-ready) |
| `functions/patch-and-transform` | Submodule → [crossplane-contrib/function-patch-and-transform](https://github.com/crossplane-contrib/function-patch-and-transform) |
| `providers/kubernetes` | Submodule → [crossplane-contrib/provider-kubernetes](https://github.com/crossplane-contrib/provider-kubernetes) |
| `charts/crossplane/` | Helm chart vendored from `core/crossplane/cluster/charts/crossplane/`; templates are mostly identical to upstream with targeted deviations where upstream fixes are pending (see [Helm Chart](#helm-chart)) — `Chart.yaml` metadata, `values.yaml` registry defaults, and listed template overrides differ |
| `build-helm/` | Minimal Go module whose only purpose is to let Hermeto/Cachi2 prefetch the Helm CLI source tree used in `Containerfile` |
| `Containerfile` | Multi-stage UBI build: compiles all submodule Go targets + Helm CLI, packages the chart, produces the final controller image |
| `.tekton/` | 12 Konflux PipelineRuns (push + pull-request for controller, chart, provider, three functions) |
| `renovate.json` | MintMaker/Renovate config driving automated dependency updates |
| `.github/workflows/fullsend.yaml` | Fullsend shim for agent-assisted automation |
| `skills/` | Canonical agent skill definitions — one `SKILL.md` per workflow |

## Setup Commands

```bash
# Fresh clone with all submodules
git clone --recurse-submodules https://github.com/konflux-ci/crossplane-components.git

# Already cloned without submodules
git submodule update --init --recursive
```

## Build

### Local (networked)

```bash
# Full controller image
podman build -f Containerfile -t crossplane-components:local .

# Build stage only — artifacts land under /workspace/dist in the resulting image
podman build -f Containerfile --target build -t crossplane-components:build .

# Smoke test
podman run --rm localhost/crossplane-components:local --help
```

### Build arguments

| Argument | Default | Purpose |
|----------|---------|---------|
| `CROSSPLANE_VERSION` | *(empty)* | Optional `v…` string injected via `-ldflags`. If unset, read from `appVersion` in `charts/crossplane/Chart.yaml`. |

### Hermetic / prefetch (Konflux)

The `crossplane-components-*` pipelines run with `hermetic: "true"` — the network is cut after Cachi2 prefetches Go modules. Function, provider, and Helm chart pipelines default to `hermetic: "false"`. Every `gomod` root compiled by `Containerfile` must appear in `prefetch-input` in the relevant `.tekton/` PipelineRun:

```
core/crossplane
build-helm
functions/go-templating
functions/auto-ready
functions/patch-and-transform
providers/kubernetes
```

**If you add a new Go compilation target to `Containerfile`, add its `gomod` root to every affected PipelineRun in `.tekton/`.** A missing entry silently succeeds in networked builds but fails hermetically.

## Validation

There is no standalone test suite. Use these checks before opening a PR (see `skills/pr-checklist/` for the full checklist):

```bash
# Chart structure and rendering
helm lint charts/crossplane
helm template crossplane charts/crossplane --namespace crossplane-system

# Compile-check all submodule Go targets (same as CI build stage)
podman build -f Containerfile --target build -t crossplane-components:build .
```

A failing build stage means a submodule bump introduced a compilation break — fix the submodule version, not the upstream source.

## CI Checks

Twelve PipelineRuns in `.tekton/` fire on push and pull-request:

| Component | PipelineRun prefix |
|-----------|-------------------|
| Controller image | `crossplane-components-` |
| Helm chart OCI artifact | `crossplane-helm-chart-` |
| provider-kubernetes | `provider-kubernetes-` |
| function-go-templating | `function-go-templating-` |
| function-auto-ready | `function-auto-ready-` |
| function-patch-and-transform | `function-patch-and-transform-` |

Fork PRs may require a maintainer trigger to run Konflux pipelines.

## Helm Chart

The chart at `charts/crossplane/` is vendored from `core/crossplane/cluster/charts/crossplane/`. Templates are mostly identical to upstream, with targeted deviations where upstream fixes are pending. Four things differ: `Chart.yaml` metadata (name, version, maintainers), `values.yaml` registry defaults (`image.repository`, `provider.packages`, `function.packages`), `README.md`, and the template overrides listed below.

#### Current template deviations from upstream

| File | Change | Reason | Upstream PR |
|------|--------|--------|-------------|
| `templates/deployment.yaml` | `.Chart.Name` → `{{ template "crossplane.name" . }}` for container and init container `name` and `containerName` fields | Fixes `nameOverride` support for container names | [crossplane/crossplane#7589](https://github.com/crossplane/crossplane/pull/7589) |
| `templates/rbac-manager-deployment.yaml` | `.Chart.Name` → `{{ template "crossplane.name" . }}` for container and init container `name` and `containerName` fields | Same fix | Same |

> **Remove these deviations** once the upstream PR is merged and the `core/crossplane` submodule is synced to a release containing the fix.

### Syncing after a submodule bump

For the full step-by-step workflow see `skills/bump-component/`.

```bash
rsync -a --delete --exclude='.git' \
  core/crossplane/cluster/charts/crossplane/ charts/crossplane/
```

After syncing, **manually restore** these repository-specific values:

- **`Chart.yaml`** — `version` and `appVersion` must match the Crossplane release and the image you publish.
- **`values.yaml`** — `image.repository`, and the OCI digest pins in `provider.packages` and `function.packages`.
- **Template deviations** — re-apply the changes listed in [Current template deviations from upstream](#current-template-deviations-from-upstream) above. The rsync will overwrite them with the upstream versions.

Update `provider.packages` and `function.packages` with digest-pinned OCI references whenever component images are bumped — not just `image.repository`. The current `values.yaml` may use bare refs; add `@sha256:<digest>` when publishing a new component image.

## Dependency Updates

**Renovate / MintMaker** (`renovate.json`) owns all of the following — **do not update manually**:

- Submodule refs — semver tags only; digest-only bumps are disabled. Patch updates automerge; minor and major require review.
- Go module versions — patch/minor automerge for direct deps; all updates for indirect deps disabled (resolved by `go mod tidy`).
- Base image digests in `Containerfile` — grouped as `container-digest`, automerged.

## PR Guidelines

- Run `helm lint` and `helm template` before submitting chart changes (see **Validation**).
- After bumping `core/crossplane`, run the `rsync` sync and restore `Chart.yaml` / `values.yaml` as described in **Helm Chart**. For step-by-step instructions see `skills/bump-component/`.
- New Go targets in `Containerfile` → add their `gomod` root to `prefetch-input` in all affected `.tekton/` PipelineRuns.
- Do not edit base image digests in `Containerfile` without a scanner review; Renovate handles routine updates.
- Submodule version bumps are normally opened by Renovate; manual bumps should use the same semver discipline (no pinning to non-release commits).

## Skills

Skills provide step-by-step procedures for complex workflows. Sections above define rules and constraints; skills provide the detailed how-to. Guides live in `skills/` — each subdirectory contains a `SKILL.md`:

| Skill | When to use |
|-------|-------------|
| `skills/bump-component/` | Bumping a submodule version (controller, function, provider) including chart sync and digest pin updates |
| `skills/pr-checklist/` | Definition of done and pre-PR validation steps |

## Code Style

- **Containerfile** — UBI-based, non-root user (`65532:65532`), static binaries, pinned base image digests. Multi-stage: build stage on `ubi9/go-toolset`, runtime on `ubi9-minimal`.
- **Shell** — `set -euo pipefail`, quote all variables, POSIX-compatible constructs only (no GNU-only flags; scripts must work on both Linux and macOS).
- **YAML (`.tekton/`, `charts/`)** — pin exact image digests, not floating tags; preserve `hermetic: "true"` default in new PipelineRuns.
- **Markdown** — keep any TOC up to date if document structure changes.

## Architecture Notes

- This repo does not patch or cherry-pick upstream code. If a submodule version introduces a build break, roll it back or wait for an upstream fix.
- The `Containerfile` build stage intentionally compiles all submodule Go targets as a **compile-check** — a red build stage is the first signal that a submodule bump is broken.
- `build-helm/` exists solely so Hermeto can prefetch the Helm CLI's Go module tree. Helm is compiled from source rather than installed via a package manager to satisfy hermetic build requirements.
- The Helm chart OCI artifact (`charts/Dockerfile.konflux.crossplane-chart`) and the controller image have independent pipelines and release lifecycles — bumping one does not require releasing the other.
- Upstream components are pinned via submodule SHAs that correspond to semver tags. Renovate tracks semver and opens PRs; the SHA in `.gitmodules` is what the build actually uses.
