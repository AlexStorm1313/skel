.PHONY: kube play down workspace resources validate

SHELL := /bin/bash

NAMESPACE=envskel-123
USERNS=--userns=keep-id:uid=1001,gid=0
IMAGE_PULL_POLICY?=IfNotPresent

# Generate deployment from Helm Chart
kube:
	@printf '☸️  Rendering Kubernetes manifest for namespace: %s\n' '$(NAMESPACE)'; \
	printf '📥 Image pull policy: %s\n' '$(IMAGE_PULL_POLICY)'; \
	podman run \
		-i \
		--rm \
		-v ./infrastructure:/infrastructure:Z \
		-w /infrastructure \
		--entrypoint sh \
		docker.io/alpine/helm:latest \
		-c 'helm template $(NAMESPACE) \
			--dry-run=client \
			--values ./values.yaml \
			--set-string deployments.containers.pullPolicy=$(IMAGE_PULL_POLICY) \
			. > ./kube.yaml.tmp && mv ./kube.yaml.tmp ./kube.yaml' && \
	printf '✅ Kubernetes manifest generated: infrastructure/kube.yaml\n'

# Lint and schema-check a fresh render without changing the deployed manifest
validate:
	@printf '🔎 Validating chart for namespace: %s\n' '$(NAMESPACE)'; \
	printf '📥 Image pull policy: %s\n' '$(IMAGE_PULL_POLICY)'; \
	case '$(IMAGE_PULL_POLICY)' in \
		Always|IfNotPresent|Never) ;; \
		*) printf '❌ Invalid image pull policy\n' >&2; exit 1 ;; \
	esac; \
	git diff --check && \
	manifest=$$(podman run \
		--rm \
		-v ./infrastructure:/infrastructure:ro,Z \
		-w /infrastructure \
		--entrypoint sh \
		docker.io/alpine/helm:latest \
		-c 'helm lint . \
			--values ./values.yaml \
			--set-string deployments.containers.pullPolicy=$(IMAGE_PULL_POLICY) >&2 && \
			helm template $(NAMESPACE) \
				--dry-run=client \
				--values ./values.yaml \
				--set-string deployments.containers.pullPolicy=$(IMAGE_PULL_POLICY) .') && \
	printf '📋 Checking rendered resource schemas\n' && \
	printf '%s\n' "$$manifest" | podman run \
		-i \
		--rm \
		ghcr.io/yannh/kubeconform:latest \
		-strict \
		-summary && \
	printf '✅ Validation passed (not a Podman compatibility or readiness check)\n'

# Run the deployment with Podman
play: down
	@printf '🚀 Starting workspace in namespace: %s\n' '$(NAMESPACE)'; \
	podman kube play $(USERNS) ./infrastructure/kube.yaml && \
	printf '📋 Pods in namespace: %s\n' '$(NAMESPACE)' && \
	podman pod ls | grep $(NAMESPACE) && \
	printf '✅ Workspace started from infrastructure/kube.yaml\n'

# Stop the deployment with Podman
down:
	@printf '🛑 Stopping workspace from manifest: %s\n' 'infrastructure/kube.yaml'; \
	podman kube down --force ./infrastructure/kube.yaml && \
	printf '✅ Workspace stopped\n'

# Stop existing pods, render the chart, and start the workspace with Podman
workspace: down kube play
	@printf '✅ Workspace is ready in namespace: %s\n' '$(NAMESPACE)'

resources:
	@printf '📦 Resources in namespace: %s\n' '$(NAMESPACE)'; \
	for resource in pod volume network; do \
		case "$$resource" in pod) label='📦 Pods' ;; volume) label='💾 Volumes' ;; network) label='🌐 Networks' ;; esac; \
		printf '\n%s\n' "$$label"; \
		listing=$$(podman "$$resource" ls) || exit $$?; \
		matches=$$(printf '%s\n' "$$listing" | grep -F -- "$(NAMESPACE)"); \
		status=$$?; \
		if [ $$status -eq 0 ]; then \
			printf '%s\n' "$$listing" | sed -n '1p'; \
			printf '%s\n' "$$matches"; \
		elif [ $$status -eq 1 ]; then \
			printf '(none)\n'; \
		else exit $$status; fi; \
	done
