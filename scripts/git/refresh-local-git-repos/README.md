# refresh-local-git-repos.sh

Interactive and CLI-driven Bash utility to manage, synchronize, and batch-clone Git repositories organized by project folders under a base directory (default `~/workspace/projects`).

## Key Features

1. **Interactive Guided Mode:** When launched without arguments, displays a dynamic menu listing all discovered local projects, repo counts, and operational options.
2. **CLI Flags Support:** Specify target projects (`-p ocp-apijo,ocp-penyas`) or all (`-p all`).
3. **Automatic Remote Discovery & Clone:** Option `-c, --clone-new` queries the Bitbucket REST API (`bitbucket.once.es`), compares with local repos, and clones missing repositories automatically.
4. **Safe Git Synchronization:**
   - Validates working tree cleanliness before making any changes.
   - Executes `git fetch --all --prune`.
   - Strictly applies `git pull --ff-only` when the local branch is behind and clean.
5. **Robust Failure & Lockout Handling:**
   - **Early CAPTCHA Detection:** If Bitbucket requires CAPTCHA resolution, the script alerts immediately and halts subsequent requests to prevent prolonged account lockouts.
   - **Root Directory Protection:** Ignores corrupt or empty `.git` entries in base project roots.
   - **Work-in-Progress Protection (BLOCKED):** Never overwrites uncommitted local modifications, detached HEADs, or diverged branches (`git stash` / manual intervention suggested).

---

## Options & Arguments

```text
Usage: refresh-local-git-repos.sh [options]

Options:
  -p, --proyectos <p1,p2|all>   Target projects to refresh (e.g. ocp-apijo, ocp-penyas or all)
  -c, --clone-new               Detect and automatically clone new remote repos from Bitbucket
  -s, --servicio <filter>       Filter microservices inside projects by name pattern
  -n, --dry-run                 Dry-run mode: inspect local and upstream state without changes
  -d, --dir <directory>         Base directory of projects (default: ~/workspace/projects)
  -h, --help                    Show help
```

---

## Usage Examples

### 1. Interactive Mode (Recommended)
```bash
./refresh-local-git-repos.sh
```

### 2. Refresh a Single Project
```bash
./refresh-local-git-repos.sh -p ocp-apijo
```

### 3. Refresh Multiple Projects and Clone Missing Repositories
```bash
./refresh-local-git-repos.sh -p ocp-apijo,ocp-penyas -c
```

### 4. Dry-run Mode Across All Projects
```bash
./refresh-local-git-repos.sh -p all -n
```

### 5. Filter by Microservice Name Across All Projects
```bash
./refresh-local-git-repos.sh -p all -s user-service
```

---

## Status Definitions

* `UPDATED`: Repository fast-forwarded via `pull --ff-only`.
* `UP-TO-DATE`: Already in sync with upstream.
* `WOULD-UPDATE`: (Dry-run mode) Behind upstream and safe to update.
* `CLONED`: Newly discovered remote repository cloned from Bitbucket.
* `BLOCKED`: Requires manual action (uncommitted changes, detached HEAD, divergence).
* `ERROR`: Network failure, authentication error, or git command failure.
