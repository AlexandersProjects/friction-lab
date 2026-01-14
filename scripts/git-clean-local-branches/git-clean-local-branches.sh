#!/bin/bash

# Git Clean Local Branches
# Finds and removes local branches that no longer have remote counterparts

# Safety: fail fast on errors, undefined variables, and failed pipes. Use a safe IFS.
set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Determine script and workspace locations (workspace is two levels up from script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." >/dev/null 2>&1 && pwd)"

# Configuration
STALE_DAYS=30
MULTI_REPO_MODE=false
TARGET_FOLDER=""
AUTO_YES=false
EXCLUDE_STALE=false
LOG_FILE="${WORKSPACE_ROOT}/git-clean-local-branches.log"
LOG_ENABLED=false
FORCE_DELETE=false
RECURSIVE=false
DRY_RUN=false

# Helper: convert Windows drive-style paths to POSIX (/c/...) for Git Bash / find
convert_to_posix_path() {
  local p="$1"
  # If begins with A:\ or A:/ or a:\
  if [[ "$p" =~ ^[A-Za-z]:[\\/].* ]]; then
    if command -v cygpath >/dev/null 2>&1; then
      p="$(cygpath -u "$p")"
    else
      # Fallback: C:/Users -> /c/Users ; normalize backslashes to slashes
      local drive="${p:0:1}"
      local rest="${p:2}"
      rest="${rest//\\//}"
      p="/${drive,,}/${rest#/}"
    fi
  fi
  printf '%s' "$p"
}

# Logging function: writes to stdout and optionally to a log file (without colors)
log() {
    local message="$1"

    # Print to terminal with colors (use printf to respect formatting)
    printf '%b\n' "$message"

    # Flush output to ensure it appears immediately
    sync 2>/dev/null || true

    # Write to log file without colors (if enabled)
    if [ "${LOG_ENABLED}" = true ]; then
        local timestamp
        timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
        # strip ANSI color sequences before writing
        local clean_message
        clean_message=$(printf '%b' "$message" | sed 's/\x1b\[[0-9;]*m//g')
        printf '[%s] %s\n' "$timestamp" "$clean_message" >> "$LOG_FILE"
    fi
}


# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--folder)
            # Validate presence of the folder argument
            if [ -z "${2:-}" ] || [[ "${2:-}" == -* ]]; then
                printf '%s\n' "${RED}Error: --folder requires a PATH argument${NC}"
                exit 1
            fi
            MULTI_REPO_MODE=true
            TARGET_FOLDER_RAW="$2"
            # Convert Windows-style path to POSIX for Git Bash tools (find, etc.)
            TARGET_FOLDER="$(convert_to_posix_path "$TARGET_FOLDER_RAW")"
            shift 2
            ;;
        -y|--yes)
            AUTO_YES=true
            shift
            ;;
        -s|--stale-days)
            if ! [[ "${2:-}" =~ ^[0-9]+$ ]] || [ "$2" -le 0 ]; then
                printf '%b\n' "${RED}Error: --stale-days must be a positive number (got: '$2')${NC}"
                exit 1
            fi
            STALE_DAYS="$2"
            shift 2
            ;;
        -x|--exclude-stale)
            EXCLUDE_STALE=true
            shift
            ;;
        -l|--log)
            # Enable logging. If an argument is supplied and doesn't start with '-', use it as filename;
            # otherwise enable logging to default LOG_FILE.
            if [ -n "${2:-}" ] && [[ "$2" != -* ]]; then
                LOG_FILE="$2"
                LOG_ENABLED=true
                shift 2
            else
                LOG_ENABLED=true
                shift
            fi
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -F|--force-delete)
            FORCE_DELETE=true
            shift
            ;;
        -r|--recursive)
            RECURSIVE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -f, --folder PATH       Run on all git repositories in the specified folder"
            echo "  -r, --recursive         Search for git repositories recursively under PATH"
            echo "  -y, --yes               Auto-confirm deletions (use with caution!)"
            echo "  -s, --stale-days DAYS   Set custom threshold for marking stale branches (default: 30)"
            echo "  -x, --exclude-stale     Exclude stale branches from deletion (show only)"
            echo "  -l, --log [FILE]       Write log output to specified file (optional; default used when no FILE)"
            echo "  -n, --dry-run          Show what would be deleted without deleting (safe preview)"
            echo "  -F, --force-delete      Force delete branches (-D) when necessary (use with caution)"
            echo "  -h, --help              Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                              # Clean current repository"
            echo "  $0 -n                           # Dry-run: show what would be deleted"
            echo "  $0 -l                           # Clean and log to workspace/git-clean-local-branches.log"
            echo "  $0 -f ~/projects                # Clean all repos in ~/projects"
            echo "  $0 -f ~/projects -r -n          # Dry-run on all repos recursively"
            echo "  $0 -f ~/projects -y -F          # Auto-confirm and force-delete unmerged"
            echo "  $0 -s 60 -x                     # Show branches >60 days old but don't delete"
            echo "  $0 -l cleanup.log               # Clean and log to cleanup.log"
            exit 0
            ;;
        *)
            log "${RED}Unknown option: $1${NC}"
            log "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

