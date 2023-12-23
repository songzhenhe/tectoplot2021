# tectoplot
# bashscripts/args_cleanup.sh
# Copyright (c) 2021 Kyle Bradley, all rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its contributors
#    may be used to endorse or promote products derived from this software without
#    specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## Argument processing, data management, and cleanup routines

################################################################################
# Messaging and debugging routines


# Returns true if argument is empty or starts with a hyphen but is not a float;
# else returns false. Not sure this is the best way to code this test... bash...
# if arg_is_flag "${1}"; then ... ; fi

function arg_is_flag() {
  if ! arg_is_float "${1}"; then
    [[ ${1:0:1} == [-] || -z ${1} ]] && return
  else
    [[ 1 -eq 0 ]] && return
  fi
}

# Returns true if argument is a (optionally signed, optionally decimal) number
function arg_is_float() {
  [[ "${1}" =~ ^[+-]?([0-9]+\.?|[0-9]*\.[0-9]+)$ ]]
}

# Returns true if argument is a (optionally signed, optionally decimal) positive number
function arg_is_positive_float() {
  [[ "${1}" =~ ^[+]?([0-9]+\.?|[0-9]*\.[0-9]+)$ ]]
}

# Report the number of arguments remaining before the next flag argument
# Assumes the first argument in ${@} is current flag (eg -xyz) and ignores it
# num_left=$(number_nonflag_args "${@}")
function number_nonflag_args() {
  THESE_ARGS=("${@}")
  for index_a in $(seq 2 ${#THESE_ARGS[@]}); do
    if arg_is_flag "${THESE_ARGS[$index_a]}"; then
      break
    fi
  done
  echo $(( index_a - 1 ))
}

function error_msg() {
  printf "%s[%s]: %s\n" "${BASH_SOURCE[1]##*/}" ${BASH_LINENO[0]} "${@}" > /dev/stderr
  exit 1
}

function info_msg() {
  if [[ $narrateflag -eq 1 ]]; then
    printf "TECTOPLOT %05s: " ${BASH_LINENO[0]}
    printf "%s\n" "${@}"
  fi
  printf "TECTOPLOT %05s: " ${BASH_LINENO[0]} >> "${INFO_MSG}"
  printf "%s\n" "${@}" >> "${INFO_MSG}"
}

# Return the full path to a file or directory
function abs_path() {
    if [ -d "${1}" ]; then
        (cd "${1}"; echo "$(pwd)/")
    elif [ -f "${1}" ]; then
        if [[ $1 = /* ]]; then
            echo "${1}"
        elif [[ $1 == */* ]]; then
            echo "$(cd "${1%/*}"; pwd)/${1##*/}"
        else
            echo "$(pwd)/$1"
        fi
    elif [[ $1 =~ TEMP/* ]]; then
      echo "${FULL_TMP}"/"${1##*/}"
    fi
}


# Return the full path to the directory containing a file, or the directory itself
function abs_dir() {
    if [ -d "${1}" ]; then
        (cd "${1}"; echo "$(pwd)/")
    elif [ -f "${1}" ]; then
        if [[ $1 == */* ]]; then
            echo "$(cd "${1%/*}"; pwd)/"
        else
            echo "$(pwd)/"
        fi
    fi
}

# Exit cleanup code from Mitch Frazier
# https://www.linuxjournal.com/content/use-bash-trap-statement-cleanup-temporary-files

function cleanup_on_exit()
{
      for i in "${on_exit_items[@]}"; do
        if [[ $CLEANUP_FILES -eq 1 ]]; then
          info_msg "rm -f $i"
          rm -f "${i}"
        else
          info_msg "Not cleaning up file $i"
        fi
      done
}

function move_on_exit()
{
      for i in "${on_exit_move_items[@]}"; do
        if [[ -d ${OUTPUTDIRECTORY} ]]; then
          info_msg "mv $i ${OUTPUTDIRECTORY}"
          mv $i ${OUTPUTDIRECTORY}
        else
          info_msg "Not moving file $i"
        fi
      done
}
# Be sure to only cleanup files that are in the temporary directory
function cleanup()
{
    local n=${#on_exit_items[*]}
    on_exit_items[$n]="$*"
    if [[ $n -eq 0 ]]; then
        info_msg "Setting EXIT trap function cleanup_on_exit()"
        trap cleanup_on_exit EXIT
    fi
}

# Be sure to only cleanup files that are in the temporary directory
function move_exit()
{
    local n=${#on_exit_move_items[*]}
    on_exit_move_items[$n]="$*"
    if [[ $n -eq 0 ]]; then
        info_msg "Setting EXIT trap function move_on_exit()"
        trap move_on_exit EXIT
    fi
}

function is_gmt_cpt () {
  gawk < "${GMTCPTS}" -v id="${1}" 'BEGIN{res=0} ($1==id) {res=1; exit} END {print res}'
}
