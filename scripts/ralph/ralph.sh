#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop for Hex Voice
# Usage: ./ralph.sh [max_iterations]
#
# This script runs Claude Code repeatedly until all PRD items are complete.
# Each iteration is a fresh instance with clean context. Memory persists via:
# - Git history (commits from previous iterations)
# - progress.txt (learnings and context)
# - prd.json (which stories are done)

set -e

MAX_ITERATIONS=${1:-50}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PRD_FILE="$PROJECT_ROOT/prd.json"
PROGRESS_FILE="$PROJECT_ROOT/progress.txt"
ARCHIVE_DIR="$PROJECT_ROOT/.ralph-archive"
LAST_BRANCH_FILE="$PROJECT_ROOT/.ralph-last-branch"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if PRD file exists
if [ ! -f "$PRD_FILE" ]; then
    log_error "prd.json not found at $PRD_FILE"
    log_info "Please create prd.json from your EPICS.md using: /lifecycle:ralph"
    exit 1
fi

# Archive previous run if branch changed
if [ -f "$LAST_BRANCH_FILE" ]; then
    CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
    LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

    if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
        # Archive the previous run
        DATE=$(date +%Y-%m-%d)
        FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||' | sed 's|^feature/||')
        ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

        log_info "Archiving previous run: $LAST_BRANCH"
        mkdir -p "$ARCHIVE_FOLDER"
        [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
        [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
        log_success "Archived to: $ARCHIVE_FOLDER"

        # Reset progress file for new run
        cat > "$PROGRESS_FILE" << 'EOF'
# Ralph Progress Log for Hex Voice
# This file tracks learnings across iterations for autonomous AI development

## Codebase Patterns
# Add reusable patterns here as they are discovered

---
EOF
    fi
fi

# Track current branch
CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
    cat > "$PROGRESS_FILE" << 'EOF'
# Ralph Progress Log for Hex Voice
# This file tracks learnings across iterations for autonomous AI development

## Codebase Patterns
# Add reusable patterns here as they are discovered

---
EOF
fi

# Show status
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           Ralph Wiggum - Autonomous AI Agent Loop              ║"
echo "║                      Hex Voice - Tauri Refactor                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check and switch to branch
TARGET_BRANCH=$(jq -r '.branchName // "main"' "$PRD_FILE")
CURRENT_BRANCH_ACTUAL=$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || echo "")

if [ "$CURRENT_BRANCH_ACTUAL" != "$TARGET_BRANCH" ]; then
    log_info "Switching to branch: $TARGET_BRANCH"
    cd "$PROJECT_ROOT"

    # Check if branch exists
    if git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
        git checkout "$TARGET_BRANCH"
    else
        # Check if branch exists on remote
        if git show-ref --verify --quiet "refs/remotes/origin/$TARGET_BRANCH"; then
            git checkout -b "$TARGET_BRANCH" "origin/$TARGET_BRANCH"
        else
            # Create new branch from main
            git checkout main 2>/dev/null || git checkout master 2>/dev/null || true
            git checkout -b "$TARGET_BRANCH"
        fi
    fi
    log_success "Now on branch: $TARGET_BRANCH"
fi

# Pull latest changes
log_info "Pulling latest changes..."
git -C "$PROJECT_ROOT" pull --rebase 2>/dev/null || true

# Count remaining tasks
REMAINING=$(jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE")
COMPLETED=$(jq '[.userStories[] | select(.passes == true)] | length' "$PRD_FILE")
TOTAL=$(jq '.userStories | length' "$PRD_FILE")

echo ""
log_info "Task Status: $COMPLETED/$TOTAL completed, $REMAINING remaining"
echo ""

if [ "$REMAINING" -eq 0 ]; then
    log_success "All tasks are already complete!"
    exit 0
fi

log_info "Starting Ralph loop - Max iterations: $MAX_ITERATIONS"
echo ""

for i in $(seq 1 $MAX_ITERATIONS); do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}  Ralph Iteration $i of $MAX_ITERATIONS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Run Claude Code with the ralph prompt
    cd "$PROJECT_ROOT"
    OUTPUT=$(claude --dangerously-skip-permissions --print < "$SCRIPT_DIR/CLAUDE.md" 2>&1 | tee /dev/stderr) || true

    # Check for completion signal
    if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
        echo ""
        log_success "Ralph completed all tasks!"
        log_info "Completed at iteration $i of $MAX_ITERATIONS"
        echo ""
        log_info "Final status:"
        REMAINING=$(jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE")
        COMPLETED=$(jq '[.userStories[] | select(.passes == true)] | length' "$PRD_FILE")
        echo "  - Completed: $COMPLETED/$TOTAL"
        echo "  - Progress file: $PROGRESS_FILE"
        echo ""

        # Optional: push to remote
        read -p "Push changes to remote? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git push origin "$TARGET_BRANCH"
        fi

        exit 0
    fi

    # Check if all tasks are done
    REMAINING=$(jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE")
    if [ "$REMAINING" -eq 0 ]; then
        echo ""
        log_success "All tasks marked as complete in prd.json!"
        exit 0
    fi

    echo ""
    log_info "Iteration $i complete. Remaining tasks: $REMAINING"
    echo ""

    # Brief pause between iterations
    sleep 2
done

echo ""
log_warning "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
log_info "Check progress.txt for details on what was accomplished."
log_info "To continue, run: ./scripts/ralph/ralph.sh"
echo ""
