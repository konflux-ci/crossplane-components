# crossplane-components

Build and release Crossplane components with Konflux for supply chain security, instead of consuming them from the community helm chart and `xpg.upbound.io` registry.

## Repository structure

This repository uses git submodules to aggregate upstream Crossplane source:

| Path | Source |
|------|--------|
| `core/crossplane` | [crossplane/crossplane](https://github.com/crossplane/crossplane) |
| `functions/go-templating` | [function-go-templating](https://github.com/crossplane-contrib/function-go-templating) |
| `functions/auto-ready` | [function-auto-ready](https://github.com/crossplane-contrib/function-auto-ready) |
| `functions/patch-and-transform` | [function-patch-and-transform](https://github.com/crossplane-contrib/function-patch-and-transform) |
| `providers/kubernetes` | [provider-kubernetes](https://github.com/crossplane-contrib/provider-kubernetes) |
| `charts/crossplane` | Helm chart (based on `core/crossplane/cluster/charts/crossplane`) |

## Components

- **Crossplane controller** – Core Crossplane runtime
- **Functions** – Go Templating, Auto Ready, Patch & Transform (built as OCI xpkg packages)
- **Kubernetes provider** – Provider package for Crossplane
- **Helm chart** – Custom chart configured to use Konflux-built images

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
