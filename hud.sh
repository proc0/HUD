#!/usr/bin/env bash
#!/usr/local/Cellar/bash/5.1.4/bin/bash
#!/bin/bash

# --------
# Settings
# --------

# COLORS
FILL_COLOR=black
FONT_COLOR=white
FORM_COLOR=green
FORM_FONT_COLOR=white
PANEL_COLOR=brown
PANEL_FONT_COLOR=white
SELECT_COLOR=blue
FONT_SELECT_COLOR=white

SAMPLE_INPUT='load --commit="git add -A . && git commit -m (message: default option, option 1, {echo blah}) && git push (origin) (blah)" --echo="echo charles (hi,bye) && echo (haha,hihi)"'
ERROR_INPUT='load asoa soaisi'

# Codification
# ------------

COLOR(){
  case $1 in
    black) echo 0 ;;
      red) echo 1 ;;
    green) echo 2 ;;
    brown) echo 3 ;;
     blue) echo 4 ;;
    lilac) echo 5 ;;
     cyan) echo 6 ;;
    white) echo 7 ;;
        *) echo 9 ;;
  esac
}

CODE(){
  case $1 in
    insert) echo 4  ;;
    invert) echo 7  ;;
    cursor) echo 25 ;;
    revert) echo 27 ;;
    *)      echo 0  ;;
  esac
}

# Infrastructure
# --------------
Usage(){
  echo -e "hahaha"
  return 0
}

ParseField(){
  case "$1" in
    '(') field_flag=0 ;;
    ')') field_flag=1;
        this_command+="{field${#form_fields[*]}}";
        this_field_count=$(( $this_field_count + 1 ));
        form_fields+=("field${#form_fields[*]}");
        user_values+=("$user_value");
        user_value='' ;;
    *) if (( $field_flag == 0 )); then
          case "$1" in
            ',') user_values+=("$user_value");
                user_value='' ;;
            *) user_value+="$1" ;;
          esac
        else
          this_command+="$1"
        fi ;;
  esac
  return 0
}

ParseForm(){
  local form_string="$1"
  local form_string_length=$(( ${#form_string} - 1 ))
  local field_flag=1
  local this_command=""
  local last_command=''
  local user_value=''
  local last_field=''
  local this_field_count=0

  local string_index=0
  for string_index in $(seq 0 $form_string_length); do
    ParseField "${form_string:$string_index:1}"
  done

  if (( ${#field_starts[*]} > 0 )); then
    local form_idx=0
    local count_i
    for count_i in ${!field_starts[@]}; do
      form_idx=$(( $form_idx + ${field_starts[$count_i]} ))
    done
    field_starts+=($(( $form_idx + $this_field_count + 1 )))
  else
    field_starts+=(0)
  fi
  field_counts+=($this_field_count)
  form_commands+=("$this_command")
  return 0
}

Parse(){
  local token="$1"
  case ${token:0:2} in
    '--')
      local name="${token%%=*}"
      form_names+=("${name:2}")
      ParseForm "${token##*=}" 
      return 0 ;;
    '-'*) 
      case "${token:1}" in
        d) debug=0; return 0 ;;
        *) return 2 ;;
      esac ;;
    *) return 1 ;;
  esac
  return 2
}

Initialize(){
  case $1 in 
    load)
      local status=2
      while (( $# > 1 )); do
        shift
        Parse "$1";
        status=$?
      done
      return $status ;;
    clear) return 0 ;;
    help|*) Usage && Stop ;;
  esac
  return 2
}

Guard(){
  if [[ -n $OFS ]]; then
    IFS=$OFS
  else
    OFS=$IFS
    IFS=''
  fi

  if [[ -n $OTTY ]]; then
    stty $OTTY
    OTTY=
  else
    OTTY=$(stty -g)
    stty sane min 0 time 0
  fi
}

Resize(){
  local win_h=$1
  local win_w=$2
  local win_code

  if [[ -n $win_h && -n $win_w ]]; then
    win_code="\e[8;$win_h;$win_w;t\e[1;$win_h;r"
    echo $win_code
  else
    local pos
    printf "\e[13t" > /dev/tty
    IFS=';' read -r -d t -a pos

    local xpos=${pos[1]}
    local ypos=${pos[2]}

    printf "\e[14;2t" > /dev/tty
    IFS=';' read -r -d t -a size

    local hsize=${size[1]}
    local wsize=${size[2]}

    win_code="\e[8;$hsize;$wsize;t\e[1;$win_h;r"
    echo $win_code
  fi
}

Mode(){
  local toggle=$1
  local code=$2
  local mode

  if [[ $toggle == 'set' ]]; then
    mode=h
  elif [[ $toggle == 'reset' ]]; then
    mode=l
  fi

  echo "\e[?$(CODE $code)$mode" 
}

Fill(){
  echo "\e[4$(COLOR $1)m"
}

