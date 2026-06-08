---
name: pr-checklist
description: Definition of done and pre-PR validation checklist for crossplane-components. Use when the user is about to open a PR, asks what to check before merging, wants to know if their changes are ready, or asks about CI requirements for this repo.
disable-model-invocation: true
---

# PR Checklist

This repo has no unit test suite. Validation is done through Helm tooling and a container build. AGENTS.md defines rules and constraints; this skill is the step-by-step pre-PR checklist.

## Checklist

### Always

- [ ] `git submodule status` — confirm no unintended submodule changes (dirty or unexpected refs)
- [ ] `podman build -f Containerfile --target build -t crossplane-components:build .` — compile-checks all Go targets; a failure here means a submodule bump is broken

### If chart files changed (`charts/crossplane/**`)

- [ ] `helm lint charts/crossplane`
- [ ] `helm template crossplane charts/crossplane --namespace crossplane-system` — catches rendering errors lint misses
- [ ] `Chart.yaml` metadata (`name: crossplane-konflux-ci`, `version`, `appVersion`) is correct and not overwritten by an upstream rsync
- [ ] `values.yaml` registry defaults (`image.repository`, `provider.packages`, `function.packages`) are Konflux Quay refs, not upstream community refs

### If `Containerfile` changed

- [ ] New Go compilation target? → add its `gomod` path to `prefetch-input` in **every** affected `.tekton/` PipelineRun
- [ ] Base image digest changed? → only update intentionally after scanner review; routine digest bumps are Renovate's job

### If `.tekton/` PipelineRun changed

- [ ] New PipelineRun preserves the hermetic default for its pipeline type (`"true"` for controller, `"false"` for chart/functions/provider)
- [ ] `prefetch-input` lists every `gomod` root compiled by that pipeline's `Containerfile` invocation

### If submodule ref changed

- [ ] New ref corresponds to a semver tag (no bare SHA pins)
- [ ] For `core/crossplane`: chart synced via `rsync` and `Chart.yaml`/`values.yaml` overrides restored (see `skills/bump-component/`)

---

## CI behaviour

Twelve PipelineRuns in `.tekton/` fire on every PR. A missing `prefetch-input` entry fails silently in local networked builds but breaks the hermetic pipeline.

Fork PRs require a maintainer trigger before Konflux pipelines run.

---

## What Renovate owns (do not duplicate manually)

- Submodule version bumps
- Go module version updates
- Base image digest updates in `Containerfile`
