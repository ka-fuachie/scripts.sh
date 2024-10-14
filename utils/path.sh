#! /bin/bash

is_url_path() {
  [[ $1 =~ ^https?:// ]]
}

is_absolute_path() {
  is_url_path || [[ $1 == /* ]]
}

split_text() {
  local TEXT="$1"
  local DELIMETER="$2"
  local -n ARR="$3"
  local CURRENT_IFS=$IFS
  IFS="$DELIMETER"

  ARR=(${TEXT[@]})

  IFS="$CURRENT_IFS"
}

strip_trailing_slash() { echo "${1%/}"; }
strip_leading_slash() { echo "${1#/}"; }

resolve_path() {
  local base_path=
  local resolved_path=

  local current_path=
  local previous_resolved_path=
  local previous_base_path=

  for path in "$@"; do
    current_path="$path"

    if [[ "$path" =~ ^/ ]]; then
      base_path="/"
      previous_base_path="$base_path"
    elif is_url_path "$path"; then
      previous_base_path="$base_path"
      base_path="$(echo "$path" | sed -e "s/\(https\?:\/\/[^\/]\+\/\?\).*/\1/")"
      local temp_path=/"$(echo "$path" | sed -e "s/\(https\?:\/\/[^\/]\+\/\?\)//")"
      path="$temp_path"
    fi

    split_text "$path" "/" path_list
    for item in "${path_list[@]}"; do
      if [[ -z "$item" ]]; then
        resolved_path="/"
      elif [[ "$item" == "." ]]; then
        resolved_path="$resolved_path"
      elif [[ "$item" == ".." ]]; then
        if ! [[ $resolved_path =~ /[^/]+/?$ ]]; then
          if [[ -z "$base_path" ]]; then
            current_path="$(strip_trailing_slash "$base_path")"/"$(strip_leading_slash "$current_path")"
          elif [[ -z "$previous_base_path" ]]; then
            previous_resolved_path="$(strip_trailing_slash "$base_path")"/"$(strip_leading_slash "$previous_resolved_path")"
          fi
          echo -e "Failed to resolve path \"${current_path}\" from \"${previous_resolved_path}\" " 1>&2
          return 1
        fi
        resolved_path="$(strip_trailing_slash "$(echo "$resolved_path" | sed -e "s/\/[^\/]\+\/\?$//")")"/
      else
        resolved_path="$(strip_trailing_slash "$resolved_path")"/"${item}"
      fi
    done

    previous_resolved_path="$resolved_path"
  done

  if ! [[ -z "$base_path" ]]; then
    resolved_path="$(strip_trailing_slash "$base_path")"/"$(strip_leading_slash "$resolved_path")"
  fi
  echo $resolved_path
}

get_path_dir() {
  local base_path=
  local path="$(resolve_path "$1")"
  local path_dir=

  if is_url_path "$path"; then
    base_path="$(echo "$path" | sed -e "s/\(https\?:\/\/[^\/]\+\/\?\).*/\1/")"
    path="$(echo "$path" | sed -e "s/\(https\?:\/\/[^\/]\+\/\?\)//")"
  elif is_absolute_path; then
    base_path="/"
  fi

  if ! [[ "$path" =~ /[^/]+/?$ ]]; then
    if ! [[ -z "$base_path" ]]; then
      path="$(strip_trailing_slash "$base_path")"/"$(strip_leading_slash "$path")"
    fi
    echo -e "Failed to get directory of path \"${path}\"" 1>&2
    return 1
  fi

  path_dir="$(echo "$path" | sed -e "s/\/[^\/]\+\/\?$//")"

  if ! [[ -z "$base_path" ]]; then
    path_dir="$(strip_trailing_slash "$base_path")"/"$(strip_leading_slash "$path_dir")"
  fi

  echo "$path_dir"
}

SCRIPT_PATH="${BASH_SOURCE[-1]}"
if ! is_absolute_path "$SCRIPT_PATH"; then
  SCRIPT_PATH="$(resolve_path "$PWD" "$SCRIPT_PATH")"
fi
