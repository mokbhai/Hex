#!/bin/bash
# Watch Ralph progress in real-time
# Run this in a separate terminal to monitor progress

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PRD_FILE="$PROJECT_ROOT/prd.json"
PROGRESS_FILE="$PROJECT_ROOT/progress.txt"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    Ralph Progress Monitor                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

while true; do
    clear
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                    Ralph Progress Monitor                     ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    # Task status
    REMAINING=$(jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE" 2>/dev/null || echo "?")
    COMPLETED=$(jq '[.userStories[] | select(.passes == true)] | length' "$PRD_FILE" 2>/dev/null || echo "?")
    TOTAL=$(jq '.userStories | length' "$PRD_FILE" 2>/dev/null || echo "?")

    if [ "$TOTAL" != "?" ] && [ "$TOTAL" -gt 0 ]; then
        PERCENT=$((COMPLETED * 100 / TOTAL))
        printf "${CYAN}Progress:${NC} %d/%d tasks (%d%%)\n" "$COMPLETED" "$TOTAL" "$PERCENT"

        # Progress bar
        BAR_WIDTH=50
        FILLED=$((BAR_WIDTH * COMPLETED / TOTAL))
        EMPTY=$((BAR_WIDTH - FILLED))
        printf "["
        printf "%${FILLED}s" | tr ' ' '='
        printf "%${EMPTY}s" | tr ' ' '-'
        printf "]\n\n"
    fi

    # Current task (next to be done)
    echo -e "${YELLOW}Next task:${NC}"
    NEXT_TASK=$(jq -r '[.userStories[] | select(.passes == false)] | sort_by(.priority) | .[0] | "  \(.id) - \(.title)"' "$PRD_FILE" 2>/dev/null || echo "  All tasks complete!")
    echo "$NEXT_TASK"
    echo ""

    # Last completed task
    LAST_COMPLETED=$(jq -r '[.userStories[] | select(.passes == true)] | sort_by(.priority) | reverse | .[0] | "  \(.id) - \(.title)"' "$PRD_FILE" 2>/dev/null || echo "  None yet")
    if [ "$LAST_COMPLETED" != "  None yet" ]; then
        echo -e "${GREEN}Last completed:${NC}"
        echo "$LAST_COMPLETED"
        echo ""
    fi

    # Recent commits
    echo -e "${BLUE}Recent commits:${NC}"
    git -C "$PROJECT_ROOT" log --oneline -5 2>/dev/null || echo "  No commits yet"
    echo ""

    # Last update time
    if [ -f "$PROGRESS_FILE" ]; then
        MODIFIED=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$PROGRESS_FILE" 2>/dev/null || stat -c "%y" "$PROGRESS_FILE" 2>/dev/null | cut -d'.' -f1)
        echo -e "${CYAN}Last update:${NC} $MODIFIED"
    fi

    echo ""
    echo -e "${CYAN}Press Ctrl+C to exit${NC}"

    sleep 2
done