if [ "${MULTI_REPO_MODE}" = true ]; then
    # Show resolved path so Windows users can see the conversion
    log "Resolved target folder: ${CYAN}${TARGET_FOLDER}${NC}"
    if [ ! -d "$TARGET_FOLDER" ]; then
        log "${RED}Error: Folder does not exist: $TARGET_FOLDER${NC}"
        exit 1
    fi
fi

# Initialize logging: ensure parent dir exists and file is writable (or create it)
if [ "${LOG_ENABLED}" = true ]; then
    # Create parent directory if needed
    LOG_DIR="$(dirname "$LOG_FILE")"
    if [ -n "$LOG_DIR" ] && [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR" || {
            printf '%b\n' "${RED}Error: Could not create log directory: $LOG_DIR${NC}"
            exit 1
        }
    fi

    # Ensure we can create or append to the log file
    if ! touch "$LOG_FILE" 2>/dev/null; then
        printf '%b\n' "${RED}Error: Cannot create or write to log file: $LOG_FILE${NC}"
        exit 1
    fi

    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    printf '[%s] ==== Git Clean Local Branches Log Started ====\n' "$timestamp" >> "$LOG_FILE"
fi

# Function to clean branches in a single repository
clean_repository() {
#    echo "[DEBUG] >>> FUNCTION ENTERED - USING ECHO <<<" >&2
#    printf '[DEBUG] >>> FUNCTION ENTERED - USING PRINTF <<<\n' >&2
#
#    log "${MAGENTA}[DEBUG] >>> FUNCTION ENTERED <<<${NC}"

    local repo_path="$1"
    local repo_name
    local original_dir

#    log "${CYAN}[DEBUG] Variables declared${NC}"

    # These assignments use || to provide defaults if commands fail
    repo_name="$(basename "$repo_path" 2>/dev/null || echo "unknown")"
#    log "${CYAN}[DEBUG] repo_name assigned: $repo_name${NC}"

    original_dir="$(pwd 2>/dev/null || echo "/tmp")"
#    log "${CYAN}[DEBUG] original_dir assigned: $original_dir${NC}"

#    log "${CYAN}[DEBUG] Entering clean_repository for: $repo_path${NC}"
#    log "${CYAN}[DEBUG] Repository name: $repo_name${NC}"
#    log "${CYAN}[DEBUG] Original directory: $original_dir${NC}"

    cd "$repo_path" || {
        log "${RED}Error: Cannot access directory: $repo_path${NC}"
        return 1
    }

#    log "${CYAN}[DEBUG] Changed to directory successfully${NC}"

    # Check if we're in a git repository
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        log "${RED}Error: Not a git repository: $repo_path${NC}"
        cd "$original_dir"
        return 1
    fi

#    log "${CYAN}[DEBUG] Verified git repository${NC}"

    # Get current branch to avoid deleting it; detect detached HEAD
    CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || echo "")"
