# Infrastructure authoring

This file supplements the repository-root `AGENTS.md` for changes under
`infrastructure/`. Keep lifecycle/Podman operations in the root guide; keep chart
and resource-authoring conventions here. Avoid duplicating instructions in every
template directory unless that directory needs genuinely different rules.

## Chart structure and runtime

- `Chart.yaml`: static Helm chart metadata. Its name is not a workspace identity.
- `values.yaml`: service enablement, images, and other configuration defaults.
- `templates/deployments/`: workload templates.
- `templates/volumes/`: PVC templates mapped to Podman named volumes.
- `templates/configmaps/`: configuration resources when needed.
- `templates/_snippets.yaml`: shared pod/container security-context helpers.
- `configs/`, `secrets/`, `state/`: configuration and local runtime inputs. Inspect
  relevant paths only; do not enumerate or read secret contents unnecessarily.
- `kube.yaml`: generated output, not a source file. Never edit or commit it.

The target runtime is **Podman kube play**, not a Kubernetes cluster. Confirm
Podman support before introducing a resource kind, field, storage feature, or
controller behavior. A valid Kubernetes schema does not imply Podman support.
Do not assume Kubernetes Services, Ingress, RBAC, or namespace isolation work as
they would in a cluster.

Prefer Bash for shell commands when the selected image provides it. Minimal
images may only have `sh`; the BusyBox example below uses that fallback. Do not
switch an image's entrypoint to Bash without confirming Bash is installed.

## Required namespace scoping

Multiple worktrees can deploy to the same Podman backend. **Every new stack-owned
top-level resource name must include `{{ .Release.Name }}` as its prefix.**
The Makefile passes `NAMESPACE` as the Helm release name; it is not
`metadata.namespace`. Never hardcode the current namespace, use `.Chart.Name`
as the identity, or rely on a Kubernetes Namespace to prevent collisions.

Use exactly three naming layers: **`{namespace}-{pod}-{container}`**.

- `{namespace}` is `{{ .Release.Name }}`, supplied through `NAMESPACE`.
- `{pod}` is the logical pod name, without its namespace prefix.
- `{container}` is the container's local name within that pod.

| Resource/reference | Pattern |
| --- | --- |
| Pod identity | `{namespace}-{pod}` |
| Application container identity | `{namespace}-{pod}-{container}` |
| Container-scoped PVC / claim reference | `{namespace}-{pod}-{container}` |
| Container-scoped ConfigMap / Secret and references | `{namespace}-{pod}-{container}` |
| Identity labels and selectors | Match the owning namespace-prefixed identity |

Do not introduce additional naming layers. Derive each name from its owning
pod/container and keep references identical. If a container needs multiple
resources of the same kind, agree on that naming extension before introducing
one. Preserve existing deployed names unless a migration is requested: renaming
a claim can disconnect data or cause recreation.

Keep all references consistent: Deployment selectors must match pod labels;
`claimName`, configuration references, and volume mounts must point to the exact
rendered names. Repeated container-local names such as `server`, `data`, and
`http` are fine inside their own pod. They do not need global prefixes, but a
bare network alias such as `server` is not a unique cross-workspace identity.

Name prefixes do **not** isolate everything:

- Host ports still collide on the same host address. Do not add a fixed
  `hostPort` casually; make host bindings explicit and coordinate allocation.
- A fixed writable `hostPath` shares data across releases. Prefer scoped PVCs,
  or require a clearly scoped host path. Do not interpolate unchecked names into
  arbitrary host paths or cleanup commands.
- Shared networking is intentional where services need to communicate; do not
  create a per-release network by default just for naming uniqueness.
- Existing host Podman/SSH-agent sockets are intentionally shared capabilities,
  not resources created per release. Document any new shared-resource exception.
- Never clean up using a broad namespace-prefix regex. Discover and verify exact
  owned resource names before any destructive operation.

## Example: add an optional service with persistent data

Add configuration to the existing `services:` mapping in `values.yaml` (do not
create a second `services:` key). Default new services to disabled unless their
activation is explicitly requested:

```yaml
services:
  example:
    enabled: false
    image: docker.io/library/busybox:1.37
```

The following direct Pod example uses `example` for `{pod}` and `server` for
`{container}`. Create it under `templates/pods/example.yaml` (create that
directory if needed):

```yaml
{{ if .Values.services.example.enabled }}
apiVersion: v1
kind: Pod
metadata:
  name: {{ .Release.Name }}-example
  labels:
    app: {{ .Release.Name }}-example
spec:
  {{ include "pod.securityContext" . | indent 2 }}
  containers:
    - name: server
      {{ include "container.securityContext" . | indent 6 }}
      image: {{ .Values.services.example.image | quote }}
      imagePullPolicy: {{ .Values.deployments.containers.pullPolicy }}
      command: ["sh", "-c", "while :; do sleep 3600; done"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: {{ .Release.Name }}-example-server
{{ end }}
```

Create `templates/volumes/example.yaml` with the **same enablement condition**:

```yaml
{{ if .Values.services.example.enabled }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ .Release.Name }}-example-server
spec: {}
{{ end }}
```

`spec: {}` follows this repository's Podman PVC convention; it is not a portable
Kubernetes storage configuration. Reuse the security helpers rather than
silently relaxing privileges. Check that the real application supports UID 1001,
group 0, a read-only root filesystem, and writable paths limited to declared
mounts. Add probes only when supported by the runtime and application.

The example's pod identity is `{namespace}-example`; its application container
and PVC identities are `{namespace}-example-server`. The local volume name
`data` connects the mount to the claim declaration; it is not another global
naming layer. For existing Deployment templates, Podman can transform runtime
names: confirm them through discovery rather than adding naming layers to this
convention. This documentation example does not migrate existing templates.

`make validate` is available from the repository root as an optional check, not a
required authoring or deployment step. It lints the chart and schema-checks the
existing `kube.yaml` without regenerating or overwriting it or starting/stopping
the stack. If an updated manifest is wanted, `make kube NAMESPACE="{namespace}"`
generates it; replace the namespace placeholder and preserve any older manifest
needed for teardown. Validation does not verify naming isolation, Podman
compatibility, or readiness; review scoping and references when authoring.

Keep local secrets out of examples, generated output shared with others, and Git.
Do not weaken root `.gitignore` rules or assume `.helmignore` alone protects
credentials. Scope Secret names and references exactly like other resources.
