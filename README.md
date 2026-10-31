# 🦴 Skel

**Your environment, declared.**

Skel is a starter structure for defining, deploying, and managing application
environments with **Helm**, **Kubernetes manifests**, and **Podman**. It works with
the Kubernetes resources supported by `podman kube`—no cluster or local Helm
installation required.

Use it for a development workspace, an application stack, or infrastructure you
want to version alongside your code. Skel provides the structure and workflow;
you choose the workloads.

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
- **Review changes in Git.** Treat infrastructure like application code, with
  pull requests and a shared history.
- **Start small.** Use a Makefile, a Helm chart, and a container runtime instead of
  introducing a cluster just to run a local stack.
- **Make it your own.** Add the applications and dependencies you need,
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

Helm runs in a disposable container and renders `infrastructure/kube.yaml`.
Podman then runs the resources through `podman kube play`. Helm is used only for
templating: no Helm release is installed, and no Kubernetes control plane is
involved.

> [!NOTE]
> **A skeleton, not a prebuilt stack.** The repository includes chart metadata,
> example service values, shared security-context helpers, and lifecycle commands.
> It does not include application workload templates or container build
> definitions. Enabling a service in `values.yaml` alone does not deploy it; you
> must add its templates.

## 📁 Repository structure

```text
.
├── Makefile                       # Rendering, validation, and Podman lifecycle
├── containers/                    # Your container build definitions
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

The Makefile uses Linux-oriented settings, including SELinux volume relabeling
and explicit user namespace mappings. Adjust them to suit your host and container
images.

### 1. Define your environment

Start from a copy of this repository. Update `infrastructure/values.yaml` with
your images, paths, and service selections. Build or pull any required images;
Skel does not build them for you.

Add workload templates and any corresponding volumes, ConfigMaps, or Secrets.
Use `.Release.Name` to prefix stack-owned resource names and keep references
consistent. See [the infrastructure authoring guide](infrastructure/AGENTS.md)
for patterns and conventions.

### 2. Render and inspect

Run Make commands from the repository root. Choose a unique, Helm-compatible
resource prefix and pass it consistently:

```bash
make kube NAMESPACE=my-environment

# Optional: lint the chart and validate the rendered manifest.
make validate NAMESPACE=my-environment
```

`make kube` generates `infrastructure/kube.yaml`; it does not start anything.
`make validate` lints the chart and schema-checks the existing manifest without
regenerating it. Both commands may download tool images; validation may also
download schemas.

Review the generated file before deployment. Schema validation does not establish
Podman compatibility or application readiness.

### 3. Run with Podman

Run the manifest you reviewed:

```bash
# Tear down resources from the current manifest, then run that same file.
make play NAMESPACE=my-environment

# List resources whose names contain the prefix.
make resources NAMESPACE=my-environment
```

Then check container state and application logs:

```bash
podman ps -a --pod
podman logs --tail 100 your-container-name
```

Replace `your-container-name` with the exact name from the listing. A successful
Make message does not mean the application is ready.

## 🧰 Commands

| Command | What it does | Effect |
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

### Image pull policy

`IMAGE_PULL_POLICY` defaults to `IfNotPresent`. Override it through the environment
or a Make argument; supported values are `Always`, `IfNotPresent`, and `Never`:

```bash
make kube NAMESPACE=my-environment IMAGE_PULL_POLICY=Always
```

## 🌳 Multiple environments and worktrees

> [!IMPORTANT]
> Despite its name, `NAMESPACE` is a **resource-name prefix**, passed as Helm's
> release name. It is not a Kubernetes namespace or an isolation boundary.

Give each deployed worktree or environment a unique prefix and pass it explicitly
as a Make argument, as in the examples above. Branch and worktree names are not
detected automatically, and an environment variable alone does not override the
Makefile's default assignment.

Keep the prefix stable for the deployment's lifetime. `play` and `down` use the
names in the existing manifest, regardless of the `NAMESPACE` argument. Before
rendering a different prefix into that file, plan the existing deployment's
teardown and preserve the manifest needed for it.

Distinct prefixes do not prevent host-port conflicts or isolate shared host paths,
networks, or sockets. Coordinate those resources separately. The `resources`
command uses substring matching, so verify exact ownership before acting.

## 🔐 Configuration and secrets

- **Edit the sources.** Change chart templates and values, not the generated
  `infrastructure/kube.yaml`.
- **Keep credentials out of Git.** Do not put them in committed values or
  ConfigMaps. Ignore rules cover specific local secret paths and the generated
  manifest—not every possible secret file. Review new paths before committing.
- **Review before sharing.** Generated manifests and logs can contain sensitive
  data.

---

## 📜 License

[MIT](LICENSE).
