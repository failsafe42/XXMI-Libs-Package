#!/usr/bin/env bash
#
# generate-version.sh — Bash port of tools/generate-version.ps1
# Generates version.generated.h from git state.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Parameters (environment overrides: VERSION_FILE, OUTPUT_FILE, TAG)
# ---------------------------------------------------------------------------

VERSION_FILE="${VERSION_FILE:-$SCRIPT_DIR/../version.h}"
OUTPUT_FILE="${OUTPUT_FILE:-$SCRIPT_DIR/../version.generated.h}"
TAG="${TAG:-}"

VERSION_FILE="$(realpath --canonicalize-missing -- "$VERSION_FILE")"
OUTPUT_FILE="$(realpath --canonicalize-missing -- "$OUTPUT_FILE")"

if [[ ! -f "$VERSION_FILE" ]]; then
    echo "Version file not found: $VERSION_FILE" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

invoke_git() {
    local result
    if ! result="$(git "$@" 2>&1)"; then
        echo "Git command failed: git $*" >&2
        echo "$result" >&2
        exit 1
    fi
    printf '%s' "$result"
}

trim() {
    # Trim leading/trailing whitespace and CR (Windows checkouts).
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

parse_version_tag() {
    local tag="$1"
    if [[ "$tag" =~ ^v?([0-9]+)\.([0-9]+)\.([0-9]+)(\.([0-9]+))?$ ]]; then
        VERSION_MAJOR="${BASH_REMATCH[1]}"
        VERSION_MINOR="${BASH_REMATCH[2]}"
        VERSION_REVISION="${BASH_REMATCH[3]}"
        if [[ -n "${BASH_REMATCH[5]:-}" ]]; then
            VERSION_BUILD="${BASH_REMATCH[5]}"
        else
            VERSION_BUILD="0"
        fi
    else
        echo "Invalid version tag '$tag'. Expected vMAJOR.MINOR.PATCH or vMAJOR.MINOR.PATCH.BUILD" >&2
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Verify we are inside a Git repository
# ---------------------------------------------------------------------------

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not inside a Git repository." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Git repository
# ---------------------------------------------------------------------------

REMOTE_URL="$(invoke_git config --get remote.origin.url)" || true
REMOTE_URL="$(trim "$REMOTE_URL")"

if [[ -z "$REMOTE_URL" ]]; then
    echo "Git remote 'origin' is not configured." >&2
    exit 1
fi

# Convert common GitHub remote formats to a clean HTTPS URL.
if [[ "$REMOTE_URL" =~ ^git@github\.com:(.+?)(\.git)?$ ]]; then
    REPO_URL="https://github.com/${BASH_REMATCH[1]}"
elif [[ "$REMOTE_URL" =~ ^ssh://git@github\.com/(.+?)(\.git)?$ ]]; then
    REPO_URL="https://github.com/${BASH_REMATCH[1]}"
elif [[ "$REMOTE_URL" =~ ^https://github\.com/(.+?)(\.git)?$ ]]; then
    REPO_URL="https://github.com/${BASH_REMATCH[1]}"
elif [[ "$REMOTE_URL" =~ ^http://github\.com/(.+?)(\.git)?$ ]]; then
    REPO_URL="https://github.com/${BASH_REMATCH[1]}"
else
    REPO_URL="${REMOTE_URL%.git}"
fi

# ---------------------------------------------------------------------------
# Version tag
# ---------------------------------------------------------------------------

if [[ -z "$TAG" ]]; then
    if ! TAG="$(invoke_git describe --tags --match 'v[0-9]*' --abbrev=0 2>/dev/null)"; then
        echo "No version tag was found. Create a tag such as v1.4.0 first." >&2
        exit 1
    fi
fi

TAG="$(trim "$TAG")"
parse_version_tag "$TAG"

# ---------------------------------------------------------------------------
# Git commit information
# ---------------------------------------------------------------------------

HEAD_COMMIT="$(invoke_git rev-parse HEAD)"
WORKING_TREE_STATUS="$(git status --porcelain 2>/dev/null || true)"

IS_DIRTY=false
[[ -n "$WORKING_TREE_STATUS" ]] && IS_DIRTY=true

TAG_COMMIT="$(invoke_git rev-list -n 1 "$TAG")"
COMMITS_SINCE_TAG="$(( $(invoke_git rev-list "$TAG..HEAD" --count) ))"

IS_RELEASE=false
[[ "$HEAD_COMMIT" == "$TAG_COMMIT" ]] && IS_RELEASE=true

if [[ "$IS_RELEASE" == false ]]; then
    VERSION_BUILD=$(( VERSION_BUILD + COMMITS_SINCE_TAG ))
fi

SHORT_COMMIT="$(invoke_git rev-parse --short=8 HEAD)"

COMMIT_DISPLAY="$SHORT_COMMIT"
[[ "$IS_DIRTY" == true ]] && COMMIT_DISPLAY="$COMMIT_DISPLAY-dirty"

# ---------------------------------------------------------------------------
# Builder identity
# ---------------------------------------------------------------------------

# GitHub Actions provides GITHUB_ACTOR automatically.
BUILDER="${GITHUB_ACTOR:-}"

# Local builds can optionally use:
#
#   git config --global github.username YourGitHubUsername
#
if [[ -z "$BUILDER" ]]; then
    BUILDER="$(git config --get github.username 2>/dev/null || true)"
fi

# Fall back to the normal Git user name.
if [[ -z "$BUILDER" ]]; then
    BUILDER="$(git config --get user.name 2>/dev/null || true)"
fi

BUILDER="$(trim "$BUILDER")"

if [[ -z "$BUILDER" ]]; then
    BUILDER="Unknown"
fi

# ---------------------------------------------------------------------------
# Explorer Comments field
# ---------------------------------------------------------------------------

COMPANY_NAME="Built by $BUILDER @ $COMMIT_DISPLAY"
COMMENTS="$REPO_URL"

# Escape characters which could break the generated C/C++ string.
COMPANY_NAME="${COMPANY_NAME//\\/\\\\}"
COMPANY_NAME="${COMPANY_NAME//\"/\\\"}"
COMMENTS="${COMMENTS//\\/\\\\}"
COMMENTS="${COMMENTS//\"/\\\"}"

# ---------------------------------------------------------------------------
# Generate header
# ---------------------------------------------------------------------------

cat > "$OUTPUT_FILE" <<EOF
#define VERSION_MAJOR               $VERSION_MAJOR
#define VERSION_MINOR               $VERSION_MINOR
#define VERSION_REVISION            $VERSION_REVISION
#define VERSION_BUILD               $VERSION_BUILD

#define VER_COMPANYNAME_STR         "$COMPANY_NAME"
#define VER_COMMENTS_STR            "$COMMENTS"

EOF

VERSION="$VERSION_MAJOR.$VERSION_MINOR.$VERSION_REVISION.$VERSION_BUILD"

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

echo ""
echo "========================================"
echo " Generated version header"
echo "========================================"
echo "Version:            $VERSION"
echo "Source tag:         $TAG"
echo "Commits since tag:  $COMMITS_SINCE_TAG"
echo "Release build:      $IS_RELEASE"
echo "Builder:            $BUILDER"
echo "Commit:             $COMMIT_DISPLAY"
echo "Working tree dirty: $IS_DIRTY"
echo "Repository:         $REPO_URL"
echo "Comments:           $COMMENTS"
echo "Output:             $OUTPUT_FILE"
echo "========================================"
echo ""