# Git Clean Local Branches

Simple bash script to clean up local git branches whose remote counterparts have been deleted. Works on single repositories or entire folders of repositories.

## Quick Start

**Windows:**
```cmd
git-clean-local-branches.bat
```

**Mac/Linux/Git Bash:**
```bash
bash git-clean-local-branches.sh
```

## Features

- 🔍 List local branches without remotes (marked as "gone")
- 📅 Show last commit date and author
- 🏷️ Mark stale branches (customizable threshold, default 30 days)
- ✅ Safe deletion with confirmation prompts
- 🚫 Skip current branch automatically
- 🎨 Color-coded terminal output
- 📁 Multi-repository mode (scan entire folders)
- ⚡ Auto-confirm option for automation
- 🔒 Exclude stale branches from deletion (view only)

## Usage

### Single Repository
```bash
# Clean current repo
bash git-clean-local-branches.sh

# Exclude stale branches from deletion
bash git-clean-local-branches.sh -x

# Custom stale threshold (60 days)
bash git-clean-local-branches.sh -s 60

# Combined: 60-day threshold + exclude stale
bash git-clean-local-branches.sh -s 60 -x
```

### Multiple Repositories
```bash
# Clean all repos in a folder
bash git-clean-local-branches.sh -f ~/projects

# With auto-confirm
bash git-clean-local-branches.sh -f ~/projects -y

# Exclude stale branches across all repos
bash git-clean-local-branches.sh -f ~/projects -x

# Custom threshold for all repos
bash git-clean-local-branches.sh -f ~/projects -s 60 -x
```

### Windows (Easy Mode)
```cmd
REM Windows batch wrapper - auto-finds Git Bash
git-clean-local-branches.bat

REM Multi-repo
git-clean-local-branches.bat -f C:\Users\YourName\projects

REM Exclude stale
git-clean-local-branches.bat -x

REM All options work the same
git-clean-local-branches.bat -f C:\projects -s 90 -x -y
```

## Command-Line Options

| Option | Description |
|--------|-------------|
| `-f, --folder PATH` | Run on all git repositories in specified folder |
| `-y, --yes` | Auto-confirm deletions (use with caution!) |
| `-s, --stale-days DAYS` | Set custom threshold for stale branches (default: 30) |
| `-x, --exclude-stale` | Exclude stale branches from deletion (show only) |
| `-h, --help` | Show help message |

## Common Workflows

### Weekly Cleanup (Recommended)
```bash
# 1. Update all remotes first
cd ~/projects
for dir in */; do
  cd "$dir"
  git fetch --prune 2>/dev/null
  cd ..
done

# 2. Clean all repos, keeping stale branches for review
bash git-clean-local-branches.sh -f . -x
```

### Safe Exploration
```bash
# See what would be deleted (stale branches excluded)
bash git-clean-local-branches.sh -x
# Review the list, then run without -x to actually delete
bash git-clean-local-branches.sh
```

### Aggressive Cleanup
```bash
# 90-day threshold, auto-confirm everything
bash git-clean-local-branches.sh -f ~/projects -s 90 -y
```

### Conservative Cleanup
```bash
# Only show truly old branches, don't delete them
bash git-clean-local-branches.sh -s 180 -x
```

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
ℹ Stale branches are shown for information only (--exclude-stale is set)

Do you want to delete these branches? (y/N): y

✓ Deleted: feature/new-ui
⊗ Skipped (stale): feature/old-task
✓ Deleted: bugfix/quick-fix

Done! Deleted 2 branch(es)
Skipped 1 stale branch(es)
```

## Setup Tips

### Add to PATH (Optional)
```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="$PATH:/path/to/friction-lab/scripts/git-clean-local-branches"

# Then use from anywhere
git-clean-local-branches.sh -f ~/workspaces
```

### Create Alias (Recommended)
```bash
# Add to ~/.bashrc or ~/.zshrc
alias git-clean='bash ~/path/to/git-clean-local-branches.sh'

# Usage
git-clean -f ~/projects -x
```

### Windows PowerShell Alias
```powershell
# Add to $PROFILE
function git-clean { & "C:\path\to\git-clean-local-branches.bat" $args }

# Usage
git-clean -f C:\projects -x
```

## How It Works

1. **Finds branches** - Uses `git for-each-ref` to find branches with `[gone]` tracking status
2. **Calculates age** - Computes days since last commit
3. **Marks stale** - Flags branches older than threshold (default 30 days)
4. **Shows info** - Displays branch name, last commit date, author, and stale status
5. **Confirms deletion** - Asks for confirmation (unless `-y` is used)
6. **Respects exclusions** - Skips stale branches if `-x` is set
7. **Deletes safely** - Uses `git branch -D` to remove branches
8. **Never touches** - Current branch or remote branches

## Important Notes

- ✅ Only deletes **local** branches (remote branches are safe)
- ✅ Always run `git fetch --prune` first for accurate results
- ✅ You can recover deleted branches from reflog if needed: `git reflog`
- ✅ Stale threshold is just a guideline - review before confirming
- ⚠️ The `-y` flag skips ALL confirmations - use carefully!

## Requirements

- Git (any recent version)
- Bash shell (Git Bash on Windows, native on Mac/Linux)
- No external dependencies

## Files

- **git-clean-local-branches.sh** - Main bash script (cross-platform)
- **git-clean-local-branches.bat** - Windows wrapper (auto-finds Git Bash)
- **README.md** - This file

## Why Two Scripts?

This tool consists of **one main bash script** plus **one Windows helper**:

1. **git-clean-local-branches.sh** (Bash)
   - The actual implementation
   - Works on all platforms with bash
   - Contains all the logic

2. **git-clean-local-branches.bat** (Windows Batch)
   - Convenience wrapper for Windows
   - Auto-detects Git Bash installation
   - Passes all arguments to the bash script
   - Makes it easy for Windows users (just double-click!)

**Why not one unified script?**
- Bash is not native to Windows (requires Git Bash/WSL)
- The .bat wrapper makes it "just work" on Windows
- Unix users can ignore the .bat file completely
- Keeps the bash script pure and cross-platform
- Windows users don't need to know where Git Bash is installed

**Could it be one script?** 
- Not really - you need either bash OR batch as entry point
- A single bash script requires Windows users to manually find/run bash
- A single batch script can't run natively on Mac/Linux
- **This two-file approach is KISS** - simple wrapper + simple script

Think of it like this: The bash script is the engine, the batch file is the key for Windows users.

## KISS Principle

✅ Native git commands only  
✅ No dependencies  
✅ Clear, readable code  
✅ Does one thing well  
✅ Simple options, powerful results

