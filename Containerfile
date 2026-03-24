# syntax=docker/dockerfile:1
#
# Reproducible build image for chart + Go components (same defaults as scripts/build-all.sh,
# without Nix core or Docker-in-Docker xpkg builds).
#
# Prerequisites: from the repository root, either check out submodules on the host, or include
# .git in the build context so RUN git submodule can fetch them during the image build.
#
# Examples:
#   git submodule update --init --recursive
#   podman build -f Containerfile -t crossplane-components-build .
#   cid=$(podman create crossplane-components-build) && podman cp "$cid":/workspace/dist ./dist && podman rm "$cid"
#
#   docker build -f Containerfile -t crossplane-components-build .
#

FROM docker.io/library/golang:1.25.6-bookworm AS build

RUN apt-get update \
	&& apt-get install -y --no-install-recommends git make curl ca-certificates bash \
	&& rm -rf /var/lib/apt/lists/* \
	&& curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

WORKDIR /workspace

COPY . .

RUN set -eux; \
	if [ -e .git ]; then \
		git submodule update --init --recursive; \
	elif [ ! -f functions/go-templating/go.mod ] || [ ! -f providers/kubernetes/go.mod ]; then \
		echo "Missing submodule content: run 'git submodule update --init --recursive' on the host," \
			"or build with a context that includes .git for automatic submodule fetch." >&2; \
		exit 1; \
	fi

RUN mkdir -p dist/bin dist/charts

RUN helm lint charts/crossplane \
	&& helm package charts/crossplane -d dist/charts

RUN cd functions/go-templating && go build -o /workspace/dist/bin/function-go-templating .
RUN cd functions/auto-ready && go build -o /workspace/dist/bin/function-auto-ready .
RUN cd functions/patch-and-transform && go build -o /workspace/dist/bin/function-patch-and-transform .

RUN cd providers/kubernetes && make go.build

# Default image keeps /workspace/dist for `podman cp` / `docker cp`.
CMD ["sh", "-c", "echo 'Artifacts in /workspace/dist:' && find dist -type f"]
