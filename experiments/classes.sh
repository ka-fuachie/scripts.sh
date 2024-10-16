# TODO: Add support for nested classes and objects
# TODO: add support for method aliasing
# TODO: add support for subclassing

declare -A OBJECT_PROPERTIES_REGISTRY
declare -A OBJECT_METHODS_REGISTRY

get_script_functions() {
  local -n function_names="$1"
  declare_output="$(declare -F)"

  local CURRENT_IFS="$IFS"
  IFS=$'\n'
  local list=($declare_output)
  function_names=()
  IFS="$CURRENT_IFS"
  for item in "${list[@]}"; do
    function_names+=("$(echo "$item" | sed -e "s/declare -f \(.\+\)/\1/")")
  done
}

CURRENT_DEFINING_CLASS=""
CURRENT_DECLARE_LIST=()


# ###################
# Main class methods
# ###################

class() {
  local class_name="$1"

  if ! [[ -z "$CURRENT_DEFINING_CLASS" ]];then
    echo "Class definitions cannot be nested" 1>&2
    exit 1
  fi

  CURRENT_DEFINING_CLASS="$class_name"
  get_script_functions CURRENT_DECLARE_LIST
}

end_class() {
  local new_delare_list=
  get_script_functions new_delare_list

  if [[ -z "$CURRENT_DEFINING_CLASS" ]];then
    echo "End class has to be called only after starting a class definition" 1>&2
    exit 1
  fi

  local class_name="$CURRENT_DEFINING_CLASS"
  local class_methods=()

  local is_fn_new=
  for fn in "${new_delare_list[@]}"; do
    for existing_fn in "${CURRENT_DECLARE_LIST[@]}"; do
      if [[ "$fn" == "$existing_fn" ]]; then
        is_fn_new=0
        break
      fi
      is_fn_new=1
    done

    if [[ "$is_fn_new" == 1 ]]; then
      class_methods+=("${fn}")
    fi
  done

  local has_constructor=0
  for method in "${class_methods[@]}"; do
    if [[ "$method" == "$class_name" ]]; then
      has_constructor=1
      break
    fi
    has_constructor=0
  done

  if [[ "$has_constructor" == 0 ]]; then
    echo "Class must have at least a constructor method" 1>&2
    exit 1
  fi

  local -n __class_methods="${class_name}__class_methods"
  __class_methods=("${class_methods[@]}")

  CURRENT_DEFINING_CLASS=""
  CURRENT_DECLARE_LIST=()
}

new() {
  local class_name=$1
  local object_name=$2
  shift;shift
  local args=("$@")

  local -n __class_methods="${class_name}__class_methods"
  if [[ -z "$__class_methods" ]]; then
    echo "Class ${class_name} does not exist" 1>&2
    exit 1;
  fi

  local object_props_var="${object_name}__props"
  declare -Ag "$object_props_var[__proto__.class]=$class_name"

  for method in "${__class_methods[@]}"; do
    if [[ "$method" == "$class_name" ]]; then
      $method "$object_props_var" "${args[@]}"
      break
    fi
  done

  local -n object="$object_name"
  object="$object_props_var"
}

set_prop() {
  local name=$1
  local value=$2
  local object_props_var="$(echo "$name" | sed -e "s/^\([^\.]\+\)\..\+/\1/")"
  local object_prop_name="$(echo "$name" | sed -e "s/^[^\.]\+\.\(.\+\)/\1/")"

  declare -n __object_props="$object_props_var"
  __object_props[$object_prop_name]="$value"
}

get_prop() {
  local name=$1
  local object_props_var="$(echo "$name" | sed -e "s/^\([^\.]\+\)\..\+/\1/")"
  local object_prop_name="$(echo "$name" | sed -e "s/^[^\.]\+\.\(.\+\)/\1/")"

  declare -n __object_props="$object_props_var"
  echo "${__object_props[$object_prop_name]}"
}

call_method() {
  local name=$1

  local object_props_var="$(echo "$name" | sed -e "s/^\([^\.]\+\)\..\+/\1/")"
  local object_method_name="$(echo "$name" | sed -e "s/^[^\.]\+\.\(.\+\)/\1/")"
  shift
  local args=$@

  declare -n __object_props="$object_props_var"
  local object_class="${__object_props[__proto__.class]}" 
  local -n object_class_methods="${object_class}__class_methods"

  local has_method=0
  for method in "${object_class_methods[@]}"; do
    if [[ "$method" == "$object_method_name" ]]; then
      has_method=1
      break
    fi
    has_method=0
  done

  if [[ "$has_method" == 0 ]]; then
    echo "Method ${object_method_name} does not exist on class ${object_class}" 1>&2
    exit 1
  fi

  $object_method_name "$object_props_var" "${args[@]}"
}


# ##############
# Example usage
# ##############

class Person;
  Person() {
    local self=$1
    set_prop "${self}.name" "$2"
    set_prop "${self}.age" "$3"
  }

  info() {
    local self=$1
    local name=$(get_prop "${self}.name")
    local age=$(get_prop "${self}.age")
    echo "Name: $name, Age: $age"
  }
end_class

new Person person1 "John" 25

get_prop "${person1}.name"
get_prop "${person1}.age"
call_method "${person1}.info"

class Student;
  Student() {
    local self="$1"
    set_prop "${self}.name" "$2"
    set_prop "${self}.age" "$3"
  }

  assign() {
    local self="$1"
    local teacher="$2"
    echo "$(get_prop "${self}.name") has been assigned to $(get_prop "${teacher}.name")"
  }
end_class

class Teacher;
  Teacher() {
    local self=$1
    set_prop "${self}.name" "$2"
    set_prop "${self}.age" "$3"
  }
end_class

new Teacher science_teacher "Maxi Boat" "32"
new Student student "Tim Burner" "12"

call_method "${student}.assign" "$science_teacher"
