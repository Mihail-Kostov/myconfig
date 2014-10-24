#!/usr/bin/env bash
# ----------------------------------------------------------------------
# ${HOME}/.local/etc/profile.d/functions.sh
#   Contains all of the bash functions that will need to be sourced.
#   Environment Function Runtime Configuration
# ----------------------------------------------------------------------
# AUTHOR: Nathaniel Hellabyte
# https://github.com/hellabyte/myconfig
# ======================================================================


# Use awk magic (associative arrays) to remove duplicate paths while
# preserving order
awk_magic() {
  input=${1:-''}
  temp=$(awk 'BEGIN{ORS=RS=":"}{ 
    if ( a[$0] == 0) { 
      print $0; a[$0]++ 
    } 
  }' <<< "$input:" )
  echo ${temp%:*}
}

# Sets the path for the environment. Should only be run once.
# Allows for smooth and consistent executing, paging, and linking
# across heterogeneous systems.
set_path() {
  # Define general array of exe paths ${exe_paths[@]}
  #                         man paths ${man_paths[@]}
  #                         lib paths ${lib_paths[@]}
  #                         inc paths ${inc_paths[@]}
  local H=$HOME
  local A="anaconda/bin"
  local L="${H}/.local"
  local O="openmpi/bin"
  local LO="${L}/opt"
  local exe_paths=(
    "${LO}/${O}" "${LO}/${A}" "${L}/bin" "${L}/sbin" "${H}/bin" 
    "${H}/sbin" "${H}/local/bin" "${H}/local/sbin" "${L}/usr/bin" 
    "${L}/usr/sbin" "${L}/usr/local/bin" "${L}/usr/local/sbin"
    "/usr/local/bin" "/usr/local/sbin" "/usr/bin" "/usr/sbin" "/bin" 
    "/sbin" "/usr/texbin" "/opt/X11/bin" "/usr/bin/X11" "/usr/games" 
    "/Developer/NVIDIA/CUDA-6.0/bin" "/opt/ganglia/bin"
    "/Applications/MATLAB_R2013b.app/bin" "/usr/local/matlab/bin" 
    "/usr/local/maple/bin" "/usr/local/sage" 
    "/usr/local/mathematica/Executables" 
  )
  local mps="local/share/man"
  local lps="local/lib"
  local ips="local/include"
  local man_paths=( 
    "${H}/.${mps}" "${H}/${mps}" "${H}/share/man" "${L}/.local/man" 
    "${H}/local/man" "${H}/.local/usr/share/man" 
    "${H}/local/usr/share/man" "${H}/.local/usr/local/share/man" 
    "${H}/local/usr/local/share/man" "${LO}/anaconda/share/man" 
    "${H}/local/anaconda/share/man" 
  )
  local lib_paths=( 
    "${H}/.${lps}" "${H}/${lps}" "${H}/lib" "${H}/.local/usr/lib" 
    "${H}/.local/usr/local/lib" "${H}/local/usr/lib" 
    "${H}/local/usr/local/lib" 
  )
  local inc_paths=( 
    "${H}/.${ips}" "${H}/${ips}" "${H}/include" 
    "${H}/.local/usr/include" "${H}/.local/usr/local/include" 
    "${H}/local/usr/include" "${H}/local/usr/local/include" 
  )

  OLDXPATH=$PATH             # Archive Old Paths
  OLDMPATH=$MANPATH          #
  OLDLDPATH=$LD_LIBRARY_PATH #
  OLDLPATH=$LIBRARY_PATH     #
  OLDIPATH=$INCLUDE          #
  OLDCPATH=$CPATH            #

  # General helper function for generating path strings
  path_check() {
    dir_list=(${@})
    local collect=''
    for dir in ${dir_list[@]}; do
      [[ -d $dir ]] && collect="${collect}:${dir}" || :
    done
    echo $collect
  }

  local xpath="$(path_check ${exe_paths[@]})"
  local mpath="$(path_check ${man_paths[@]})"
  local ldpth="$(path_check ${lib_paths[@]})"
  local lbpth=$ldpth
  local ipath="$(path_check ${inc_paths[@]})"
  local cpath=$ipath

  # Source system profiles and then intel profiles
  local SYS_PROF='/etc/profile.d'
  if [[ -d SYS_PROF ]]; then
    for f in "${SYS_PROF}/*.sh"; do
      builtin source $f
    done
  fi

  # TODO Determine how intel64 linking affects MIC linking
  local INTEL_PROF='/opt/intel/bin/compilervars.sh'
  local INTEL_ARCH='intel64'
  if [[ -f $INTEL_PROF ]]; then 
    builtin source $INTEL_PROF $INTEL_ARCH 
    local INTEL_MIKE='/opt/intel/mkl/bin/mklvars.sh'
    local INTEL_MARC='mic'
    command -v micnativeloadex &>/dev/null && \
      builtin source $INTEL_MIKE $INTEL_MARC || :
  fi

  # Append old path to new path, remove redundancies, preserve order
  export PATH=$(awk_magic "$xpath:$PATH")
  export CPATH=$(awk_magic "$cpath:$CPATH")
  export INCLUDE=$(awk_magic "$ipath:$INCLUDE")
  export MANPATH=$(awk_magic "$mpath:$MANPATH")
  export LIBRARY_PATH=$(awk_magic "$lbpth:$LIBRARY_PATH")
  export LD_LIBRARY_PATH=$(awk_magic "$ldpth:$LD_LIBRARY_PATH")
  unset xpath mpath ldpth lbpth ipath cpath
}

