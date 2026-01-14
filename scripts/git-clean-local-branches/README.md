# Git Clean Local Branches

Clean up local git branches whose remote counterparts have been deleted.

## Quick Start

```bash
# Single repo (interactive)
bash git-clean-local-branches.sh

# Single repo, dry-run (show what would be deleted)
bash git-clean-local-branches.sh --dry-run

# Multiple repos (one level deep)
bash git-clean-local-branches.sh -f ~/projects

# Multiple repos, recursive discovery
bash git-clean-local-branches.sh -f ~/projects -r

# Windows (double-click or run)
git-clean-local-branches.bat
```

## Options

| Option | Description |
|--------|-------------|
| `-f PATH` | Run on all repos in folder (one level deep unless `-r` used) |
| `-r` / `--recursive` | Search recursively under `PATH` for git repositories |
| `-y` | Auto-confirm prompts (use carefully) |
| `-s DAYS` | Stale threshold in days (default: 30) |
| `-x` | Exclude stale branches from deletion (show only) |
| `-l [FILE]` | Enable logging. If FILE provided, write there; otherwise write to workspace `git-clean-local-branches.log` |
| `-n` / `--dry-run` | Show what would be deleted; do not perform any deletions |
| `-F` / `--force-delete` | In non-interactive mode, force-delete branches that are not merged (uses `git branch -D`) |
| `-h` | Show help |

## Common Usage

```bash
# Preview what would be deleted (safe)
bash git-clean-local-branches.sh -n

# Clean with custom stale threshold
bash git-clean-local-branches.sh -s 60

# Multi-repo with logging to a specific file
bash git-clean-local-branches.sh -f ~/projects -l cleanup.log

# Enable logging to default workspace log file
bash git-clean-local-branches.sh -l

# Automated cleanup (CI/CD) — auto-confirm but do NOT force unless -F is set
bash git-clean-local-branches.sh -f ~/projects -y -s 90 -l cleanup.log

# Dry-run across multiple repos recursively
bash git-clean-local-branches.sh -f ~/projects -r -n
```

## How It Works

1. **Find candidates**: Scans for local branches whose upstream tracking shows `[gone]` (remote deleted).
2. **Show info**: Displays branch name, last commit date (ISO 8601 format), and author.
3. **Mark stale**: Flags branches older than threshold (default 30 days) as `[STALE]`.
4. **Safe delete first**: Tries `git branch -d` (safe delete) which only works on merged branches.
5. **Force delete handling**:
   - **Interactive mode**: If safe delete fails, asks per-branch whether to force-delete.
   - **Auto mode** (`-y`): Skips unmerged branches unless `-F` is also set.
   - **Force mode** (`-F`): Uses `git branch -D` for unmerged branches (use carefully).
6. **Dry-run** (`-n`): Shows what would be deleted without performing any deletions.
7. **Logging** (`-l`): Optional; writes timestamped, color-free log entries.

## Example Output

```
=== Git Clean Local Branches ===

Looking for local branches without remote counterparts...

Found branches with deleted remotes:

BRANCH                         LAST COMMIT (ISO)         AUTHOR
--------------------------------------------------------------------------------
feature/new-ui                 2025-11-07T14:22:03+00:00 Jane Smith
feature/old-task               2025-09-01T11:05:22+00:00 John Doe             [STALE]
bugfix/quick-fix               2025-11-01T09:15:00+00:00 Alex Johnson

Total: 3 branch(es)
Stale branches (will be excluded from deletion): 1

Do you want to delete these branches? (y/N): y

✓ Deleted (safe): feature/new-ui
⊗ Skipped (stale): feature/old-task
✓ Deleted (safe): bugfix/quick-fix

✓ Done! Deleted 2 branch(es)
  Skipped 1 branch(es)
```

## Logging

- Logging is off by default. Use `-l` to enable logging.
- `-l` with no file writes to the workspace default: `git-clean-local-branches.log` (script workspace root).
- `-l <file>` writes to the provided file; the script will create parent directories when possible.

Example:
```bash
# Default workspace log
bash git-clean-local-branches.sh -l

# Custom logfile
bash git-clean-local-branches.sh -f ~/projects -l cleanup-$(date +%Y%m%d).log
```

## Tips

1. Run `git fetch --prune` first to sync remote status.
2. Use `-n` (dry-run) to preview changes without risk.
3. `-y` auto-confirms prompts; it does not automatically force-delete unmerged branches unless you also pass `-F`.
4. Recover deleted branches via `git reflog` if needed.

## Setup

**Add to PATH:**
```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="$PATH:/path/to/scripts/git-clean-local-branches"
```

**Create alias:**
```bash
# Add to ~/.bashrc or ~/.zshrc
alias git-clean='bash ~/path/to/git-clean-local-branches.sh'
```

**Windows PowerShell:**
```powershell
# Add to $PROFILE
function git-clean { & "C:\path\to\git-clean-local-branches.bat" $args }
```

## Files

- **git-clean-local-branches.sh** - Main bash script (cross-platform)
- **git-clean-local-branches.bat** - Windows wrapper (auto-finds Git Bash)

## Requirements

- Git (recent version)
- Bash shell (Git Bash on Windows, native on Mac/Linux)

## Safety

✅ Only deletes local branches (remotes are safe)  
✅ Skips current branch automatically  
✅ Dry-run mode (`-n`) guarantees no deletions  
✅ Confirmation prompt (unless `-y` used)  
✅ Logging is optional and safe  

## KISS

Keep it simple: native git commands only, no external deps, clear output.

---

**Pro tip:** Run `git fetch --prune` first, then use this script to clean up stale local branches.
