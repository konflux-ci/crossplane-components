// Package tools records a build-time dependency on the Helm v3 command module so that
// `go mod` resolves helm.sh/helm/v3 and Hermeto/Cachi2 gomod prefetch can vendor the same tree
// used to compile the Helm CLI in the Containerfile. This package is not imported at runtime.
package tools

import _ "helm.sh/helm/v4/cmd/helm"
