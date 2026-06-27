# finn git - Passthrough to git in the dotfiles repo

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: finn git <args...>"
    echo ""
    echo "Run git commands scoped to the dotfiles repository."
    echo ""
    echo "Examples:"
    echo "  finn git status"
    echo "  finn git log --oneline -5"
    echo "  finn git diff"
    return 0
fi

git -C "$DOTS_DIR" "$@"
