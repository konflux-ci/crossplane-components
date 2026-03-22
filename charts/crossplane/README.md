# Crossplane Helm Chart

This directory will contain the Helm chart for Crossplane, configured to use images
built by Konflux.

The upstream chart source is in `core/crossplane/cluster/charts/crossplane`. This chart
will be customized to reference our Konflux-built images (controller, functions,
provider) instead of `xpg.upbound.io`.
