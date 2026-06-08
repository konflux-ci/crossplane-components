---
name: bump-component
description: Full workflow for bumping a Crossplane component version in this repo (submodule update, chart sync, digest pin updates in values.yaml). Use when the user wants to upgrade crossplane, a composition function, or provider-kubernetes to a new release, or when Renovate has opened a submodule bump PR that needs manual steps completed.
disable-model-invocation: true
---

# Bump a Component Version

This repo pins upstream components as Git submodules. Renovate normally opens PRs for semver bumps; this skill covers what to do when completing or performing a manual bump. AGENTS.md defines rules and constraints; this skill is the step-by-step procedure.

## Which component are you bumping?

- **`core/crossplane`** → follow all steps below (submodule + chart sync + digest pins)
- **`functions/*` or `providers/kubernetes`** → follow submodule step + digest pin step only

---

## Step 1 — Update the submodule ref

```bash
cd <submodule-path>          # e.g. core/crossplane
git fetch --tags
git checkout <new-tag>       # e.g. v2.4.0
cd -
git add <submodule-path>
```

Verify:
```bash
git submodule status <submodule-path>
```

---

## Step 2 — Sync the Helm chart (core/crossplane bumps only)

After bumping `core/crossplane`, re-vendor the chart templates from upstream:

```bash
rsync -a --delete --exclude='.git' \
  core/crossplane/cluster/charts/crossplane/ charts/crossplane/
```

Then **manually restore** the three repository-specific overrides that `rsync` will have clobbered:

### `charts/crossplane/Chart.yaml`
- `name` → must remain `crossplane-konflux-ci`
- `version` and `appVersion` → set to the new Crossplane release (e.g. `2.4.0`)
- `maintainers` → restore to Konflux CI block (see current file before rsync)
- `source` → restore to this repo's URLs

### `charts/crossplane/values.yaml`
- `image.repository` → `quay.io/konflux-ci/crossplane-components`
- `image.tag` → leave as `""` (chart derives the tag as `v` + `appVersion` from `Chart.yaml`)
- `provider.packages` → keep existing ref (see Step 3)
- `function.packages` → keep existing refs (see Step 3)

> Tip: run `git diff charts/crossplane/Chart.yaml charts/crossplane/values.yaml` after rsync to confirm only the expected upstream changes came in.

---

## Step 3 — Update OCI digest pins in `values.yaml`

`provider.packages` and `function.packages` in `charts/crossplane/values.yaml` carry digest-pinned OCI refs. When you bump a function or provider submodule, update its corresponding entry to the new image digest published by the Konflux pipeline for that component.

The digest is available from the component's push pipeline output in Konflux, or from:

```bash
skopeo inspect --format '{{.Digest}}' \
  docker://quay.io/konflux-ci/crossplane-components/<component>:<tag>
```

The current `values.yaml` uses bare refs (no tag or digest). When bumping, update the affected entry to include the new digest:

```yaml
provider:
  packages:
    - quay.io/konflux-ci/crossplane-components/provider-kubernetes@sha256:<new-digest>
function:
  packages:
    - quay.io/konflux-ci/crossplane-components/function-go-templating@sha256:<new-digest>
    - quay.io/konflux-ci/crossplane-components/function-auto-ready@sha256:<new-digest>
    - quay.io/konflux-ci/crossplane-components/function-patch-and-transform@sha256:<new-digest>
```

---

## Step 4 — Validate

```bash
# Chart structure (required if chart files changed)
helm lint charts/crossplane
helm template crossplane charts/crossplane --namespace crossplane-system

# Compile-check all Go targets (catches build breaks from the bump)
podman build -f Containerfile --target build -t crossplane-components:build .
```

A failing build stage means the submodule version introduced a compilation break. Roll back the submodule ref or wait for an upstream fix — do not patch upstream source.

---

## Notes

- Renovate owns routine version bumps. Only do this manually when Renovate cannot (e.g. pre-release tags, emergency rollback).
- Never pin submodules to non-release commits (SHAs without a semver tag).
- The controller image and Helm chart OCI artifact have independent release lifecycles — bumping a submodule does not automatically trigger a chart release.
