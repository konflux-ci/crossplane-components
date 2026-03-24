# Crossplane-Components

Build and release Crossplane components with Konflux for better supply chain security.

## Repository structure

This repository uses git submodules to aggregate upstream Crossplane source:

| Path | Source |
|------|--------|
| `core/crossplane` | [crossplane/crossplane](https://github.com/crossplane/crossplane) |
| `functions/go-templating` | [function-go-templating](https://github.com/crossplane-contrib/function-go-templating) |
| `functions/auto-ready` | [function-auto-ready](https://github.com/crossplane-contrib/function-auto-ready) |
| `functions/patch-and-transform` | [function-patch-and-transform](https://github.com/crossplane-contrib/function-patch-and-transform) |
| `providers/kubernetes` | [provider-kubernetes](https://github.com/crossplane-contrib/provider-kubernetes) |
| `charts/crossplane` | Helm chart (synced from `core/crossplane/cluster/charts/crossplane`; defaults use Konflux-oriented image registry paths — see chart README) |

## Components

- **Crossplane controller** – Core Crossplane runtime
- **Functions** – Go Templating, Auto Ready, Patch & Transform (built as OCI xpkg packages)
- **Kubernetes provider** – Provider package for Crossplane
- **Helm chart** – Same templates as upstream Crossplane; `values.yaml` defaults target Konflux-built controller images (`charts/crossplane/README.md` describes sync and release flow)

## Configuration

- **Renovate** – `renovate.json` configures MintMaker to track submodule **tags** (semver) only, not every commit. Digest updates are disabled.

## Cloning

```bash
git clone --recurse-submodules https://github.com/konflux-ci/crossplane-components.git
```

Or if already cloned:

```bash
git submodule update --init --recursive
```
