# Stack operations

## Runtime and configuration

- Prefer Bash for scripts, Make recipes, and interactive container shells when
  available. Use `sh` only where Bash is unavailable, such as minimal images;
  do not assume every container includes Bash.
- Operate this stack with **Podman**, not Docker, Kubernetes, or `kubectl`.
  Helm renders Kubernetes YAML; `podman kube play` runs it locally. There is
  no Helm release installed in a Kubernetes cluster.
- Run Make commands from this repository/worktree root, using the same user and
  Podman connection as the existing stack. Do not switch to `sudo podman`:
  rootful and rootless Podman have different resource stores.
- `Makefile` defines the lifecycle, `infrastructure/values.yaml` configures the
  chart, and `infrastructure/templates/` defines the resources. Edit those
  sources rather than hand-editing generated `infrastructure/kube.yaml`.
- The generated manifest is ignored by Git and is local to each worktree.
  It records what `play` and `down` will target. Read it before lifecycle actions;
  it may be absent or stale relative to the Makefile and templates.
- `NAMESPACE` is a resource-name prefix passed as Helm's release name, **not** a
  Kubernetes namespace. Keep it unique across worktrees sharing a Podman backend
  and stable for a worktree's deployed lifetime.

## Make commands

| Command | Effect |
| --- | --- |
| `make` / `make kube` | Render `infrastructure/kube.yaml` using a disposable Helm container. Does not start the stack. May pull the renderer image. |
| `make resources` | List namespace-matching pods, volumes, and networks; empty sections show `(none)`. |
| `make validate` | Check diff whitespace, lint the chart, and schema-check a fresh render using disposable containers, without overwriting `kube.yaml` or changing stack resources. May download images and schemas; does not verify Podman compatibility or readiness. |
| `make down` | Tear down resources described by the current manifest with `podman kube down --force`. |
| `make play` | Run `down` first, then play the existing manifest. Does **not** render it again. |
| `make workspace` | Run teardown, render the manifest, then play it. Recreates the workspace. |

**Destructive operations:** `down`, `play`, and `workspace` can remove PVC-backed
volumes, including application data at the manifest's declared mount paths.
They are not read-only checks or safe restart commands. Obtain explicit authorization before
using them if data loss is not already part of the requested operation. Do not
use them just to validate output formatting.

Run lifecycle targets serially; do not use `make -j`. Their prerequisite graph
does not enforce the intended ordering under parallel Make. Missing manifests
can make teardown fail; inspect the situation rather than masking the failure.

Set a nonempty, unique `NAMESPACE` in your shell, then pass it consistently:

```sh
make kube NAMESPACE="$NAMESPACE" IMAGE_PULL_POLICY=IfNotPresent
make resources NAMESPACE="$NAMESPACE"
# Destructive: only after authorization and checking the existing manifest:
make workspace NAMESPACE="$NAMESPACE" IMAGE_PULL_POLICY=IfNotPresent
```

- Use `make ... NAMESPACE=...`: the current Makefile assignment overrides an
  ordinary environment `NAMESPACE` value.
- `IMAGE_PULL_POLICY` supports environment or Make command-line overrides. Read
  its current default in the Makefile; valid values are `Always`, `IfNotPresent`,
  and `Never`. The Helm CLI override takes precedence over `values.yaml`.
- Changing `NAMESPACE` on `play` or `down` does **not** change the existing YAML's
  resource names. `workspace` tears down the old manifest before rendering the
  new namespace. Do not regenerate over the only record of a running deployment
  under a different prefix without first planning its teardown.
- Printed "started"/"ready" messages do not verify application readiness.
  Check container state and logs separately.

## Resource naming and discovery

Use names from the **rendered manifest**, then confirm them against Podman.
Do not assume the Makefile default describes already-running resources.

Naming components (braces below denote placeholders, not literal text):

- `{namespace}`: the unique Helm release-name prefix supplied by `NAMESPACE`.
- `{pod}`: the logical pod name, without the namespace prefix.
- `{container}`: the container's local name within that pod.

These are the three naming layers: **`{namespace}-{pod}-{container}`**.

| Resource | Convention / source of truth |
| --- | --- |
| Pod identity | `{namespace}-{pod}` |
| Application container identity | `{namespace}-{pod}-{container}` |
| Container-scoped PVC, ConfigMap, or Secret | `{namespace}-{pod}-{container}`, with matching references from consumers |

Read `metadata.name` for the declared resource identity and `containers[].name`
for the local container component (`spec.template.spec` for Deployments,
`spec` for direct Pods). Do not add the namespace twice. Follow each volume's declaration:
a pod-local volume name is not necessarily the backend volume/claim name, and
a `hostPath` refers to a host path rather than a named volume.

Confirm actual names with Podman before acting; these conventions are not a
substitute for runtime discovery. Podman may transform names when converting
Deployments, so use discovered names rather than inventing extra naming layers.
Infra-container names/IDs are runtime-generated,
not stable application identifiers. The static chart name is not the prefix.

```sh
podman pod ps
podman ps -a --pod --format '{{.Names}} | {{.PodName}} | {{.Status}}'
podman volume ls
podman network ls
```

`make resources` uses a literal substring filter, not an exact ownership check.
Verify exact names before acting; similar prefixes can appear together. Shared
networks need not include the namespace, so `(none)` does not mean no networking.
Networking is intentionally allowed to be shared. Use confirmed, qualified pod
or container names rather than assuming a pod-local container alias is unique.

## Logs, inspection, and exec

Replace `{namespace}`, `{pod}`, and `{container}` below with the actual naming
components confirmed from the manifest and Podman listing. These are documentation
placeholders, not environment variables. Use the exact discovered names if Podman
has transformed them. Logs/inspection are useful first steps; exec runs commands
inside the application container and can modify its state.

```sh
podman pod inspect '{namespace}-{pod}'
podman inspect '{namespace}-{pod}-{container}'
podman logs --tail 100 '{namespace}-{pod}-{container}'
podman logs --follow '{namespace}-{pod}-{container}'
podman exec '{namespace}-{pod}-{container}' id
podman exec -it '{namespace}-{pod}-{container}' bash
```

Prefer container logs to querying the pod's infra container. Use `podman ps -a`
to find exited containers when troubleshooting. Inspect output and logs can
contain credentials: do not publish sensitive fields. If host Podman or SSH-agent
sockets are mounted, they are shared host capabilities; commands inside a container
may affect resources outside this stack. Do not prune resources or delete by a
broad prefix to fix a single workspace.

Use `make validate NAMESPACE="{namespace}"` before deployment. Preserve ignore
rules for generated manifests and local secrets; never commit credentials or
dump secret files as part of diagnosis.
