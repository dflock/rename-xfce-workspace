#!/usr/bin/env bash

# Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -o nounset   # Using an undefined variable is fatal
set -o errexit   # A sub-process/shell returning non-zero is fatal
# set -o pipefail  # If a pipeline step fails, the pipelines RC is the RC of the failed step
# set -o xtrace    # Output a complete trace of all bash actions; uncomment for debugging

# IFS=$'\n\t'  # Only split strings on newlines & tabs, not spaces.

function init() {
  readonly script_path="${BASH_SOURCE[0]:-$0}"
  readonly script_dir="$(dirname "$(readlink -f "$script_path")")"
  readonly script_name="$(basename "$script_path")"
  
  # Get the names of all the workspaces
  ws_names=()
  while read name; do
    ws_names+=("$name")
  done < <(xfconf-query -c xfwm4 -p /general/workspace_names | tail -n +3)

  # Get current workspace details from wmctrl
  current_ws_idx=$(wmctrl -d | grep '*' | cut -d " " -f1)

  verbose=false

  setup_colors
  parse_params "$@"
}

usage() {
  cat <<EOF

Rename the current Xfce workspace.

It takes no arguments, instead it opens a dialog box.

Requirements:

1) wmctrl (tested with 1.07)
2) zenity (tested with 3.6.0)

${bld}USAGE${off}
  $script_name

${bld}OPTIONS${off}
  -h, --help       show this help
  -v, --verbose    show verbose/debug output

EOF
  exit
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    # Control sequences for fancy colours
    readonly bld="$(tput bold 2> /dev/null || true)"
    readonly off="$(tput sgr0 2> /dev/null || true)"
  else
    readonly bld=''
    readonly off=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

vmsg() {
  if [ "$verbose" = "true" ]; then
    msg "$@"
  fi
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

function parse_params() {
  local param
  while [[ $# -gt 0 ]]; do
    param="$1"
    shift
    case $param in
      -h | --help | help)
        usage
        ;;        
      *)
        die "Invalid parameter: $param" 1
        ;;
    esac
  done
}

init "$@"

if ! command -v zenity &> /dev/null
then
  die "zenity could not be found\n\
    $script_name requires zenity (tested with 3.32.0)\n\
    See: https://help.gnome.org/users/zenity/" 127
fi

if ! command -v wmctrl &> /dev/null
then
  die "wmctrl could not be found\n\
    $script_name requires wmctrl (tested with 1.07)\n\
    See: https://www.freedesktop.org/wiki/Software/wmctrl/" 127
fi

# Get new workspace name via zenity
new_name=$(zenity --entry --title="Rename workspace" \
    --text="Rename workspace $((current_ws_idx + 1))" --entry-text="${ws_names[$curnt_ws_idx]}")

# Overwrite current workspace name
xfconf_cmd="xfconf-query -c xfwm4 -p /general/workspace_names"
for i in "${!ws_names[@]}"; do
    if [[ $i == "$current_ws_idx" && $new_name ]]; then
        xfconf_cmd+=" -s \"$new_name\""
    else
        xfconf_cmd+=" -s \"${ws_names[$i]}\""
    fi
done
eval "$xfconf_cmd"