#    log "${CYAN}[DEBUG] Current branch: '$CURRENT_BRANCH'${NC}"

    if [ -z "$CURRENT_BRANCH" ]; then
        DETACHED_HEAD=true
        HEAD_COMMIT="$(git rev-parse --verify HEAD 2>/dev/null || echo "")"
    else
        DETACHED_HEAD=false
        HEAD_COMMIT=""
    fi

#    log "${CYAN}[DEBUG] Detached HEAD: $DETACHED_HEAD${NC}"

    if [ "$MULTI_REPO_MODE" = true ]; then
        log ""
        log "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        log "${MAGENTA}Repository: $repo_name${NC}"
        log "${CYAN}Path: $repo_path${NC}"
        log "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    else
        log "${BLUE}=== Git Clean Local Branches ===${NC}"
        log ""
    fi

    log "Looking for local branches without remote counterparts..."
    log ""

    # If dry-run is enabled, we'll determine merged status to report whether a branch would be deleted safely
    is_branch_merged() {
        local branch_ref="$1"
        # Return 0 if branch tip is an ancestor of HEAD (i.e., merged into HEAD)
        # Use || true to prevent errexit from stopping execution
        local commit_sha
        commit_sha=$(git rev-parse --verify "$branch_ref" 2>/dev/null || echo "")
        if [ -z "$commit_sha" ]; then
            return 1
        fi
        git merge-base --is-ancestor "$commit_sha" HEAD >/dev/null 2>&1 || return 1
        return 0
    }

    # Initialize arrays to store branch information
    declare -a BRANCH_NAMES=()
    declare -a BRANCH_DATES=()
    declare -a STALE_BRANCHES=()

    # Use NUL-separated output to safely handle branch names with unusual characters
    # Fields: branch_name, upstream_track (contains '[gone]' when remote is deleted), committerdate ISO8601, authorname
    # Use git's -z output to get NUL-separated records directly (don't store in a variable)
    # The for-each-ref will emit records terminated by NUL when -z is used.
    git_cmd_output_exists=true
    if ! git for-each-ref -z --format='%(refname:short)%00%(upstream:track)%00%(committerdate:iso8601)%00%(authorname)%00' refs/heads/ >/dev/null 2>&1; then
        git_cmd_output_exists=false
    fi

    if [ "$git_cmd_output_exists" = false ]; then
        log "${GREEN}✓ No branches found with deleted remotes${NC}"
        log ""
        if [ "$MULTI_REPO_MODE" = false ]; then
            log "All your local branches have corresponding remotes or are local-only branches."
        fi
        cd "$original_dir"
        return 0
    fi

    log "${YELLOW}Found branches with deleted remotes:${NC}"
    log ""
    log "$(printf "%-30s %-25s %-25s" "BRANCH" "LAST COMMIT (ISO)" "AUTHOR")"
    log "--------------------------------------------------------------------------------"

    # Read records safely (NUL-terminated). We pass git's -z output directly to the loop.
    while IFS= read -r -d '' record; do
        # split the NUL-separated fields in record
        IFS=$'\00' read -r branch tracking date author <<< "$record" || true

        # Only consider branches whose upstream tracking indicates gone
        if [[ -z "$tracking" ]] || [[ "$tracking" != *"[gone]"* ]]; then
            continue
        fi

        # Skip current branch - don't show or count it
        if [ -n "$CURRENT_BRANCH" ] && [ "$branch" = "$CURRENT_BRANCH" ]; then
            continue
        fi

        # If HEAD is detached, protect branches pointing to HEAD - don't show or count them
        if [ "$DETACHED_HEAD" = true ] && [ -n "$HEAD_COMMIT" ]; then
            branch_commit="$(git rev-parse --verify "refs/heads/$branch" 2>/dev/null || true)"
            if [ -n "$branch_commit" ] && [ "$branch_commit" = "$HEAD_COMMIT" ]; then
                continue
            fi
        fi

        # Calculate days since last commit using commit epoch for precision
        COMMIT_EPOCH="$(git log -1 --format=%ct "$branch" 2>/dev/null || echo "0")"
        if [ "$COMMIT_EPOCH" = "0" ]; then
            log "${YELLOW}⚠ Warning: Could not get commit date for branch: $branch${NC}"
            continue
        fi

        CURRENT_EPOCH=$(date +%s)
        DAYS_OLD=$(( (CURRENT_EPOCH - COMMIT_EPOCH) / 86400 ))

        # Mark as stale if older than threshold
        STALE_MARKER=""
        IS_STALE=false
        if [ "$DAYS_OLD" -gt "$STALE_DAYS" ]; then
            STALE_MARKER="${RED}[STALE]${NC}"
            IS_STALE=true
            STALE_BRANCHES+=("$branch")
        fi

        # Show ISO date if available, otherwise show the date field
        LAST_COMMIT_ISO="$date"
        BRANCH_LINE=$(printf "%-30s %-25s %-25s %b" "$branch" "$LAST_COMMIT_ISO" "${author:0:24}" "$STALE_MARKER")
        log "$BRANCH_LINE"

        BRANCH_NAMES+=("$branch")
        BRANCH_DATES+=("$LAST_COMMIT_ISO")
    done < <(git for-each-ref -z --format='%(refname:short)%00%(upstream:track)%00%(committerdate:iso8601)%00%(authorname)%00' refs/heads/ 2>/dev/null || true)

    log ""

    # Check if we found any candidate branches at all
    if [ ${#BRANCH_NAMES[@]} -eq 0 ]; then
        log "${GREEN}✓ No branches found with deleted remotes${NC}"
        log ""
        if [ "$MULTI_REPO_MODE" = false ]; then
            log "All your local branches have corresponding remotes or are local-only branches."
        fi
        cd "$original_dir"
        return 0
    fi

    log "${YELLOW}Total: ${#BRANCH_NAMES[@]} branch(es)${NC}"
    if [ "$EXCLUDE_STALE" = true ] && [ ${#STALE_BRANCHES[@]} -gt 0 ]; then
        log "${YELLOW}Stale branches (will be excluded from deletion): ${#STALE_BRANCHES[@]}${NC}"
        log "${CYAN}ℹ Stale branches are shown for information only (--exclude-stale is set)${NC}"
    fi

    # Calculate how many branches will actually be deleted
    DELETABLE_COUNT=${#BRANCH_NAMES[@]}
    if [ "$EXCLUDE_STALE" = true ]; then
        DELETABLE_COUNT=$((DELETABLE_COUNT - ${#STALE_BRANCHES[@]}))
    fi

    if [ "$DELETABLE_COUNT" -eq 0 ]; then
        log ""
        log "${BLUE}No branches to delete (all are stale or excluded)${NC}"
        cd "$original_dir"
        return 0
    fi

    log ""

    # Ask for confirmation (skip in dry-run mode since we're not actually deleting)
    if [ "$DRY_RUN" = true ]; then
        log "${CYAN}Dry-run mode: analyzing what would be deleted...${NC}"
    elif [ "$AUTO_YES" = false ]; then
        read -r -n 1 -p "Do you want to delete these branches? (y/N): " REPLY
        echo ""

        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "${BLUE}Cancelled. No branches deleted.${NC}"
            cd "$original_dir"
            return 0
        fi
    else
        log "${YELLOW}Auto-confirm enabled, deleting branches...${NC}"
    fi

    # Delete branches with safer behavior: try -d first, then -D after explicit confirmation or when forced
    log ""
    DELETED_COUNT=0
    SKIPPED_COUNT=0
    WOULD_DELETE_COUNT=0
    WOULD_FORCE_COUNT=0

    for branch in "${BRANCH_NAMES[@]}"; do
        # Check if this branch is stale and should be excluded
        if [ "$EXCLUDE_STALE" = true ]; then
            IS_STALE_BRANCH=false
            for stale_branch in "${STALE_BRANCHES[@]}"; do
                if [ "$branch" = "$stale_branch" ]; then
                    IS_STALE_BRANCH=true
                    break
                fi
            done

            if [ "$IS_STALE_BRANCH" = true ]; then
                log "${CYAN}⊗ Skipped (stale): $branch${NC}"
                ((SKIPPED_COUNT++))
                continue
            fi
        fi

        # Protect current branch
        if [ -n "$CURRENT_BRANCH" ] && [ "$branch" = "$CURRENT_BRANCH" ]; then
            log "${CYAN}⊗ Skipped (current branch): $branch${NC}"
            ((SKIPPED_COUNT++))
            continue
        fi

        # Attempt safe delete first
        if [ "$DRY_RUN" = true ]; then
            # Determine whether a safe delete would succeed (branch merged into HEAD)
            if is_branch_merged "$branch"; then
                log "${YELLOW}Would delete (safe): $branch${NC}"
                ((WOULD_DELETE_COUNT++))
                continue
            else
                # Would require force to delete
                if [ "$FORCE_DELETE" = true ]; then
                    log "${YELLOW}Would delete (force): $branch${NC}"
                    ((WOULD_FORCE_COUNT++))
                    continue
                else
                    log "${YELLOW}Would skip (would require force to delete): $branch${NC}"
                    ((SKIPPED_COUNT++))
                    continue
                fi
            fi
        else
            if git branch -d -- "$branch" > /dev/null 2>&1; then
                log "${GREEN}✓ Deleted (safe): $branch${NC}"
                ((DELETED_COUNT++))
                continue
            fi
        fi

        # Safe delete failed (likely not fully merged)
        if [ "$FORCE_DELETE" = true ]; then
            if git branch -D -- "$branch" > /dev/null 2>&1; then
                log "${GREEN}✓ Deleted (force): $branch${NC}"
                ((DELETED_COUNT++))
            else
                log "${RED}✗ Failed to force-delete: $branch${NC}"
            fi
            continue
        fi

        # If auto-yes is enabled but force-delete is not, prompt for force
        if [ "$AUTO_YES" = true ]; then
            # In auto mode, don't force-delete unless FORCE_DELETE is set. Skip instead.
            log "${YELLOW}⊗ Skipped (would require force to delete): $branch${NC}"
            ((SKIPPED_COUNT++))
            continue
        fi

        # Ask user whether to force delete this branch
        read -r -n 1 -p "Branch '$branch' is not fully merged. Force delete? (y/N): " REPLY
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if git branch -D -- "$branch" > /dev/null 2>&1; then
                log "${GREEN}✓ Deleted (force): $branch${NC}"
                ((DELETED_COUNT++))
            else
                log "${RED}✗ Failed to force-delete: $branch${NC}"
            fi
        else
            log "${CYAN}⊗ Skipped (user cancelled force delete): $branch${NC}"
            ((SKIPPED_COUNT++))
        fi
    done

    log ""
    if [ "$DRY_RUN" = true ]; then
        log "${BLUE}Dry-run: Would have deleted ${WOULD_DELETE_COUNT} branch(es) (safe), ${WOULD_FORCE_COUNT} branch(es) (force). Skipped: ${SKIPPED_COUNT}${NC}"
    else
        if [ "$DELETED_COUNT" -gt 0 ] || [ "$SKIPPED_COUNT" -gt 0 ]; then
            log "${GREEN}✓ Done! Deleted $DELETED_COUNT branch(es)${NC}"
            if [ "$SKIPPED_COUNT" -gt 0 ]; then
                log "${CYAN}  Skipped $SKIPPED_COUNT branch(es)${NC}"
            fi
        else
            log "${BLUE}No branches were deleted${NC}"
        fi
    fi

    cd "$original_dir"
}

# Main execution
if [ "$MULTI_REPO_MODE" = true ]; then
    # Multi-repository mode
    if [ -z "$TARGET_FOLDER" ] || [ ! -d "$TARGET_FOLDER" ]; then
        log "${RED}Error: Folder does not exist: $TARGET_FOLDER${NC}"
        exit 1
    fi

    log "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    log "${BLUE}║   Git Clean Local Branches - Multi-Repo Mode          ║${NC}"
    log "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    log ""
    log "Started: ${CYAN}$(date -u '+%Y-%m-%dT%H:%M:%SZ')${NC}"
    log "Target folder: ${CYAN}$TARGET_FOLDER${NC}"
    log "Stale threshold: ${CYAN}$STALE_DAYS days${NC}"
    if [ "$EXCLUDE_STALE" = true ]; then
        log "Mode: ${CYAN}Exclude stale branches from deletion${NC}"
    fi
    if [ "$AUTO_YES" = true ]; then
        log "Auto-confirm: ${YELLOW}ENABLED${NC}"
    fi
    if [ "$LOG_ENABLED" = true ]; then
        log "Log file: ${CYAN}$LOG_FILE${NC}"
    fi
    if [ "$FORCE_DELETE" = true ]; then
        log "Force-delete mode: ${YELLOW}ENABLED${NC}"
    fi
    if [ "$RECURSIVE" = true ]; then
        log "Search mode: ${YELLOW}Recursive${NC}"
    fi
    if [ "$DRY_RUN" = true ]; then
        log "Dry-run: ${CYAN}ENABLED (no deletions will be performed)${NC}"
    fi
    log ""

    # Find git repositories in the target folder
    REPO_COUNT=0
    CLEANED_COUNT=0

    if [ "$RECURSIVE" = true ]; then
        # Find .git directories recursively and take their parent folder as repo root
        log "${CYAN}Searching for git repositories in: ${TARGET_FOLDER}${NC}"

        # Count repos first to provide feedback
        git_dir_count=$(find "$TARGET_FOLDER" -type d -name .git 2>/dev/null | wc -l || echo "0")
        log "${CYAN}Found ${git_dir_count} git repositor(ies) to process...${NC}"
        log ""

        # Disable errexit for the entire loop to prevent unexpected exits
        set +e

        # Enable bash debug mode to trace execution
#        set -x

        while IFS= read -r -d $'\0' gitdir; do
            [ -z "$gitdir" ] && continue
            dir="$(dirname "$gitdir")"
            log "Processing repo: ${CYAN}$dir${NC}"
#            log "${CYAN}[DEBUG] About to call clean_repository...${NC}"
            ((REPO_COUNT++))

            clean_repository "$dir"
            repo_result=$?

            if [ $repo_result -eq 0 ]; then
#                log "${GREEN}[DEBUG] clean_repository returned success${NC}"
                ((CLEANED_COUNT++))
            else
#                log "${YELLOW}[DEBUG] clean_repository returned error: $repo_result${NC}"
                log "${YELLOW}Warning: processing failed for: ${CYAN}$dir${NC} (exit code: $repo_result)"
            fi
            log "${CYAN}[DEBUG] Finished processing this repo${NC}"
        done < <(find "$TARGET_FOLDER" -type d -name .git -print0 2>/dev/null || true)

        # Disable bash debug mode
#        set +x

        # Re-enable errexit
        set -e

        log ""
        log "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        log "${GREEN}Finished processing. Total repositories: ${REPO_COUNT}${NC}"
    else
        for dir in "$TARGET_FOLDER"/*; do
            if [ -d "$dir/.git" ]; then
                log "Found repo: ${CYAN}$dir${NC}"
                ((REPO_COUNT++))
                if clean_repository "$dir"; then
                    ((CLEANED_COUNT++))
                fi
            fi
        done
    fi

    log ""
    log "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    log "${BLUE}║   Summary                                              ║${NC}"
    log "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    log "Completed: ${CYAN}$(date -u '+%Y-%m-%dT%H:%M:%SZ')${NC}"
    log "Total repositories found: ${CYAN}$REPO_COUNT${NC}"
    log "Repositories processed: ${GREEN}$CLEANED_COUNT${NC}"

    if [ "$REPO_COUNT" -eq 0 ]; then
        log ""
        log "${YELLOW}⚠ No git repositories found in the target folder${NC}"
        log "${YELLOW}  Make sure the folder contains git repositories (with .git directories)${NC}"
    fi
    log ""

else
    # Single repository mode
    CURRENT_DIR=$(pwd)
    clean_repository "$CURRENT_DIR"
fi

