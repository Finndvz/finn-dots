# finn migrate - Manage migration scripts

local MIGRATIONS_DIR="$DOTS_DIR/.data/finn-cli/migrations"
local DONE_FILE="$HOME/.local/share/finn/migrations-done"
local LEGACY_DONE_FILE="$HOME/.local/share/lyne/migrations-done"
local subcmd="${1:-}"

mkdir -p "$(dirname "$DONE_FILE")"
touch "$DONE_FILE"

if [[ -f "$LEGACY_DONE_FILE" ]]; then
    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        [[ "$name" == "004-install-lyne-cli-to-path.sh" ]] && name="004-install-finn-cli-to-path.sh"
        grep -qxF "$name" "$DONE_FILE" 2>/dev/null || echo "$name" >> "$DONE_FILE"
    done < "$LEGACY_DONE_FILE"
fi

case "$subcmd" in
    -h|--help)
        echo "Usage: finn migrate [subcommand]"
        echo ""
        echo "Manage dotfiles migration scripts."
        echo ""
        echo "Subcommands:"
        echo "  (none)  Run pending migrations"
        echo "  list    Show all migrations and their status"
        echo "  done    Mark all pending migrations as done"
        ;;
    list)
        local total=0
        local pending=0

        for migration in "$MIGRATIONS_DIR"/*.sh; do
            [[ -f "$migration" ]] || continue
            local name="$(basename "$migration")"
            ((total++))
            if grep -qxF "$name" "$DONE_FILE" 2>/dev/null; then
                echo -e "  \e[1;32m[done]\e[0m    $name"
            else
                echo -e "  \e[1;33m[pending]\e[0m $name"
                ((pending++))
            fi
        done

        if [[ $total -eq 0 ]]; then
            echo "finn migrate: no migrations found"
        else
            echo ""
            echo "  $total total, $pending pending"
        fi
        ;;
    done)
        local count=0
        for migration in "$MIGRATIONS_DIR"/*.sh; do
            [[ -f "$migration" ]] || continue
            local name="$(basename "$migration")"
            if ! grep -qxF "$name" "$DONE_FILE" 2>/dev/null; then
                echo "$name" >> "$DONE_FILE"
                ((count++))
            fi
        done

        if [[ $count -eq 0 ]]; then
            echo "finn migrate: all migrations already marked as done"
        else
            echo "finn migrate: marked $count migrations as done"
        fi
        ;;
    "")
        echo ":: Running pending migrations..."
        source "$DOTS_DIR/.data/finn-cli/lib/run-migrations.sh"
        ;;
    *)
        echo "finn migrate: unknown subcommand '$subcmd'"
        echo "Run 'finn migrate --help' for usage information."
        ;;
esac