Stroke(){
  echo "\e[9$(COLOR $1)m"
}

Decrease(){
  # 1. position
  if (( $1 > 0 )); then
    echo $(( $1 - 1 ))
  else 
    echo $1
  fi
}

Increase(){
  # 1. position
  # 2. limit
  if (( $1 < $2 - 1 )); then
    echo $(( $1 + 1 ))
  else 
    echo $1
  fi
}

Focus(){
  # 1. x: column
  # 2. y: row
  echo "\e[$2;$1;H" 
}

# Decomposition
# -------------

Text(){
  # 1. column
  # 2. row
  # 3. text
  # 4. color
  echo "$(Focus $1 $2)$(Stroke $4)$3"
}

Box(){
  # 1. column
  # 2. row
  # 3. width
  # 4. height
  # 5. fill
  local sect=1
  local box="$(Focus $1 $2)$(Fill $5)"
  for sect in $( seq 1 $4 ); do 
    box+="$(Focus $1 $(( $2 + $sect )))\e[$3;@"
  done
  echo $box
}

Label(){
  # 1. column
  # 2. row
  # 3. width
  # 4. text
  # 5. color
  # 6. fill
  local start=$(Box $1 $2 1 1 $6)
  local text=$(Text $(( $1 + 1 )) $(($2 + 1)) "$4" $5)
  local end=$(Box $(( $1 + ${#4} + 1 )) $2 $(( $3 - ${#4} - 1 )) 1 $6)
  echo "$start$text$end"
}

Field(){
  # 1. column
  # 2. row
  # 3. width
  # 4. text
  # 5. color
  # 6. fill
  local label=$(Label $1 $2 $3 "$4" $5 $6)
  local start=$(Box $1 $(( $2 + 1 )) 1 1 $6)
  local field=$(Box $(( $1 + 1 )) $(( $2 + 1 )) $(( $3 - 2 )) 1 0)
  local end=$(Box $(( $1 + $3 - 1 )) $(( $2 + 1 )) 1 1 $6)
  local cap=$(Box $1 $(( $2 + 2 )) $3 1 $6)
  echo "$label$start$field$end$cap"
}

Header(){
  local form_name=$(Label $1 $2 $3 "$4" $5 $6)
  local padding=$(Box $1 $(( $2 + 1 )) $3 2 $6)
  echo "$form_name$padding"
}

# Construction
# ------------

Form(){
  local field_height=3
  local left_padding=10
  local form_x=$(( $x + $width + $left_padding ))

  headers+=($(Header $form_x $y $width "$1" $FORM_FONT_COLOR $FORM_COLOR))
  local field_y=$(( $field_height + $y ))
  local field_index=$first_index
  for field_index in $( seq $first_index $form_field_count ); do
    local row_index=$(( $row_index + 1 ))
    if (( $row_index > 0 )); then
      field_y=$(( $row_index*$field_height + $y ))
    fi
    fields+=($(Field $form_x $field_y $width "${form_fields[$field_index]}" $FORM_FONT_COLOR $FORM_COLOR))
    fields_select+=($(Field $form_x $field_y $width "${form_fields[$field_index]}" $FONT_SELECT_COLOR $SELECT_COLOR))
    option_values+=($(Focus $(( $form_x + 1 )) $(( $field_y + 2 )) ))
  done
}

Spawn(){
  local x=2
  local y=2
  local width=25

  local name_index
  for name_index in ${!form_names[@]}; do
    local form_name=${form_names[$name_index]}
    local navigation_y=$(( ${#focus[*]} + $y - 2 ))
    local first_index=${field_starts[$name_index]}
    local form_field_count=$(( $first_index + ${field_counts[$name_index]} - 1 ))
    focus+=(0)
    navigation+=($(Label $x $navigation_y $width "$form_name" $PANEL_FONT_COLOR $PANEL_COLOR ))
    navigation_select+=($(Label $x $navigation_y $width "$form_name" $FONT_SELECT_COLOR $SELECT_COLOR))
    Form "$form_name"
  done
}

# Destructure
# -----------

Debug(){
  if [[ $1 == 0 ]]; then
    echo -e "$(Focus 1 15)\n\
      form_indices: ${field_starts[@]}\n\
      form_names: ${form_names[@]}\n\
      form_field_counts: ${field_counts[@]}\n\
      form_commands: ${form_commands[@]}\n\
      form_fields: ${form_fields[@]}\n\
      user_values: ${user_values[@]}\n";
    sleep 35;
    exit 0;
  else
    output+="$(Focus 1 15)\n\
      action: $action\n\
      frame: $frame\n\
      form: $form_select\n\
      field: $field_select\n\
      form_count: $form_count\n\
      form_command: ${form_commands[$form_select]}\n\
      field_count: $field_count\n\
      field_start: $field_start\n\
      selected: $selected\n";
  fi
  return 0
}

Draw(){
  output="\e[2J"
  local form_end_count=$(( $field_count - $field_select - 1 ))
  local selected_next=$(( $selected + 1 ))
  local nav_end=$(( $form_count - $form_select - 1 ))
  local nav_top=$(( $form_select + 1 ))

  output+="${navigation[@]:0:$form_select}${navigation_select[$form_select]}${navigation[@]:$nav_top:$nav_end}${headers[$form_select]}"

  if (( $frame == 1 )); then
    output+="${fields[@]:$field_start:$field_select}${fields_select[$selected]}$fill_color${option_values[@]:$field_start:$field_select}"
    output+="${fields[@]:$selected_next:$form_end_count}$fill_color${option_values[@]:$selected_next:$form_end_count}"
  else 
    output+="${fields[@]:$field_start:$field_count}$fill_color${option_values[@]:$field_start:$field_count}"
  fi

  return 0
}

Render(){
  local frame=${focus[0]}
  local form_select=${focus[1]}
  local form_index=$(( $form_select + 2 ))
  local field_select=${focus[$form_index]}
  local form_count=${#navigation[*]}
  local field_count=${field_counts[$form_select]}
  local field_start=${field_starts[$form_select]}
  local selected=$(( $field_start + $field_select ))
  local option_value="${option_values[$selected]}"

  Draw
  (( $debug == 0 )) && Debug
  case $action in
    UP|DN|TB) echo -e "$output" ;;&
    IN|BS) echo -e "$output" ;;&
    *) echo -en "$font_color$option_value"
  esac

  return 0
}

# Interaction
# ------------

Control(){
  local frame=${focus[0]}
  local form_select=${focus[1]}
  local form_index=$(( $form_select + 2 ))
  local field_select=${focus[$form_index]}
  local form_count=${#navigation[*]}
  local field_count=${field_counts[$form_select]}
  local field_start=${field_starts[$form_select]}
  local selected=$(( $field_start + $field_select ))
  local option_value="${option_values[$selected]}"

  case $action in
    EN) 
      eval ${form_commands[$form_select]}
      return 0 ;;
    UP)
      case $frame in
        0) focus[1]=$(Decrease $form_select) ;;
        1) focus[$form_index]=$(Decrease $field_select) ;;
      esac
      return 0 ;;
    DN)
      case $frame in
        0) focus[1]=$(Increase $form_select $form_count ) ;;
        1) focus[$form_index]=$(Increase $field_select $field_count) ;;
      esac
      return 0 ;;
    BS) 
      local opt_len=${#option_value}
      local opt_end=$(( $opt_len - 1 ))
      (( $frame == 1 && $opt_len > 0 )) && option_values[$selected]="${option_values[$selected]:0:$opt_end}";
      return 0 ;;
    TB) 
      (( $frame == 0 )) && focus[0]=1 || focus[0]=0;
      return 0 ;;
    IN)
      (( $frame == 1 && $field_select < $field_count )) && option_values[$selected]="$option_value$input";
      return 0 ;;
    *) return 1 ;;
  esac

  return 1
}

