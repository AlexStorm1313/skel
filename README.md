# 🦴 Skel

**Your environment, declared.**

Skel is a starter structure for deploying and managing Kubernetes resources
supported by `podman kube`, using Helm and Kubernetes manifests. Use it as a
foundation for a development workspace, an application stack, or infrastructure
you want to version alongside your code.

The included workflow renders manifests with Helm and runs them locally with
**Podman**. You do not need a Kubernetes cluster or a local Helm installation.
Skel provides the structure and workflow; you choose the workloads and how to use
them.

[Get started](#-getting-started) · [Commands](#-commands) ·
[Repository structure](#-repository-structure)

---

## 💡 Why it exists

An environment is more than a container image. It also includes configuration,
storage, networking, dependencies, and the commands needed to bring it together.
When those details live in manual setup steps, environments become difficult to
reproduce and changes are hard to review.

Skel gives those decisions a home in your repository:

- **Declare the environment.** Keep resource definitions and configuration in files
  rather than relying on remembered commands.
- **Review infrastructure like application code.** Track changes, discuss them in
  pull requests, and retain their history in Git.
- **Start small.** Use a Makefile, a Helm chart, and a container runtime instead of
  introducing a cluster just to run a local stack.
- **Build your own structure.** Add the applications and dependencies you need,
  without adopting a fixed collection of services.
- **Use familiar definitions.** Work with Kubernetes resource concepts while
  keeping runtime-specific differences explicit.

## ⚙️ How it works

```text
Helm templates + values.yaml
             │
             │ make kube
             ▼
   infrastructure/kube.yaml
             │
             │ make play (tears down first)
             ▼
      Local Podman resources
```

Helm runs in a disposable container and generates a manifest. Podman consumes that
manifest through `podman kube play`. There is no installed Helm release and no
Kubernetes control plane managing these local resources.

> [!NOTE]
> **A skeleton, not a prebuilt stack.** The repository includes chart metadata,
> example service values, shared security-context helpers, and lifecycle commands.
> It does not yet include application workload templates or container build
> definitions. Enabling a service in `values.yaml` alone does not deploy it; you
> must add its templates.

## 📁 Repository structure

```text
.
├── Makefile                       # Rendering, validation, and Podman lifecycle
├── containers/                    # Place your container build definitions here
└── infrastructure/
    ├── Chart.yaml                 # Helm chart metadata
    ├── values.yaml                # Environment configuration and service values
    ├── templates/
    │   └── _snippets.yaml         # Shared pod/container security contexts
    └── kube.yaml                  # Generated locally; ignored by Git
```

As your stack grows, group workload templates under `templates/deployments/`,
storage under `templates/volumes/`, and configuration resources under
`templates/configmaps/`. Keep non-secret configuration files under
`infrastructure/configs/` when needed.

## 🚀 Getting started

### Requirements

- GNU Make and Bash.
- Podman configured for your user, with support for `podman kube play`.
- Access to the container registries used by your images and the rendering tools.

The current workflow uses Linux-oriented settings, including SELinux volume
relabeling and explicit user namespace mappings. Review those settings for your host
and container images rather than assuming they work unchanged everywhere.

### 1. Define your environment

Copy this repository as your starting point. Review `infrastructure/values.yaml`
and replace the example images, paths, and service selections with your own.
Local image references require images you provide; Skel does not build them for
you.

Add workload templates and any corresponding volumes, ConfigMaps, or Secrets.
Use `.Release.Name` to prefix stack-owned resource names and keep references
consistent. See [the infrastructure authoring guide](infrastructure/AGENTS.md)
for patterns and conventions.

### 2. Render and inspect

Run Make commands from the repository root. Choose a unique, Helm-compatible
resource prefix and pass it consistently:

```bash
make kube NAMESPACE=my-environment
make validate NAMESPACE=my-environment
```

`make kube` generates `infrastructure/kube.yaml`; it does not start anything.
`make validate` is optional: it lints the chart and schema-checks the existing
manifest without regenerating it. Both commands may download tool images;
validation may also download schemas.

Review the generated file before deployment. Schema validation does not establish
Podman compatibility or application readiness.

### 3. Run with Podman

Once your workload templates are in place and you have reviewed the manifest:

```bash
# Tears down resources from the current manifest, then plays that same file.
make play NAMESPACE=my-environment

# Lists resources whose names contain the prefix.
make resources NAMESPACE=my-environment
```

Check actual container state and logs separately:

```bash
podman ps -a --pod
podman logs --tail 100 <container-name>
```

Use the exact container name from the listing. A successful Make message does not
mean the application is ready.

## 🧰 Commands

| Command | Behavior | Lifecycle |
| --- | --- | --- |
| `make` / `make kube` | Render the manifest; do not start the stack. | 📄 Render only |
| `make validate` | Lint the chart and schema-check the existing manifest. | 🔎 Check only |
| `make resources` | List prefix-matching pods, volumes, and networks. | 📋 List only |
| `make play` | Tear down, then run the existing manifest; do not render again. | ⚠️ Destructive |
| `make down` | Tear down resources described by the existing manifest. | ⚠️ Destructive |
| `make workspace` | Tear down, render, then run the stack. | ⚠️ Destructive |

Run lifecycle commands serially, not with `make -j`. Teardown requires the existing
manifest; if it is missing, investigate before trying to recreate or remove
resources manually.

`IMAGE_PULL_POLICY` defaults to `IfNotPresent`. Override it through the environment
or a Make argument; supported values are `Always`, `IfNotPresent`, and `Never`:

```bash
make kube NAMESPACE=my-environment IMAGE_PULL_POLICY=Always
```

## 🌳 Multiple environments and worktrees

> [!IMPORTANT]
> Despite its name, `NAMESPACE` is a **resource-name prefix**, passed as Helm's
> release name. It is not a Kubernetes namespace or an isolation boundary.

Give each deployed worktree or environment its own prefix. There is no automatic
branch or worktree naming integration; use `make ... NAMESPACE=your-prefix`.
An ordinary environment variable does not override the Makefile's default
assignment; pass the prefix explicitly as a Make argument.

Keep the prefix stable for the deployment's lifetime. Changing `NAMESPACE` on
`play` or `down` does not change the names in the existing manifest. Do not render
over the only manifest for a running deployment with a different prefix before
planning its teardown.

Distinct prefixes do not prevent host-port conflicts or isolate shared host paths,
networks, or sockets. Coordinate those resources separately. The `resources`
command uses substring matching, so verify exact ownership before acting.

## 🔐 Configuration and secrets

Edit chart sources and values, not generated `infrastructure/kube.yaml`. Keep
credentials out of committed values and ConfigMaps. Existing ignore rules cover
specific local secret paths and the generated manifest, not every possible
secret file. Review new paths before committing.

Generated manifests can contain sensitive data. Do not publish them or logs
without reviewing their contents.

---

## 📜 License

[MIT](LICENSE).
