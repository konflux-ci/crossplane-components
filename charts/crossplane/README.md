# Crossplane Helm chart (Konflux)

This chart is the upstream [Crossplane cluster chart](https://github.com/crossplane/crossplane/tree/master/cluster/charts/crossplane) vendored into [konflux-ci/crossplane-components](https://github.com/konflux-ci/crossplane-components), with defaults aimed at **Konflux-built controller images** instead of `xpkg.crossplane.io` or other community registry defaults.

## Staying aligned with upstream

After moving the `core/crossplane` submodule to a new tag, refresh this directory from the submodule so templates stay in lockstep:

```bash
rsync -a --delete --exclude='.git' \
  core/crossplane/cluster/charts/crossplane/ charts/crossplane/
```

Then re-apply Konflux-specific changes:

- `Chart.yaml` — `version` / `appVersion` should track the Crossplane release you build in Konflux (and the image tag you publish).
- `values.yaml` — keep `image.repository` (and any default package URLs) pointing at your workspace registry paths.

The full upstream values reference and install history are in `core/crossplane/cluster/charts/crossplane/README.md` in the submodule.

## Defaults

- **`image.repository`** — defaults to `quay.io/konflux-ci/crossplane-components/crossplane`. Replace this with the image reference your Konflux **Application** / **Component** pushes (organization and repo layout vary by tenant).
- **`image.tag`** — empty means the chart uses `v` + `Chart.yaml` `appVersion` (same behavior as upstream). Prefer explicit tags or digests for production, and let automation (for example MintMaker/Renovate) bump them when Konflux publishes new builds.

`provider.packages`, `configuration.packages`, and `function.packages` are empty by default. Use full OCI references to packages built and published from this repository (or your registry), for example:

```yaml
provider:
  packages:
    - quay.io/my-org/crossplane/provider-kubernetes:vX.Y.Z
function:
  packages:
    - quay.io/my-org/crossplane/function-go-templating:vX.Y.Z
```

Set **`imagePullSecrets`** if your cluster must authenticate to Quay (or another private registry).

## Konflux / MintMaker workflow (high level)

1. Submodule updates (for example a new function tag) land in this repo.
2. Konflux builds and pushes the corresponding container or `xpkg` OCI artifact.
3. MintMaker/Renovate can open PRs to bump default image tags or package references in this chart.
4. A Konflux **Helm chart** component can `helm package` / push the chart as an OCI artifact, sign it per your pipeline policy.
5. Deployment repos should only pin **chart version** (or OCI chart digest), not duplicate chart source.

## Local checks

```bash
helm lint charts/crossplane
helm template crossplane charts/crossplane --namespace crossplane-system
```

## Install (example)

```bash
kubectl create namespace crossplane-system

helm install crossplane ./charts/crossplane \
  --namespace crossplane-system \
  --set image.repository=quay.io/<your-org>/<your-workspace>/crossplane \
  --set image.tag=v2.3.0-rc.0
```

Adjust values for HA, webhooks, metrics, and pre-installed providers/functions to match your platform design.
