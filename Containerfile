FROM registry.access.redhat.com/ubi9/go-toolset:1.25.8-1774618347 AS build

USER root

ENV PLATFORM=linux_amd64

RUN dnf -y install git make ca-certificates bash \
	&& dnf clean all \
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
