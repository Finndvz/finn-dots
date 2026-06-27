# run-migrations.sh - Run pending migration scripts
#
# Migrations live in .data/finn-cli/migrations/ as numbered shell scripts.
# Each migration runs only once. Completed migrations are tracked in
# a local file that is not managed by git.
#
# Usage: source this file (expects $DOTS_DIR to be set)

local MIGRATIONS_DIR="$DOTS_DIR/.data/finn-cli/migrations"
local DONE_FILE="$HOME/.local/share/finn/migrations-done"
local LEGACY_DONE_FILE="$HOME/.local/share/lyne/migrations-done"

# Ensure tracking directory exists
mkdir -p "$(dirname "$DONE_FILE")"
touch "$DONE_FILE"

if [[ -f "$LEGACY_DONE_FILE" ]]; then
    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        [[ "$name" == "004-install-lyne-cli-to-path.sh" ]] && name="004-install-finn-cli-to-path.sh"
        grep -qxF "$name" "$DONE_FILE" 2>/dev/null || echo "$name" >> "$DONE_FILE"
    done < "$LEGACY_DONE_FILE"
fi

# Find and run pending migrations in order
local has_pending=false

for migration in "$MIGRATIONS_DIR"/*.sh; do
    [[ -f "$migration" ]] || continue
    local name="$(basename "$migration")"

    # Skip if already executed
    if grep -qxF "$name" "$DONE_FILE" 2>/dev/null; then
        continue
    fi

    has_pending=true
    echo "   -> Running migration: $name"

    if source "$migration"; then
        echo "$name" >> "$DONE_FILE"
    else
        echo "finn migrate: migration '$name' failed, stopping"
        return 1
    fi
done

if [[ "$has_pending" = false ]]; then
    echo "   No pending migrations"
fi
