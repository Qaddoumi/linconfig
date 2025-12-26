# Git Branch Management

To see all available branches in your terminal, you can use the following `git` commands:

## 1. List Branches

*   **Local branches only:**
    ```bash
    git branch
    ```
*   **Remote branches only:**
    ```bash
    git branch -r
    ```
*   **All branches (local and remote):**
    ```bash
    git branch -a
    ```

---

## 2. Removing Branches

Once you've identified the branches you want to get rid of, use these commands:

*   **Delete a local branch:**
    ```bash
    git branch -d <branch-name>
    ```
    > **Note:** Use `-D` instead of `-d` if you want to force delete it without checking if it's been merged.

*   **Delete a remote branch:**
    ```bash
    git push origin --delete <branch-name>
    ```

*   **Clean up local "ghost" branches:**
    *(Branches that were deleted on the remote but still show up in your local `git branch -a`)*
    ```bash
    git fetch --prune
    ```
