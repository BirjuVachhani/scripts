#!/bin/bash

# core.sh - Common utilities for .scripts
# This file provides shared functions, utilities, and configuration loading
# for all scripts in the .scripts directory.

# ==============================================================================
# SCRIPT DIRECTORY DETECTION
# ==============================================================================

# Get the directory where the sourcing script is located
# This ensures core.sh functions work correctly regardless of where scripts are called from
get_script_dir() {
    local source="${BASH_SOURCE[1]}"
    local dir
    dir="$(cd "$(dirname "$source")" && pwd)"
    echo "$dir"
}

# Store the scripts directory for later use
SCRIPTS_DIR="$(get_script_dir)"

# ==============================================================================
# ENVIRONMENT CONFIGURATION
# ==============================================================================

# Load environment variables from .env file if it exists
load_env() {
    local env_file="$SCRIPTS_DIR/.env"

    if [ -f "$env_file" ]; then
        # Read .env file and export variables using a more robust method
        while IFS= read -r line || [ -n "$line" ]; do
            # Skip comments and empty lines
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

            # Extract key and value
            if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$ ]]; then
                local key="${BASH_REMATCH[1]}"
                local value="${BASH_REMATCH[2]}"

                # Remove surrounding quotes only if they match
                if [[ "$value" =~ ^\"(.*)\"$ ]] || [[ "$value" =~ ^\'(.*)\'$ ]]; then
                    value="${BASH_REMATCH[1]}"
                fi

                # Export the variable
                export "$key=$value"
            fi
        done < "$env_file"
    fi
}

# Load environment on source
load_env

# ==============================================================================
# COLOR CONSTANTS
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ==============================================================================
# LOGGING FUNCTIONS
# ==============================================================================

# Print formatted log messages with consistent styling
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# ==============================================================================
# PUBSPEC UTILITIES
# ==============================================================================

# Check if pubspec file exists and return its path
# Usage: find_pubspec "/path/to/directory"
# Returns: Path to pubspec file (stdout) and exit code 0 if found, 1 otherwise
find_pubspec() {
    local dir="$1"

    if [ -f "$dir/pubspec.yaml" ]; then
        echo "$dir/pubspec.yaml"
        return 0
    elif [ -f "$dir/pubspec.yml" ]; then
        echo "$dir/pubspec.yml"
        return 0
    fi

    return 1
}

# Check if project has Flutter SDK dependency
# Usage: has_flutter_dependency "/path/to/pubspec.yaml"
# Returns: 0 if Flutter dependency found, 1 otherwise
has_flutter_dependency() {
    local pubspec_path="$1"

    # Check if flutter sdk is listed in the pubspec
    if grep -q "sdk:[[:space:]]*flutter" "$pubspec_path"; then
        return 0
    fi

    return 1
}

# Check if a package is a member of a pub workspace
# Usage: is_workspace_member "/path/to/pubspec.yaml"
# Returns: 0 if the package resolves through a workspace, 1 otherwise
#
# Members carry a top-level "resolution: workspace" key. Their dependencies are
# resolved by a single pub get at the workspace root, into one shared lockfile.
is_workspace_member() {
    local pubspec_path="$1"

    grep -qE "^resolution:[[:space:]]*[\"']?workspace[\"']?" "$pubspec_path"
}

# Check if a package is the root of a pub workspace
# Usage: is_workspace_root "/path/to/pubspec.yaml"
# Returns: 0 if the pubspec declares a workspace, 1 otherwise
is_workspace_root() {
    local pubspec_path="$1"

    grep -qE "^workspace:" "$pubspec_path"
}

# Check if project has build_runner as dev dependency
# Usage: has_build_runner "/path/to/pubspec.yaml"
# Returns: 0 if build_runner found, 1 otherwise
has_build_runner() {
    local pubspec_path="$1"

    # Check if build_runner is listed in dev_dependencies
    awk '
        /^dev_dependencies:/ { in_dev_deps = 1; next }
        /^[a-zA-Z]/ && !/^[[:space:]]/ { in_dev_deps = 0 }
        in_dev_deps && /[[:space:]]+build_runner:/ { found = 1; exit }
        END { exit !found }
    ' "$pubspec_path"
}

# Get project name from pubspec file
# Usage: get_project_name "/path/to/pubspec.yaml"
# Returns: Project name (stdout)
get_project_name() {
    local pubspec_path="$1"
    grep "^name:" "$pubspec_path" | sed 's/name:[[:space:]]*//g' | head -1
}

# ==============================================================================
# PATH UTILITIES
# ==============================================================================

# Calculate relative path from base to target (portable solution)
# Usage: relativePath "/base/path" "/target/path"
# Returns: Relative path from base to target (stdout)
relativePath() {
    local base="$1"
    local target="$2"

    # If paths are the same, return "."
    if [ "$base" = "$target" ]; then
        echo "."
        return 0
    fi

    # Check if python3 is available
    if ! command -v python3 >/dev/null 2>&1; then
        # Fallback: return absolute path if python3 not available
        echo "$target"
        return 1
    fi

    # Use Python to calculate relative path (works on both macOS and Linux)
    python3 -c "import os.path; print(os.path.relpath('$target', '$base'))"
}

# ==============================================================================
# YAML CONFIG
# ==============================================================================

# Locate a script's config file
# Usage: find_config_file "flutterclean" "/path/to/target/dir"
# Returns: Path to the config file (stdout), empty if none exists
#
# A config next to the code being cleaned wins over the global one in the
# scripts directory, so a repo can carry its own rules.
find_config_file() {
    local script_name="$1"
    local dir="$2"
    local candidate

    for candidate in "$dir/$script_name.yaml" "$dir/$script_name.yml" \
                     "$SCRIPTS_DIR/$script_name.yaml" "$SCRIPTS_DIR/$script_name.yml"; do
        if [ -f "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done

    return 1
}

# Read a list of scalars out of a two-level YAML block
# Usage: read_yaml_list "/path/to/file.yaml" "clean" "include"
# Returns: One entry per line (stdout)
#
# This understands the small subset the config files use: top-level sections,
# one level of nested keys, and block sequences of plain or quoted scalars.
# Flow sequences ("key: [a, b]") are not supported.
read_yaml_list() {
    local file="$1"
    local section="$2"
    local key="$3"

    [ -f "$file" ] || return 0

    awk -v want_section="$section" -v want_key="$key" '
        function trim(v) {
            sub(/^[[:space:]]+/, "", v)
            sub(/[[:space:]]+$/, "", v)
            return v
        }
        function unquote(v,   quote, rest, end) {
            v = trim(v)
            quote = substr(v, 1, 1)
            if (quote == "\"" || quote == "\047") {
                rest = substr(v, 2)
                end = index(rest, quote)
                if (end > 0) return substr(rest, 1, end - 1)
            }
            # Only strip a comment that is set off by whitespace, so that a
            # pattern may still contain a "#" character.
            sub(/[[:space:]]+#.*$/, "", v)
            return trim(v)
        }

        { line = $0; sub(/\r$/, "", line) }

        line ~ /^[[:space:]]*$/ { next }
        line ~ /^[[:space:]]*#/ { next }

        # List item. Checked before keys so that a value may contain a colon.
        line ~ /^[[:space:]]+-[[:space:]]*/ {
            if (in_section && in_key) {
                value = line
                sub(/^[[:space:]]*-[[:space:]]*/, "", value)
                value = unquote(value)
                if (value != "") print value
            }
            next
        }

        # Top-level section, written flush against the left margin.
        line ~ /^[^[:space:]#-][^:]*:/ {
            name = line
            sub(/:.*$/, "", name)
            in_section = (trim(name) == want_section)
            in_key = 0
            next
        }

        # Nested key.
        line ~ /^[[:space:]]+[^[:space:]#-][^:]*:/ {
            name = line
            sub(/:.*$/, "", name)
            in_key = (in_section && trim(name) == want_key)
            next
        }
    ' "$file"
}

# ==============================================================================
# GLOB MATCHING
# ==============================================================================

# Convert a glob pattern to an anchored regular expression
# Usage: glob_to_regex "**/node_modules/**"
# Returns: Regular expression (stdout)
#
# "**" crosses directory boundaries, "*" and "?" do not. A leading "**/" also
# matches at the top level, and a trailing "/**" also matches the directory
# itself, so "**/node_modules/**" covers node_modules wherever it appears
# along with everything inside it.
glob_to_regex() {
    local glob="$1"
    local regex=""
    local suffix=""
    local len
    local i=0
    local char

    if [ "${glob%/\*\*}" != "$glob" ]; then
        glob="${glob%/\*\*}"
        suffix="(/.*)?"
    fi

    len=${#glob}

    while [ $i -lt $len ]; do
        char="${glob:$i:1}"

        case "$char" in
            '*')
                if [ "${glob:$((i + 1)):1}" = "*" ]; then
                    if [ "${glob:$((i + 2)):1}" = "/" ]; then
                        # "**/" may stand for no directory at all
                        regex="$regex(.*/)?"
                        i=$((i + 3))
                        continue
                    fi
                    regex="$regex.*"
                    i=$((i + 2))
                    continue
                fi
                regex="$regex[^/]*"
                ;;
            '?')
                regex="$regex[^/]"
                ;;
            '.' | '+' | '(' | ')' | '[' | ']' | '^' | '$' | '{' | '}' | '|' | '\')
                regex="$regex\\$char"
                ;;
            *)
                regex="$regex$char"
                ;;
        esac

        i=$((i + 1))
    done

    echo "^$regex$suffix\$"
}

# Convert globs into find -path predicates rooted at a directory
# Usage: globs_to_find_paths "/search/root" "**/build/**" "packages/*/build"
# Returns: Predicates joined with -o (stdout), empty if no globs are given
#
# A trailing "/**" is dropped because pruning a directory already covers its
# contents. A leading "**/" expands to two predicates, one anchored at the root
# and one for every level below it, since find's "*" does not match an empty
# path segment.
globs_to_find_paths() {
    local root="$1"
    shift

    local expr=""
    local glob
    local pattern

    for glob in "$@"; do
        [ -z "$glob" ] && continue

        # Pruning the directory covers everything under it
        glob="${glob%/\*\*}"
        glob="${glob%/\*}"

        local -a forms=()
        if [ "${glob#\*\*/}" != "$glob" ]; then
            forms=("${glob#\*\*/}" "*/${glob#\*\*/}")
        else
            forms=("$glob")
        fi

        for pattern in "${forms[@]}"; do
            # find's "*" already crosses directory boundaries
            while [ "${pattern//\*\*/\*}" != "$pattern" ]; do
                pattern="${pattern//\*\*/\*}"
            done

            [ -z "$pattern" ] && continue

            if [ -n "$expr" ]; then
                expr="$expr -o "
            fi
            expr="$expr-path \"$root/$pattern\""
        done
    done

    echo "$expr"
}

# Check whether a path matches any of the given globs
# Usage: path_matches_glob "app/node_modules" "**/node_modules/**" ...
# Returns: 0 on a match, 1 otherwise
path_matches_glob() {
    local path="$1"
    shift

    local glob
    local regex

    for glob in "$@"; do
        [ -z "$glob" ] && continue
        regex=$(glob_to_regex "$glob")
        if [[ "$path" =~ $regex ]]; then
            return 0
        fi
    done

    return 1
}

# ==============================================================================
# EXCLUSION LOGIC
# ==============================================================================

# Read exclusion patterns from a script-specific exclude file
# Usage: load_exclude_patterns "script-name"
# Returns: Patterns in the EXCLUDE_PATTERNS global array
load_exclude_patterns() {
    local script_name="$1"
    local exclude_file="$SCRIPTS_DIR/.${script_name}-exclude"
    local folder

    EXCLUDE_PATTERNS=()

    [ -f "$exclude_file" ] || return 0

    # The `|| [ -n "$folder" ]` guard picks up a final line that has no
    # trailing newline, which `read` alone would silently drop.
    while IFS= read -r folder || [ -n "$folder" ]; do
        # Trim carriage returns and surrounding whitespace
        folder="${folder%$'\r'}"
        folder="${folder#"${folder%%[![:space:]]*}"}"
        folder="${folder%"${folder##*[![:space:]]}"}"

        # Skip empty lines and comments
        [[ -z "$folder" || "$folder" == \#* ]] && continue

        EXCLUDE_PATTERNS+=("$folder")
    done < "$exclude_file"
}

# Build a find expression that prunes excluded directories
# Usage: build_prune_expr "script-name" "/path/to/search"
# Returns: Prune expression ending in -o, or empty string if nothing is excluded
#
# Pruning matters more than filtering here: `-not -path` still walks every file
# under an excluded directory and only hides it from the output, so a single
# Pods or node_modules tree can dominate the runtime of a scan.
#
# The TRAVERSE_EXCLUDE_GLOBS and TRAVERSE_INCLUDE_GLOBS arrays, when a caller
# has filled them from a config file, extend and override the exclude file.
build_prune_expr() {
    local script_name="$1"
    local dir="$2"
    local prune_expr=""
    local keep_expr=""
    local pattern
    local match

    load_exclude_patterns "$script_name"

    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        # Patterns with a slash are matched against the path, bare names
        # against the directory name itself.
        if [[ "$pattern" == */* ]]; then
            match="-path \"*/$pattern\""
        else
            match="-name \"$pattern\""
        fi

        if [ -z "$prune_expr" ]; then
            prune_expr="$match"
        else
            prune_expr="$prune_expr -o $match"
        fi
    done

    match=$(globs_to_find_paths "$dir" "${TRAVERSE_EXCLUDE_GLOBS[@]}")
    if [ -n "$match" ]; then
        if [ -z "$prune_expr" ]; then
            prune_expr="$match"
        else
            prune_expr="$prune_expr -o $match"
        fi
    fi

    [ -z "$prune_expr" ] && return 0

    # Configured includes win over every exclusion, so a directory that would
    # otherwise be skipped can be walked again.
    keep_expr=$(globs_to_find_paths "$dir" "${TRAVERSE_INCLUDE_GLOBS[@]}")
    if [ -n "$keep_expr" ]; then
        keep_expr=" ! \\( $keep_expr \\)"
    fi

    # `! -path "$dir"` keeps the search root itself from being pruned when its
    # own name matches an exclusion, e.g. running the script from inside a
    # directory that happens to be called "web". find reports the root under
    # exactly the path it was given, so this only ever spares the root.
    echo "\\( -type d ! -path \"$dir\"$keep_expr \\( $prune_expr \\) -prune \\) -o"
}

# Build find command with exclusions from script-specific exclude file
# Usage: build_find_command "/path/to/search" "script-name"
# Returns: Find command string (stdout)
build_find_command() {
    local dir="$1"
    local script_name="$2"
    local prune_expr
    prune_expr=$(build_prune_expr "$script_name" "$dir")

    echo "find \"$dir\" $prune_expr \\( -type f \\( -name \"pubspec.yaml\" -o -name \"pubspec.yml\" \\) -print0 \\)"
}

# ==============================================================================
# DISPLAY UTILITIES
# ==============================================================================

# Spinner animation for long-running operations
# Usage: show_spinner $pid "$padded_name" "$rel_path"
show_spinner() {
    local pid=$1
    local padded_name=$2
    local rel_path=$3
    local spinner=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${BLUE}${spinner[$((i % ${#spinner[@]}))]}${NC} ${BLUE}%s${NC} ${GREY}:%s${NC}" "$padded_name" "$rel_path"
        ((i++))
        sleep 0.1
    done
}

# Convert seconds to human-readable format
# Usage: seconds_to_human 125
# Returns: Human-readable time like "2m 5s" (stdout)
seconds_to_human() {
    local seconds=$1
    if [ -z "$seconds" ] || [ "$seconds" -eq 0 ]; then
        echo "0s"
        return
    fi

    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))

    if [ $hours -gt 0 ]; then
        if [ $minutes -gt 0 ]; then
            echo "${hours}h ${minutes}m"
        else
            echo "${hours}h"
        fi
    elif [ $minutes -gt 0 ]; then
        if [ $secs -gt 0 ]; then
            echo "${minutes}m ${secs}s"
        else
            echo "${minutes}m"
        fi
    else
        echo "${secs}s"
    fi
}

# Convert bytes to human-readable format
# Usage: bytes_to_human 1048576
# Returns: Human-readable size like "1.00 MB" (stdout)
bytes_to_human() {
    local bytes=$1
    if [ -z "$bytes" ] || [ "$bytes" -eq 0 ]; then
        echo "0 B"
        return
    fi

    local kb=$((bytes / 1024))
    local mb=$((kb / 1024))
    local gb=$((mb / 1024))

    if [ $gb -gt 0 ]; then
        awk "BEGIN {printf \"%.2f GB\", $bytes / (1024*1024*1024)}"
    elif [ $mb -gt 0 ]; then
        awk "BEGIN {printf \"%.2f MB\", $bytes / (1024*1024)}"
    elif [ $kb -gt 0 ]; then
        awk "BEGIN {printf \"%.2f KB\", $bytes / 1024}"
    else
        echo "${bytes} B"
    fi
}

# Calculate size of a directory or file
# Usage: calculate_size "/path/to/directory"
# Returns: Size in bytes (stdout)
calculate_size() {
    local path="$1"
    if [ -e "$path" ]; then
        # Use du -sb for accurate byte count (works on macOS and Linux)
        if command -v du >/dev/null 2>&1; then
            # On macOS, du -sb might not work, use du -sk and convert
            if du -sb "$path" >/dev/null 2>&1; then
                du -sb "$path" 2>/dev/null | awk '{print $1}'
            else
                # Fallback: use du -sk (kilobytes) and convert to bytes
                local kb=$(du -sk "$path" 2>/dev/null | awk '{print $1}')
                echo $((kb * 1024))
            fi
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# ==============================================================================
# VALIDATION FUNCTIONS
# ==============================================================================

# Check if a required command is available
# Usage: require_command "flutter" "Flutter"
# Exits with error if command not found
require_command() {
    local cmd="$1"
    local display_name="${2:-$cmd}"

    if ! command -v "$cmd" &> /dev/null; then
        log_error "$display_name is not installed or not in PATH"
        exit 1
    fi
}

# Check if a file is tracked in git
# Usage: is_git_tracked "/path/to/file" "/path/to/project"
# Returns: 0 if tracked, 1 otherwise
is_git_tracked() {
    local file_path="$1"
    local project_dir="$2"

    # Check if project directory is a git repo
    if ! (cd "$project_dir" && git rev-parse --git-dir > /dev/null 2>&1); then
        return 1  # Not a git repo, so file is not tracked
    fi

    # Check if file is tracked in git
    (cd "$project_dir" && git ls-files --error-unmatch "$file_path" > /dev/null 2>&1)
}
