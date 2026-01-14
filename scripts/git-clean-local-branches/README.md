# Git Clean Local Branches

Clean up local git branches whose remote counterparts have been deleted.

## Quick Start

```bash
# Single repo
bash git-clean-local-branches.sh

# Multiple repos
bash git-clean-local-branches.sh -f ~/projects

# Windows (double-click or run)
git-clean-local-branches.bat
```

## Options

| Option | Description |
|--------|-------------|
| `-f PATH` | Run on all repos in folder |
| `-y` | Auto-confirm (no prompts) |
| `-s DAYS` | Stale threshold (default: 30) |
| `-x` | Exclude stale from deletion |
| `-l FILE` | Log to file with timestamps |
| `-h` | Show help |

## Common Usage

```bash
# Preview what would be deleted (safe)
bash git-clean-local-branches.sh -x

# Clean with custom stale threshold
bash git-clean-local-branches.sh -s 60

# Multi-repo with logging
bash git-clean-local-branches.sh -f ~/projects -l cleanup.log

# Automated cleanup (CI/CD)
bash git-clean-local-branches.sh -f ~/projects -y -s 90 -l cleanup.log

# Windows
git-clean-local-branches.bat -f C:\projects -x
```

## How It Works

1. Finds local branches marked as `[gone]` (remote deleted)
2. Shows branch name, last commit date, and author
3. Marks branches older than threshold as `[STALE]`
4. Confirms before deletion (unless `-y` flag)
5. Optionally excludes stale branches from deletion (`-x` flag)
6. Logs all operations to file if `-l` specified

## Example Output

```
=== Git Clean Local Branches ===

Looking for local branches without remote counterparts...

Found branches with deleted remotes:

BRANCH                         LAST COMMIT          AUTHOR
--------------------------------------------------------------------------------
feature/new-ui                 2 days ago           Jane Smith
feature/old-task               3 weeks ago          John Doe             [STALE]
bugfix/quick-fix               1 week ago           Alex Johnson

Total: 3 branch(es)
Stale branches (will be excluded from deletion): 1

Do you want to delete these branches? (y/N): y

✓ Deleted: feature/new-ui
⊗ Skipped (stale): feature/old-task
✓ Deleted: bugfix/quick-fix

✓ Done! Deleted 2 branch(es)
  Skipped 1 stale branch(es)
```

## Logging

Log files include timestamps and no color codes for easy parsing:

```
[2026-01-13 14:30:00] ✓ Deleted: feature/old-branch
[2026-01-13 14:30:01] ⊗ Skipped (stale): feature/ancient
[2026-01-13 14:30:02] ✓ Done! Deleted 5 branch(es)
```

Use date-based log files for rotation:
```bash
bash git-clean-local-branches.sh -f ~/projects -l cleanup-$(date +%Y%m%d).log
```

## Tips

1. **Always run first:** `git fetch --prune` to sync remote status
2. **Test safely:** Use `-x` flag to preview without deletion
3. **Recover if needed:** Deleted branches can be recovered from reflog: `git reflog`
4. **Combine flags:** `-s 60 -x -l cleanup.log` for powerful workflows
5. **Windows users:** The `.bat` file auto-finds Git Bash

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

# Then use anywhere
git-clean -f ~/projects -x
```

**Windows PowerShell:**
```powershell
# Add to $PROFILE
function git-clean { & "C:\path\to\git-clean-local-branches.bat" $args }
```

## Files

- **git-clean-local-branches.sh** - Main bash script (cross-platform)
- **git-clean-local-branches.bat** - Windows wrapper (auto-finds Git Bash)

The `.bat` wrapper makes it "just work" on Windows by auto-detecting Git Bash installation. Unix users can ignore it.

## Requirements

- Git (any recent version)
- Bash shell (Git Bash on Windows, native on Mac/Linux)
- No external dependencies

## Safety

✅ Only deletes **local** branches (remotes are safe)  
✅ Skips current branch automatically  
✅ Confirmation prompt (unless `-y` used)  
✅ Recoverable from reflog if needed  
⚠️ Use `-y` flag carefully in automation

## KISS Principle

✅ Native git commands only  
✅ No dependencies  
✅ Clear, readable code  
✅ Does one thing well

---

**Pro tip:** Run `git fetch --prune` first, then use this script to clean up stale local branches.
