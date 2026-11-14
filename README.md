# DevOps Things

Centralized repository containing operational automation scripts, utilities, Kubernetes templates, and developer workstation configurations.

## 📁 Repository Structure

```text
devops-things/
├── kubernetes/
│   └── templates/                # Declarative Kubernetes manifests and templates
│       ├── configMaps/           # ConfigMap templates (e.g. backup scripts)
│       ├── cronjobs/             # CronJob templates (e.g. database backup jobs)
│       └── pods/                 # Utility pods for administration (e.g. AWS CLI)
├── workstations/                 # Reusable developer workstation configurations
│   └── wsl-terminal-config/      # WSL + Windows Terminal visual setup
└── scripts/                      # Collection of operational automation scripts
    ├── git/                      # Git and SCM automation tools
    │   ├── clone-bitbucket-repo/ # Interactive batch cloning by Bitbucket project
    │   └── refresh-local-git-repos/ # Interactive repo sync and remote discovery
    └── kubernetes/               # Operational utilities for Kubernetes
        ├── admin/                # Administration scripts (e.g. secret replication)
        ├── audit/                # Resource auditing (HPA autoscaling, Kafka/OCI)
        └── monitoring/           # Real-time resource usage and pod latency monitoring
```

## 🛠️ Components

### Workstation Configurations
- **[wsl-terminal-config](workstations/wsl-terminal-config/):** Minimal WSL + Windows Terminal styling with Catppuccin Mocha, a Nerd Font, and a Git-only Starship prompt.

### Git & SCM Scripts
- **[clone-bitbucket-repo](scripts/git/clone-bitbucket-repo/):** Interactive script to clone all repositories within a Bitbucket project.
- **[refresh-local-git-repos](scripts/git/refresh-local-git-repos/):** Interactive and CLI-driven utility to refresh local repositories with `fetch`/`pull --ff-only` and discover/clone new remote repos.

### Kubernetes Scripts
- **[admin/copy-secrets](scripts/kubernetes/admin/):** Securely copy Kubernetes secrets across different namespaces.
- **[audit/audit-autoscaling](scripts/kubernetes/audit/audit-autoscaling/):** Audit HPAs and verify compliance with the corporate 80% autoscaling target ratio.
- **[audit/kafka-auditor](scripts/kubernetes/audit/kafka-auditor/):** Scan deployments, configmaps, and secrets for Kafka and OCI references.
- **[monitoring/monitor-pod-resources](scripts/kubernetes/monitoring/monitor-pod-resources/):** Real-time CLI dashboard for CPU and memory usage of pods and underlying nodes.
- **[monitoring/pods-health](scripts/kubernetes/monitoring/pods-health/):** Measure readiness/liveness endpoint latencies and simulate failure scenarios.

## 🔗 Symbolic Links & Execution Standards

To facilitate CLI execution while maintaining clean, idiomatic naming without `.sh` extensions, utilities in this repository use symbolic links following these standards:

### 1. In-Repository Relative Symlinks (Tracked in Git)
* **Relative target:** Each utility directory includes a local relative symlink without the `.sh` extension pointing directly to its executable file (e.g. `clone-bitbucket-repo -> clone-bitbucket-repo.sh`).
* **Versioned in Git:** Git handles symlinks natively using file mode `120000`. Git stores only the target string (a lightweight pointer of ~20 bytes), NOT duplicated file content.
* **Do NOT add to `.gitignore`:** These symlinks are part of the repository tool interface and must be tracked in Git. This ensures that any user or environment (Linux, WSL, macOS, CI/CD runners, container images) that clones the repository has immediate access to both invocation styles (`./script` or `./script.sh`).
* **Windows Compatibility:** When working on native Windows without WSL, ensure `core.symlinks = true` is enabled in Git (`git config --global core.symlinks true`) with Developer Mode enabled, or execute scripts inside WSL/Ubuntu.

### 2. Global User Symlinks (`~/.local/bin`)
* For system-wide execution from any working directory, symlinks can be created inside `$HOME/.local/bin/` (or any folder in `$PATH`):
  ```bash
  ln -s "/path/to/devops-things/scripts/git/clone-bitbucket-repo/clone-bitbucket-repo.sh" ~/.local/bin/clone-bitbucket-repo
  ```
* These symlinks reside outside the repository in the user's home directory and are never tracked in Git.
