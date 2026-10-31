FROM quay.io/fedora/fedora:latest

ARG USER=core
ARG UID=1001
ARG GID=0
ARG HOME=/home/${USER}

LABEL name="AlexStorm1313/core" \
    vendor="AlexStorm1313" \
    version="0.0.1" \
    release="1" \
    summary="Container image used as a base layer" \
    description="Container image used as a base layer"

# Set ENV variables
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV HOME=${HOME}
ENV SHELL=/bin/bash
ENV PATH=${HOME}/.cargo/bin:${HOME}/.bun/bin:${HOME}/.local/bin:${PATH}
ENV HERMES_RUNTIME_DIR=/opt/hermes/tools

RUN groupadd -g ${UID} ${USER} && \
    useradd -u ${UID} -g ${UID} -m -s $SHELL ${USER}

RUN curl -fsSL https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm -o session-manager-plugin.rpm && \
    dnf install -y ./session-manager-plugin.rpm && \
    rm -f ./session-manager-plugin.rpm && \
    # Register all repos first
    curl -fsSL https://rpm.releases.hashicorp.com/fedora/hashicorp.repo -o /etc/yum.repos.d/hashicorp.repo && \
    printf '%s\n' \
    '[gitlab.com_paulcarroty_vscodium_repo]' \
    'name=gitlab.com_paulcarroty_vscodium_repo' \
    'baseurl=https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/rpms/' \
    'enabled=1' \
    'gpgcheck=1' \
    'repo_gpgcheck=1' \
    'gpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg' \
    'metadata_expire=1h' \
    > /etc/yum.repos.d/vscodium.repo && \
    dnf -y install dnf-plugins-core \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" && \
    # Update with all repos active
    dnf -y update && \
    # Enable COPR (requires dnf-plugins-core)
    dnf -y copr enable atim/starship && \
    # Install all packages
    dnf -y install \
    awk \
    awscli2 \
    azure-cli \
    bash-completion \
    codium \
    composer \
    fira-code-fonts \
    gcc \
    git \
    hostname \
    libpq-devel \
    nodejs \
    npm \
    oci-cli \
    openssh-server \
    opentofu \
    php \
    podman \
    procps \
    rsync \
    rustup \
    starship \
    terraform-ls \
    tini \
    unzip \
    uv \
    which && \
    # Install Rust and Cargo tools
    rustup-init -y --profile=default --default-toolchain=nightly && \
    cargo install --locked watchexec-cli && \
    cargo install --locked bacon && \
    cargo install --locked diesel_cli --no-default-features --features "postgres" && \
    cargo install --locked cargo-lambda && \
    # Install Bun
    curl -fsSL https://bun.sh/install | sh && \
    bun install -g --trust @opencode/cli && \
    # Install Hermes agent
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --dir /opt/hermes && \
    # Cleanup
    dnf -y clean all && \
    rm -rf /var/cache/dnf && \
    rm -rf ${HOME}/.cargo/registry ${HOME}/.cargo/git

# Install extensions
RUN codium --user-data-dir ${HOME}/.vscodium-server/data --extensions-dir ${HOME}/.vscodium-server/extensions --force \
    --install-extension rust-lang.rust-analyzer \
    --install-extension bradlc.vscode-tailwindcss \
    --install-extension tamasfe.even-better-toml \
    --install-extension redhat.vscode-yaml \
    --install-extension fill-labs.dependi \
    --install-extension ms-toolsai.jupyter \
    --install-extension ms-azuretools.vscode-docker \
    --install-extension ms-kubernetes-tools.vscode-kubernetes-tools \
    --install-extension usernamehw.errorlens \
    --install-extension HashiCorp.terraform

# SHELL setup
RUN echo 'alias opencode="bunx --bun opencode"' >> ${HOME}/.bashrc
RUN echo 'eval "$(starship init bash)"' >> ${HOME}/.bashrc

# Changing ownership and user rights to support following use-cases:
# 1) running container on OpenShift, whose default security model
#    is to run the container under random UID, but GID=0
# 2) for working root-less container with UID=1001, which does not have
#    to have GID=0
# 3) for default use-case, that is running container directly on operating system,
#    with default UID and GID (1001:0)
# Supported combinations of UID:GID are thus following:
# UID=1001 && GID=0
# UID=<any>&& GID=0
# UID=1001 && GID=<any>
# Hermes locks and rebuilds the web UI in its checkout, even with a separate HERMES_HOME.
RUN chown -R ${UID}:${GID} ${HOME} /opt/hermes && \
    chmod -R g=u ${HOME} /opt/hermes

# Set fixed non-root user for compatibility with Podman/Docker and Kubernetes
USER ${UID}
WORKDIR ${HOME}