# Variables for Directory Names
common_dir_init() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    USER_HOME="/Users/${USER}"
    ROOT_HOME="/private/var/root"
  else
    USER_HOME="/home/${USER}"
    ROOT_HOME="/etc/root"
  fi
  DSTACK=( $USER_HOME $ROOT_HOME )
  # Various directories and files 
  DOCDIR="${HOME}/documents"
  INETDIR="${DOCDIR}/various/inet"
  NOTEFILE="${DOCDIR}/various/notes.txt"
  TASKFILE="${DOCDIR}/various/tasks.txt"
  INETGEOFILE="${INETDIR}/geo.xml"
  ! [[ -d $DOCDIR      ]] && mkdir -m 700 $DOCDIR || :
  ! [[ -d $INETDIR     ]] && mkdir -p $INETDIR    || :
  ! [[ -f $NOTEFILE    ]] && touch $NOTEFILE      || :
  ! [[ -f $TASKFILE    ]] && touch $TASKFILE      || :
  ! [[ -f $INETGEOFILE ]] && touch $INETGEOFILE   || :
}

common_dir_init

# Setting PS1 style 
# \033 = \e := Escape -- Escapes next Character; Needed to set color 
#                           Modes
# \e[ ... m\]         -- Escape Nest 
# 38;05;${color}      -- 88/256 Foreground Color No Attribute ${color} 
# 48;05;${color}      -- 88/256 Background Color No Attribute ${color} 
# \[\e[38;05;${color}m\]
#                           38;05;${color} -- 88/256 Foreground Color
#                               
set_prompt() {
  # Main Function sets Prompt Color, Style, Tokens for tmux and default
  # environment
  sc_prompt() {
    # Helper function -- Sets Color for Prompt
    local color=${1:-60} esc=${2:-'\a'} pad=${3:-0} S=' '
    printf "%s%${pad}.s" "\[\033[38;05;${color}m\]${esc}" $S
  }
  local capstr='\[\e[m\]'
  # If in tmux environment, $TMUX is not empty and we set simpler 
  # prompt due to status bar at bottom of window.
  # \t -- 24 hour format HH:MM:SS
  # \h -- ${HOSTNAME%.*}
  # \u -- ${USER}
  # \$ -- $ if nonroot # else
  # \W -- $(basename $PWD) = ${PWD##*/}
  # See more here: 
  # https://wiki.archlinux.org/index.php/Color_Bash_Prompt#Prompt_escapes
  # 88/256 Colors see more here:
  # http://misc.flogisoft.com/bash/tip_colors_and_formatting
  ## 
  # lb_colors -- Light Background Terminal Colors
  # db_colors -- Dark  Background Terminal Colors
  # pe_tokens -- Prompt Escape Tokens
  if [[ -n $TMUX ]]; then
    local lb_colors=( 238 249 37 36 )
    local db_colors=( 236 239 66 243 )
    local pe_tokens=('\t' '\$' '\W' '>' )
    local space=( 0 0 0 0 ) # No padding between prompt objects
  else
    local lb_colors=( 238 243 43 249 37 36 )
    local db_colors=( 236 242 245 243 66 243 )
    local pe_tokens=('\t' '\h' '\u' '\$' '\W' '>' ) 
    local space=( 1 0 0 0 0 0 ) # Padding between time and other objects
  fi
  LIGHTTERM_PS1=''; DARKTERM_PS1=''
  for k in ${!db_colors[@]}; do
    local LTP1[$k]=$( sc_prompt ${lb_colors[$k]} ${pe_tokens[$k]} ${space[$k]} )
    local DTP1[$k]=$( sc_prompt ${db_colors[$k]} ${pe_tokens[$k]} ${space[$k]} )
    LIGHTTERM_PS1=$LIGHTTERM_PS1"${LTP1[$k]}"
    DARKTERM_PS1=$DARKTERM_PS1"${DTP1[$k]}"
  done; unset k
  LIGHTTERM_PS1="${LIGHTTERM_PS1}${capstr}"
  DARKTERM_PS1="${DARKTERM_PS1}${capstr}"
  export LIGHTTERM_PS1; export DARKTERM_PS1
  # TODO  Set either light or dark prompt based on color of terminal 
  #       background.
  # ISSUE Currently assumes dark background
  case ${1-:"dark"} in
    "light")
      export PS1=$LIGHTERM_PS1
      export ITERM_PROFILE="light"
      ;;
    "dark" | : | * | ? )
      export PS1=$DARKTERM_PS1
      export ITERM_PROFILE="dark"
      ;;
  esac
  # PROMPT_COMMAND -- Executes after end of shell evaluation
  #                -- Prints only if previous command had nonzero exit
  export PROMPT_COMMAND='ER=$?; [[ $ER == 0 ]] || ( 
    BSTR="NONZERO EXIT CODE -- WHAT WENT WRONG ->"; 
    ESTR="ERROR CODE -- $ER :("; echo -ne "\033[38;05;167m${BSTR}"; 
    printf "%.0s " $(eval "echo {1..$(($(tput cols)-${#BSTR}-${#ESTR}))}"); 
    echo -e "\033[38;05;203m${ESTR}"; unset ER BSTR ESTR )'
  # TODO Make Less Arbitrary
  export ITERM_PROFILE="dark"
}

