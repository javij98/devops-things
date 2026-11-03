# Clone Bitbucket Repository Script

Bash script (`clone-bitbucket-repo.sh`) to automatically batch-clone all repositories of a project hosted on Bitbucket Server (`bitbucket.once.es`).

## 📋 Description

This script automates cloning multiple repositories belonging to a Bitbucket project. Key features include:

* **Interactive:** Safely prompts for username, masked password, and project key.
* **Safe:** Validates that the current working directory matches the target project name to prevent cloning in unintended paths.
* **Resilient:** Detects already cloned repositories and skips them, preventing unintentional overwrites.

## 🛠️ Prerequisites

- `git`
- `curl`
- `jq`

```bash
# Debian / Ubuntu installation
sudo apt-get install git curl jq
```

## 🚀 Usage

1. **Run the script:**

   ```bash
   # Using the relative symlink:
   ./clone-bitbucket-repo

   # Or using the script directly:
   ./clone-bitbucket-repo.sh
   ```

2. **Follow on-screen prompts:**
   - **User:** Your Bitbucket username.
   - **Password:** Your Bitbucket password / token.
   - **Project:** The project key in Bitbucket (e.g. `OCP-INFORMES`).

3. **Directory Safety Validation:**
   If the current working directory does not match the project name, the script prompts for confirmation before proceeding.

## ⚠️ Error Handling

- **HTTP 401:** Invalid credentials.
- **HTTP 404:** Project not found.
- **HTTP 403:** Insufficient permissions to view the project.
- **Existing directories:** Skips existing Git repositories and warns about non-git folders.
