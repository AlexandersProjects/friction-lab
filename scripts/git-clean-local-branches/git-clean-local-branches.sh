#!/bin/bash

# Git Clean Local Branches
# Finds and removes local branches that no longer have remote counterparts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
STALE_DAYS=30
MULTI_REPO_MODE=false
TARGET_FOLDER=""
AUTO_YES=false
EXCLUDE_STALE=false
LOG_FILE=""
LOG_ENABLED=false

# Logging function - prints to terminal with colors, logs to file without colors
log() {
    local message="$1"

    # Print to terminal with colors
    echo -e "$message"

    # Write to log file without colors (if enabled)
    if [ "$LOG_ENABLED" = true ]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local clean_message=$(echo -e "$message" | sed 's/\x1b\[[0-9;]*m//g')
        echo "[$timestamp] $clean_message" >> "$LOG_FILE"
    fi
}


# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--folder)
            MULTI_REPO_MODE=true
            TARGET_FOLDER="$2"
            shift 2
            ;;
        -y|--yes)
            AUTO_YES=true
            shift
            ;;
        -s|--stale-days)
            if ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -le 0 ]; then
                echo -e "${RED}Error: --stale-days must be a positive number (got: '$2')${NC}"
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
            if [ -z "${2:-}" ] || [[ "$2" == -* ]]; then
                echo -e "${RED}Error: --log requires a file path${NC}"
                exit 1
            fi
            LOG_FILE="$2"
            LOG_ENABLED=true
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -f, --folder PATH       Run on all git repositories in the specified folder"
            echo "  -y, --yes               Auto-confirm deletions (use with caution!)"
            echo "  -s, --stale-days DAYS   Set custom threshold for marking stale branches (default: 30)"
            echo "  -x, --exclude-stale     Exclude stale branches from deletion (show only)"
            echo "  -l, --log FILE          Write log output to specified file (with timestamps)"
            echo "  -h, --help              Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                              # Clean current repository"
            echo "  $0 -f ~/projects                # Clean all repos in ~/projects"
            echo "  $0 -f ~/projects -y             # Clean all repos (auto-confirm)"
            echo "  $0 -s 60                        # Mark branches >60 days as stale"
            echo "  $0 -x                           # Show stale branches but don't delete them"
            echo "  $0 -s 60 -x                     # Custom threshold + exclude stale from deletion"
            echo "  $0 -l cleanup.log               # Log all output to cleanup.log"
            echo "  $0 -f ~/projects -l multi.log   # Multi-repo with logging"
            exit 0
            ;;
        *)
            log "${RED}Unknown option: $1${NC}"
            log "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Initialize logging if enabled
if [ "$LOG_ENABLED" = true ]; then
    # Create log file or append if it exists
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] ==== Git Clean Local Branches Log Started ====" >> "$LOG_FILE"
fi

# Function to clean branches in a single repository
clean_repository() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    local original_dir=$(pwd)

    cd "$repo_path" || {
        log "${RED}Error: Cannot access directory: $repo_path${NC}"
        return 1
    }

    # Check if we're in a git repository
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        log "${RED}Error: Not a git repository: $repo_path${NC}"
        cd "$original_dir"
        return 1
    fi

    # Get current branch to avoid deleting it
    CURRENT_BRANCH=$(git branch --show-current)

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

    # Find branches with deleted remotes (marked as 'gone')
    BRANCHES=$(git for-each-ref --format='%(refname:short)|%(upstream:track)|%(committerdate:relative)|%(authorname)' refs/heads/ | grep '\[gone\]' || true)

    if [ -z "$BRANCHES" ]; then
        log "${GREEN}✓ No branches found with deleted remotes${NC}"
        log ""
        if [ "$MULTI_REPO_MODE" = false ]; then
            log "All your local branches have corresponding remotes or are local-only branches."
        fi
        cd "$original_dir"
        return 0
    fi

    # Parse and display branches
    log "${YELLOW}Found branches with deleted remotes:${NC}"
    log ""
    log "$(printf "%-30s %-20s %-30s" "BRANCH" "LAST COMMIT" "AUTHOR")"
    log "--------------------------------------------------------------------------------"

    declare -a BRANCH_NAMES=()
    declare -a BRANCH_DATES=()
    declare -a STALE_BRANCHES=()

    while IFS='|' read -r branch tracking date author; do
        # Skip current branch
        if [ "$branch" = "$CURRENT_BRANCH" ]; then
            continue
        fi

        # Calculate days since last commit
        COMMIT_EPOCH=$(git log -1 --format=%ct "$branch" 2>/dev/null || echo "0")
        if [ "$COMMIT_EPOCH" = "0" ]; then
            # Failed to get commit date, skip this branch
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

        BRANCH_LINE=$(printf "%-30s %-20s %-30s %b" "$branch" "$date" "${author:0:25}" "$STALE_MARKER")
        log "$BRANCH_LINE"

        BRANCH_NAMES+=("$branch")
        BRANCH_DATES+=("$date")
    done <<< "$BRANCHES"

    log ""
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

    # Ask for confirmation
    if [ "$AUTO_YES" = false ]; then
        read -p "Do you want to delete these branches? (y/N): " -n 1 -r
        echo ""

        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "${BLUE}Cancelled. No branches deleted.${NC}"
            cd "$original_dir"
            return 0
        fi
    else
        log "${YELLOW}Auto-confirm enabled, deleting branches...${NC}"
    fi

    # Delete branches
    log ""
    DELETED_COUNT=0
    SKIPPED_COUNT=0

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

        if git branch -D "$branch" > /dev/null 2>&1; then
            log "${GREEN}✓ Deleted: $branch${NC}"
            ((DELETED_COUNT++))
        else
            log "${RED}✗ Failed to delete: $branch${NC}"
        fi
    done

    log ""
    if [ "$DELETED_COUNT" -gt 0 ] || [ "$SKIPPED_COUNT" -gt 0 ]; then
        log "${GREEN}✓ Done! Deleted $DELETED_COUNT branch(es)${NC}"
        if [ "$SKIPPED_COUNT" -gt 0 ]; then
            log "${CYAN}  Skipped $SKIPPED_COUNT stale branch(es)${NC}"
        fi
    else
        log "${BLUE}No branches were deleted${NC}"
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
    log "Started: ${CYAN}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
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
    log ""

    # Find all git repositories in the target folder (one level deep)
    REPO_COUNT=0
    CLEANED_COUNT=0

    for dir in "$TARGET_FOLDER"/*; do
        if [ -d "$dir/.git" ]; then
            ((REPO_COUNT++))
            if clean_repository "$dir"; then
                ((CLEANED_COUNT++))
            fi
        fi
    done

    log ""
    log "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    log "${BLUE}║   Summary                                              ║${NC}"
    log "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    log "Completed: ${CYAN}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
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

