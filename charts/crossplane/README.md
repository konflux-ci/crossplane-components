# Crossplane Helm chart (konflux-ci/crossplane-components)

This chart vendors the upstream [Crossplane cluster chart](https://github.com/crossplane/crossplane/tree/master/cluster/charts/crossplane) into this repository. Defaults target the controller image published from this project instead of community registry paths such as `xpkg.crossplane.io`.

## Synchronizing with upstream

When the `core/crossplane` submodule is updated to a new release, refresh chart templates from upstream:

```bash
rsync -a --delete --exclude='.git' \
  core/crossplane/cluster/charts/crossplane/ charts/crossplane/
```

Re-apply repository-specific metadata afterward:

- **`Chart.yaml`** — `version` and `appVersion` must match the Crossplane release and the controller image you publish.
- **`values.yaml`** — Confirm `image.repository`, package defaults, and any registry-specific settings match your production registry layout.

The upstream values reference and release notes remain in `core/crossplane/cluster/charts/crossplane/README.md` inside the submodule.

## Default values

| Area | Behavior |
|------|----------|
| **`image.repository`** | `quay.io/konflux-ci/crossplane-components/crossplane` — public image built from this repository. Override for private registries or alternate promotion paths. |
| **`image.tag`** | Empty — not appended to the image reference by default (see `ignoreTag`). |
| **`image.ignoreTag`** | `true` — the chart uses `image.repository` as-is without appending any tag. This is the expected default for digest-pinned or externally managed image references. Set to `false` to re-enable tag-based resolution (empty `image.tag` falls back to `v{appVersion}`). |

`provider.packages`, `configuration.packages`, and `function.packages` default to empty lists. Populate with full OCI references for packages you install with the release, for example:

```yaml
provider:
  packages:
    - registry.example.org/org/provider-kubernetes:v1.0.0
function:
  packages:
    - registry.example.org/org/function-go-templating:v1.0.0
```

Configure **`imagePullSecrets`** when clusters pull from authenticated registries.

## Release and automation workflow

1. Submodule tags move to new upstream versions as needed.
2. Konflux (or equivalent) builds and pushes container and package artifacts.
3. MintMaker/Renovate may propose dependency and image updates.
4. Chart OCI artifacts can be packaged, signed, and promoted per organizational policy.
5. Downstream environments should pin chart version or chart digest rather than copying raw chart sources.

## Validation

```bash
helm lint charts/crossplane
helm template crossplane charts/crossplane --namespace crossplane-system
```

## Installation

```bash
kubectl create namespace crossplane-system

helm install crossplane ./charts/crossplane \
  --namespace crossplane-system

# Override image location for a non-default registry (example placeholders).
helm install crossplane ./charts/crossplane \
  --namespace crossplane-system \
  --set image.repository='registry.example.org/org/crossplane-controller' \
  --set image.tag='<immutable-tag-or-digest>'
```
