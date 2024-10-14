#! /bin/bash

# essential utils from path.sh
if [[ -z "$IS_PATH_LOADED" ]]; then
  is_url_path() {
    [[ $1 =~ ^https?:// ]]
  }

  is_absolute_path() {
    is_url_path "$1" || [[ $1 == /* ]]
  }

  resolve_path() {
    local path1="$1"
    local path2="$2"
    if [[ "$path2" == /* ]]; then
      echo "$path2"
      return
    elif is_url_path "$path2"; then
      echo "$path2"
      return
    fi

    local CURRENT_IFS="$IFS"
    IFS="/"
    local path="${*}"
    IFS="$CURRENT_IFS"

    if [[ "$path" == /* ]]; then
      echo "$path"
    elif is_url_path "$path"; then
      echo "$path"
    else
      echo "$(cd "$(dirname "$path")" && pwd)/$(basename "$path")"
    fi
  }

  get_path_dir() {
    dirname "$(resolve_path "$1")"
  }

  SCRIPT_PATH="$(echo "$(cd "$(dirname "${BASH_SOURCE[-1]}")" && pwd)"/"$(basename "${BASH_SOURCE[-1]}")")"
fi

# ###############
# import-tool.sh
# ###############

if [[ -z "$IS_IMPORT_TOOL_LOADED" ]]; then
  IS_IMPORT_TOOL_LOADED=1
  IMPORTED_PATHS=()
  IMPORT_PATH="$SCRIPT_PATH"
  MODULE_IMPORT_BASE_PATH="$HOME/.import-tool-modules"
  declare -A MODULE_IMPORT_NAMESPACES
fi

assert_exists() {
  local value="$1"
  if [[ -z "$value" ]]; then exit 1; fi
}

add_import_namespace() {
  local namespace="$1"
  local transform="$2"
  MODULE_IMPORT_NAMESPACES["$namespace"]="$transform"
}

is_namespaced_path() { [[ "$1" =~ ^[^:]+:[^/] ]]; }
get_namespaced_path_namespace() { echo "$1" | sed -e "s/^\([^:]\+\):.*/\1/"; }
get_namespaced_path_path() { echo "$1" | sed -e "s/^[^:]\+:\(.\+\)$/\1/"; }

get_transformed_namespaced_path() {
  local namespaced_path="$1"
  if ! is_namespaced_path "$namespaced_path"; then
    echo "Invalid namespaced path ${namespaced_path}" 1>&2
    return 1
  fi

  local namespace="$(get_namespaced_path_namespace "$namespaced_path")"
  local path="$(get_namespaced_path_path "$namespaced_path")"
  local transform="${MODULE_IMPORT_NAMESPACES["$namespace"]}"
  if [[ -z "$transform" ]]; then
    echo "No transform found for namespace ${namespace}" 1>&2
    return 1
  fi

  echo "$("$transform" "$namespace" "$path")"
}

resolve_module_path() {
  local module_path="$1"
  if is_namespaced_path "$module_path"; then
    local namespace="$(get_namespaced_path_namespace "$module_path")"
    local path=/"$(get_namespaced_path_path "$module_path")"
    local resolved_path="$(resolve_path "$(get_path_dir "$IMPORT_PATH")" "$path")"
    echo "${namespace}:${resolved_path#/}"
  elif ! is_url_path "$module_path" && [[ "$module_path" =~ ^[^:]+:/ ]]; then
    echo "Invalid namespaced path ${module_path}" 1>&2
    return 1
  else
    echo "$(resolve_path "$(get_path_dir "$IMPORT_PATH")" "$module_path")"
  fi
}

get_module_local_import_path() {
  local module_import_path="$1"
  local processed_module_import_path=

  if is_namespaced_path "$module_import_path"; then
    processed_module_import_path="$module_import_path"
  elif is_url_path "$module_import_path"; then
    processed_module_import_path="$(echo "$module_import_path" | sed -e 's/\/\///')"
  else
    echo "Cannot get local import path for ${module_import_path}" 1>&2
    return 1
  fi

  echo "$(resolve_path "$MODULE_IMPORT_BASE_PATH" "$processed_module_import_path")"
}

load_module() {
  local module_import_path="$1"
  local module_local_import_path="$2"

  local script="$(curl -sf "$module_import_path")"
  if [[ -z "$script" ]]; then
    echo "Failed to load module ${module_import_path}" 1>&2
    exit 1
  fi

  mkdir -p "$(get_path_dir "$module_local_import_path")"
  echo "$script" > "$module_local_import_path"
  chmod +x "$module_local_import_path"
}

import_module() {
  local module_import_path="$1"
  local module_local_import_path="$2"
  if [[ -z "$module_local_import_path" ]]; then
    module_local_import_path="$module_import_path"
  fi

  local current_import_path="$IMPORT_PATH"
  IMPORT_PATH="$module_import_path"
  IMPORTED_PATHS+=($module_import_path)
  source "$module_local_import_path"

  if [[ "$?" -ne 0 ]]; then
    echo "Failed to import ${IMPORT_PATH}" 1>&2
    exit 1
  fi

  IMPORT_PATH="$current_import_path"
}

import() {
  local import_path="$1"
  resolved_import_path="$(resolve_module_path "$import_path")"
  assert_exists "$resolved_import_path"

  for path in "${IMPORTED_PATHS[@]}"; do
    if [[ "$path" == "$resolved_import_path" ]]; then
      return
    fi
  done

  if is_url_path "$resolved_import_path"; then
    local module_local_import_path="$(get_module_local_import_path "$resolved_import_path")"
    assert_exists "$module_local_import_path"

    if ! [[ -e "$module_local_import_path" ]]; then
      load_module "$resolved_import_path" "$module_local_import_path"
    fi

    import_module "$resolved_import_path" "$module_local_import_path"
  elif is_namespaced_path "$resolved_import_path"; then
    local module_local_import_path="$(get_module_local_import_path "$resolved_import_path")"
    assert_exists "$module_local_import_path"

    if ! [[ -e "$module_local_import_path" ]]; then
      local transformed_import_path="$(get_transformed_namespaced_path "$resolved_import_path")"
      assert_exists "$transformed_import_path"
      load_module "$transformed_import_path" "$module_local_import_path"
    fi

    import_module "$resolved_import_path" "$module_local_import_path"
  else
    import_module "$resolved_import_path"
  fi 
}

get_github_namespace_url() {
  local namespace="$1"
  local path="$2"
  echo "$(resolve_path "https://cdn.jsdelivr.net/gh" "$path")"
}
add_import_namespace "github" get_github_namespace_url

if [[ -z "$IS_PATH_LOADED" ]]; then
  IS_PATH_LOADED=1
  import "github:ka-fuachie/scripts.sh/utils/path.sh"
fi