Listen(){
  local intent
  local opcode

  read -n1 -r input
  case "$input" in
    $'\e') 
      read -n2 -r -t.001 opcode
      case $opcode in
        [A) intent=UP ;;
        [B) intent=DN ;;
        [C) intent=RT ;;
        [D) intent=LT ;;
        *) return 1 ;;
      esac ;;
    $'\0d') intent=EN ;;
    $'\t') intent=TB ;;
    $'\177') intent=BS ;;
    *) intent=IN ;;
  esac

  action=$intent
  return 0
}

# Composition
# -----------

Start(){
  Render
  echo -e "$(Resize 44 88)\e%G\e]50;Cascadia Mono\a$output"
}

Spin(){
  local input=""
  local action=''
  local output=""

  local font_color=$(Stroke $FONT_COLOR)
  local fill_color=$(Fill $FILL_COLOR)

  Start
  while Listen; do
    if Control; then
      Render
    fi
  done
  return 0
}

Stop(){
  Guard
  clear
  exit 0
}

Core(){
  # State
  declare -a -i focus=(0 0)
  declare -a option_values=()

  # Layout
  declare -a navigation=()
  declare -a headers=()
  declare -a fields=()
  declare -a fields_select=()
  declare -a navigation_select=()

  Spawn
  Guard
  Spin
  Stop
}

# ----

Hud(){
  local debug=1
  # Argument Data
  declare -a form_names=()
  declare -a form_commands=()
  declare -a form_fields=()
  declare -a user_values=()
  # Metadata
  declare -a -i field_starts=()
  declare -a -i field_counts=()

  Initialize "$@" || Debug $debug
  Core
}

Hud load -d --commit="git add -A . && git commit -m (message: default option, option 1, {echo blah}) && git push (origin) (blah)" --echo="echo charles (hi,bye) && echo (haha,hihi)"
 