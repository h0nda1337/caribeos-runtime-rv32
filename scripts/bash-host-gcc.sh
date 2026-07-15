#!/usr/bin/env bash
set -e

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
workspace_root=$(CDPATH= cd -- "$project_root/../.." && pwd)
bundled_bin="$workspace_root/msys64/ucrt64/bin"

if [ -d "$bundled_bin" ]; then
    PATH="$bundled_bin:$PATH"
    export PATH
fi

args=()
for arg in "$@"; do
    case "$arg" in
        -rdynamic)
            ;;
        *)
            args+=("$arg")
            ;;
    esac
done

exec gcc -include "$script_dir/bash-host-build-compat.h" "${args[@]}"
