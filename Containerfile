# OCI image definition for the Crossplane controller used in Konflux and local builds.
#
# Stage `build`: produces the Helm CLI (from build-helm modules), validates and packages
# charts/crossplane, compiles composition functions and provider-kubernetes for supply-chain
# verification, and links the crossplane binary. Artifacts remain under /workspace/dist except
# /tmp/crossplane, which is copied into the runtime stage.
#
# Final stage: Red Hat Universal Base Image (minimal) containing only the crossplane binary,
# cluster CRDs, and webhook configuration—matching the upstream controller deployment surface.
# Inspect the full build tree: podman build --target build …

# Builder image (UBI Go toolset) pinned by digest
ARG GO_BUILD_IMAGE=registry.access.redhat.com/ubi9/go-toolset@sha256:b2c0898987b688a95f4d2f38abdfd929f45903948831783153019ab749495c72

FROM ${GO_BUILD_IMAGE} AS build

USER root

ARG TARGETARCH=amd64
ENV GOARCH=${TARGETARCH}

# CROSSPLANE_VERSION: Optional value for -ldflags version injection (include leading v). Unset — read appVersion from charts/crossplane/Chart.yaml.
ARG CROSSPLANE_VERSION=

WORKDIR /workspace

# Helm CLI: single layer for module download and static build (Hermeto/cachi2: source cachi2.env when mounted).
COPY build-helm/go.mod build-helm/go.sum /workspace/build-helm/
WORKDIR /workspace/build-helm
RUN if [ -f /cachi2/cachi2.env ]; then . /cachi2/cachi2.env; fi && \
	go mod download && \
	CGO_ENABLED=0 GOOS=linux go build -trimpath -o /usr/local/bin/helm helm.sh/helm/v3/cmd/helm

WORKDIR /workspace
COPY . .

RUN helm version

# Submodules must be present in the build context (Konflux git-clone with submodules, or host: git submodule update --init --recursive).
RUN set -eux; \
	if [ ! -f core/crossplane/go.mod ] \
		|| [ ! -f functions/go-templating/go.mod ] \
		|| [ ! -f functions/auto-ready/go.mod ] \
		|| [ ! -f functions/patch-and-transform/go.mod ] \
		|| [ ! -f providers/kubernetes/go.mod ]; then \
		echo "Missing submodule content: run 'git submodule update --init --recursive' on the host," \
			"or rely on Konflux git-clone (submodules enabled)." >&2; \
		exit 1; \
	fi

RUN mkdir -p /workspace/dist/bin /workspace/dist/charts

# Chart quality gate and distributable tarball (retained on build stage only).
RUN helm lint charts/crossplane \
	&& helm package charts/crossplane -d /workspace/dist/charts

# Composition functions: compile-only verification; not shipped in the runtime image.
RUN set -eux; \
	if [ -f /cachi2/cachi2.env ]; then . /cachi2/cachi2.env; fi; \
	cd /workspace/functions/go-templating && go build -trimpath -o /workspace/dist/bin/function-go-templating .

RUN set -eux; \
	if [ -f /cachi2/cachi2.env ]; then . /cachi2/cachi2.env; fi; \
	cd /workspace/functions/auto-ready && go build -trimpath -o /workspace/dist/bin/function-auto-ready .

RUN set -eux; \
	if [ -f /cachi2/cachi2.env ]; then . /cachi2/cachi2.env; fi; \
	cd /workspace/functions/patch-and-transform && go build -trimpath -o /workspace/dist/bin/function-patch-and-transform .

# provider-kubernetes controller binary: compile-only; PLATFORM matches TARGETARCH (linux_amd64, linux_arm64, …).
RUN set -eux; \
	if [ -f /cachi2/cachi2.env ]; then . /cachi2/cachi2.env; fi; \
	cd /workspace/providers/kubernetes && make go.build PLATFORM=linux_${TARGETARCH}

RUN set -eux; \
	cp "/workspace/providers/kubernetes/_output/bin/linux_${TARGETARCH}/provider" /workspace/dist/bin/provider-kubernetes

# Crossplane controller: version string embedded for crossplane --version and diagnostics.
RUN set -eux; \
	if [ -f /cachi2/cachi2.env ]; then . /cachi2/cachi2.env; fi; \
	cd /workspace/core/crossplane; \
	ver="${CROSSPLANE_VERSION:-}"; \
	if [ -z "$ver" ]; then \
		ver="v$(awk '/^appVersion:[[:space:]]+/ { sub(/^appVersion:[[:space:]]+/, ""); print; exit }' /workspace/charts/crossplane/Chart.yaml)"; \
	fi; \
	CGO_ENABLED=0 GOOS=linux go build -trimpath \
		-ldflags="-s -w -X=github.com/crossplane/crossplane/v2/internal/version.version=${ver}" \
		-o /tmp/crossplane \
		./cmd/crossplane

RUN cp /tmp/crossplane /workspace/dist/bin/crossplane

FROM registry.access.redhat.com/ubi9-minimal@sha256:1bc3c5c15720506a0cf48adfdf8b623dfe704377e007d7bbae8d14876392ca6a

LABEL name="crossplane" \
	vendor="Red Hat, Inc." \
	summary="Crossplane controller" \
	description="Cloud native control plane"

COPY --from=build /tmp/crossplane /usr/local/bin/crossplane
COPY --from=build /workspace/core/crossplane/cluster/crds /crds
COPY --from=build /workspace/core/crossplane/cluster/webhookconfigurations /webhookconfigurations

USER 65532:65532

# RHEL/UBI CA bundle path (not DEBIAN_FRONTEND /usr/ssl paths). Ensures Go and other TLS clients trust the system trust store.
ENV SSL_CERT_FILE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem

ENTRYPOINT ["/usr/local/bin/crossplane"]
