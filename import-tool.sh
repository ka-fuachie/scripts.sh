#! /bin/bash

# essential utils from path.sh
is_url_path() {
  [[ $1 =~ ^https?:// ]]
}

is_absolute_path() {
  is_url_path "$1" || [[ $1 == /* ]]
}

resolve_path() {
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
# end of essential utils from path.sh

# ###############
# import-tool.sh
# ###############

if [[ -z "$IS_IMPORT_TOOL_LOADED" ]]; then
  IS_IMPORT_TOOL_LOADED=1
  IMPORTED_PATHS=()
  IMPORT_PATH="$SCRIPT_PATH"
  MODULE_IMPORT_PATH="$HOME/.import-tool-modules"
fi

import() {
  local import_path="$1"
  local resolved_import_path="$(resolve_path "$(get_path_dir "$IMPORT_PATH")" "$import_path")"

  for path in "${IMPORTED_PATHS[@]}"; do
    if [[ "$path" == "$resolved_import_path" ]]; then
      return
    fi
  done

  if is_url_path "$resolved_import_path"; then
    local module_local_import_path="$(echo "$resolved_import_path" | sed -e 's/\/\///')"
    module_local_import_path="$(resolve_path "$MODULE_IMPORT_PATH" "$module_local_import_path")"

    if ! [[ -e "$module_local_import_path" ]]; then
      local script="$(curl -sf "$resolved_import_path")"
      if [[ -z "$script" ]]; then
        echo "Failed to fetch ${resolved_import_path}" 1>&2
        exit 1
      fi

      mkdir -p "$(get_path_dir "$module_local_import_path")"
      echo "$script" > "$module_local_import_path"
      chmod +x "$module_local_import_path"
    fi

    current_import_path="$IMPORT_PATH"
    IMPORT_PATH="$resolved_import_path"
    IMPORTED_PATHS+=($IMPORT_PATH)
    source "$module_local_import_path"

    if [[ "$?" -ne 0 ]]; then
      echo "Failed to import ${IMPORT_PATH}" 1>&2
      exit 1
    fi

    IMPORT_PATH="$current_import_path"
  else
    current_import_path="$IMPORT_PATH"
    IMPORT_PATH="$resolved_import_path"
    IMPORTED_PATHS+=($IMPORT_PATH)
    source "$IMPORT_PATH"

    if [[ "$?" -ne 0 ]]; then
      echo "Failed to import ${IMPORT_PATH}" 1>&2
      exit 1
    fi

    IMPORT_PATH="$current_import_path"
  fi 
}

if [[ -z "$IS_PATH_LOADED" ]]; then
  IS_PATH_LOADED=1
  _IMPORT_PATH="$IMPORT_PATH"
  # Set import path as if it was imported from a URL
  # Not very robust, will change later
  IMPORT_PATH="https://cdn.jsdelivr.net/gh/ka-fuachie/scripts.sh/import-tool.sh"
  import "utils/path.sh"
  IMPORT_PATH="$_IMPORT_PATH"
fi