alert() {
  local BELL=""
  echo -e $BELL
}

alias_checker() {
  local ALIASCHECK
  local acheck_arr
  local ALIASFILE="${HOME}/.local/etc/profile.d/aliases.sh"
  [[ -f "${ALIASFILE}" ]] && grep 'alias ll=' "${ALIASFILE}" && \
    ALIASCHECK=0 || ALIASCHECK=1
  if [[ $ALIASCHECK -eq 0 ]]; then
    read -a acheck_arr -d '\n' < <(alias)
    [[ ${#acheck_arr[@]} -eq 0 ]] && builtin source "${HOME}/.bash_profile" || :
  fi
}

easy_ip() {
  ping -c 1 google.com &> /dev/null
  if [[ $? -eq 0 ]]; then
    IPADDR_PRI=$(ipconfig getifaddr en0)
    IPADDR_PUB=$(curl -s bot.whatismyipaddress.com)
    echo -e "\033[38;05;23mPublic  IP: ${IPADDR_PUB}"
    echo -e "\033[38;05;30mPrivate IP: ${IPADDR_PRI}"
  else
    echo "No network connection."
  fi
}

easy_ip_geo() {
  # TODO - Create unique XML for every new location.
  # TODO - Parse XML into data type that is better.
  # TODO - Turn into seperate program.
  # TODO - Find ethical use for the data.
  ping -c 1 google.com &> /dev/null
  if [[ $? -eq 0 ]]; then
    [[ -z $IP_ADDR_PUB ]] && easy_ip &> /dev/null
    [[ -d "${INETDIR}" ]] || mkdir "${GEO_DATA_DIR}" &> /dev/null
    local WEBADDR="http://services.ipaddresslabs.com/iplocation/locateip?key=demo&ip="
    local IP_GEO_STR="${WEBADDR}${IPADDR_PUB}"
    echo "Creating xml of ip geo data at ${INETGEOFILE}"
    curl -s "${IP_GEO_STR}" -o "${INETGEOFILE}" &> /dev/null
  else
    echo "No network connection."
  fi
}

geo_ip_info() {
  # Takes ip from command line options and returns xml data generated by ipaddresslabs
  # ping -c 1 google.com &> /dev/null
  # [[ $? -ne 0 ]] && echo "No network connection."; return 1
  local IP_TARGET=${1}
  echo $IP_TARGET
  if [[ -n $IP_TARGET ]]; then
    local WEBADDR="http://services.ipaddresslabs.com/iplocation/locateip?key=demo&ip="
    local IP_GEO_STR="${WEBADDR}${IP_TARGET}"
    curl -s "${IP_GEO_STR}"
  else
    echo "No target provided."
  fi
}

duh() {
  du --si $1 | tail -1
}

now() {
  echo $(date +"%Y.%m.%d-%H.%M.%S")
}

scd() {
  # Nearly as good as quick-cd
  # Also for changing directory to deeper directories
  if [ $# != 1 ]; then
    echo "No input passed."
  else
    [[ -z ${DSTACK[@]} ]] && ( echo "Empty directory stack."; return ) || :
    local null="/dev/null" item="*${1}*" 
    local prc=$(find ${DSTACK[@]} \
      -maxdepth 3 -type d -iname $item 2> $null | sed 1q)
    cd ${prc[0]}
  fi
}

d2h() {
  # Converts decimal input to hex
  python - $@ << __EOF 
from sys import argv 
params = argv[1:]
for arg in params:
  print hex( int( arg ) )
__EOF
}

h2d() {
    # Converts hex to decimal
  python - $@ << __EOF 
from sys import argv 
params = argv[1:]
for arg in params:
  if '0x' in arg:
    val = int( arg, 16 )
  else:
    val = int( '0x{}'.format(arg), 16 )
print val
__EOF
}

h2unicode() {
  # Prints unicode characters
  local count=0
  for j in {128..191}; do 
    for k in {128..191}; do 
      local iHEX="e2"
      local jHEX=$(d2h $j)
      local kHEX=$(d2h $k) 
      local HSTR="\x${iHEX}\x${jHEX}\x${kHEX}"
      local USTR="${iHEX}${jHEX}${kHEX}"
      echo -ne "$HSTR | $USTR   " 
      let count++
      [[ $(( count % 7 )) -eq 0 ]] && echo '' || :
    done
  done
  echo ''
}

task_checker() {
  local TASKCOUNT=$(wc -w $TASKFILE | cut -d ' ' -f 1)
  [[ $TASKCOUNT -ne 0 ]] && echo -e \
    "\033[38;05;168mThere are tasks that need to be completed.\
    \nPlease check $TASKFILE for more info.\033[m"
}

task() {
  # TODO -- Count number of lines in task file, and automatically enumerate.
  local TASKS_APPEND="${@}"
  echo -e $TASKS_APPEND >> $TASKFILE
}

note() { 
  local NOTE_APPEND="${@}"
  echo -e $NOTE_APPEND >> $NOTEFILE
}

# ======================================================================
# Custom man page command that will correctly display man pages.
# Someimtes man only displays a part of man page, thus manual.
manual() {
  local manpage=${1:-""}
  local opts=${2:-""}
  [[ -z $manpage ]] && return || :
  local twidth=$(( $(tput cols) - 5 ))
  local mpath=$( man -w $manpage ) 
  local ext=$( echo ${mpath##*.} )
  local cmd="nroff -man -rLL=${twidth}n"
  local printer="cat"
  [[ $ext =~ 'gz' ]] && local printer="gzip -cd" || :
  $printer $mpath | $cmd | less
}
