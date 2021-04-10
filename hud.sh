#!/usr/bin/env bash
#!/bin/bash
#!/usr/local/Cellar/bash/5.1.4/bin/bash

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

# SAMPLE_INPUT="--form1 {text1 text2 text3} --form2 {blah4 blah5 blah6}"
SAMPLE_INPUT='load --commit="git add -A . && git commit -m (message: default option, option 1, {echo blah}) && git push" --echo="echo charles (hi,bye)"'
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
}

ParseFields(){
  local term=$1
  # case ${term:0:1} in
  #   '(') ;;
  #   ')') ;;
  #   *) form_commands[$current_form]+=($term) ;;
  # esac
}

Parse(){
  local token="$1"
  local len=$(( ${#token} - 1))
  local ti=0
  local processing_flag=1
  local form_command=""
  local last_command=''
  local curr_command=''
  local curr_field=''
  local last_field=''
  local curr_field_count=0
  declare -a curr_fields=()
  for ti in $(seq 0 $len); do
    local t="${token:$ti:1}"
    case "$t" in
      '(') processing_flag=0; curr_fields=() ;;
      ')') processing_flag=1; form_command+=" {field${#form_args[*]}} "; curr_field_count=$(( $curr_field_count + 1 )); form_args+=("field${#form_args[*]}"); form_defaults+=("$curr_field"); curr_field='' ;;
      *)
        if (( $processing_flag == 0 )); then
          case "$t" in
            ',') curr_fields+=("$curr_field"); form_defaults+=("$curr_field"); curr_field='' ;;
            *) curr_field+="$t" ;;
          esac
        else
          form_command+="$t"
        fi ;;
    esac
  done 
  if (( ${#form_idxs[*]} > 0 )); then
    local form_idx=0
    local count_i
    for count_i in ${!form_idxs[@]}; do
      form_idx=$(( $form_idx + $curr_field_count - 1 ))
    done
    form_idxs+=($form_idx)
  else
    form_idxs+=(0)
  fi
  field_counts+=($curr_field_count)
  form_commands+=("$form_command")
  return 0
}

ParseForm(){
  local token="$1"
  case ${token:0:2} in
    '--')
      local name=${token%%=*}
      form_names+=(${name:2})
      Parse "${token##*=}" 
      return 0 ;;
    *) return 1 ;;
  esac
  return 2
}

Initialize(){
  local comm=$1
  case $comm in 
    help) Usage && Stop ;;
    load)
      local ret=2
      while (( $# > 1 )); do
        shift
        ParseForm "$1";
        ret=$?
      done
      return $ret ;;
    clear) return 0 ;;
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
    # ssty erase ^?
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

Font(){
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
  echo "$(Focus $1 $2)$(Font $4)$3"
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
  local form_name=$(Label $1 $2 $3 $4 $5 $6)
  local padding=$(Box $1 $(( $2 + 1 )) $3 2 $6)
  echo "$form_name$padding"
}

Button(){
  echo $(Label $1 $2 $3 "$4" $5 $6)
}

# Construction
# ------------

Form(){
  local id=$1
  local field_height=3
  local header_height=3
  local first_col=$(( $x + $w + 10 ))
  # local first_row=$(( $y + $field_height ))

  headers+=($(Header $first_col $y $w $id $FORM_FONT_COLOR $FORM_COLOR))
  local r_i=$fst
  local row=$(( $field_height + $y ))
  local cur_idx=0
  for r_i in $( seq $fst $fse ); do
    cur_idx=$(( $r_i - $fst ))
    if (( $cur_idx == 0 )); then
      row=$(( $field_height + $y ))
    else
      row=$(( $cur_idx*$field_height + $y ))
    fi
    fields+=($(Field $first_col $row $w "${form_args[$r_i]}" $FORM_FONT_COLOR $FORM_COLOR))
    fields_select+=($(Field $first_col $row $w "${form_args[$r_i]}" $FONT_SELECT_COLOR $SELECT_COLOR))
    option_values+=($(Focus $(( $first_col + 1 )) $(( $row + 2 )) ))
  done
  # if (( ${#form_args[*]} > 0 )); then
  #   cur_idx=$(( $cur_idx + 1 ))
  # fi
  # row=$(( $cur_idx*$field_height + $y ))
  # buttons+=($(Button $first_col $row $w 'Run_Command' $FORM_FONT_COLOR $FORM_COLOR))
  # button_selects+=($(Button $first_col $row $w 'Run_Command' $FONT_SELECT_COLOR $SELECT_COLOR))
  # option_values+=($(Focus $first_col $(( $row + $field_height )) ))

}

Spawn(){
  local x=2
  local y=2
  local w=25

  local n
  for n in ${!form_names[@]}; do
    local form_name=${form_names[$n]}
    local nav_row=$(( ${#focus[*]} + $y - 2 ))
    local fst=${form_idxs[$n]}
    local fse=$(( $form_idx + ${field_counts[$n]} + 1 ))
    focus+=(0)
    navigation+=($(Label $x $nav_row $w $form_name $PANEL_FONT_COLOR $PANEL_COLOR ))
    navigation_select+=($(Label $x $nav_row $w $form_name $FONT_SELECT_COLOR $SELECT_COLOR))
    Form $form_name
  done
}

# Destructure
# -----------

Draw(){
  local fill=${colors["fill"]}

  output="\e[2J"
  local form_end_count=$(( $field_count - $form_select - 1 ))
  local form_bottom_start=$(( $selected + 1 ))
  local nav_end=$(( $form_count - $panel_select - 1 ))
  local nav_top=$(( $panel_select + 1 ))
  # local opt_end=$(( $form_end_count - 1 ))

  output+="${navigation[@]:0:$panel_select}"
  output+="${navigation_select[$panel_select]}"
  output+="${navigation[@]:$nav_top:$nav_end}"

  output+="${headers[$panel_select]}"
  if (( $frame == 1 )); then

    output+="${fields[@]:$form_start:$form_select}${fields_select[$selected]}"
    output+="${fields[@]:$form_bottom_start:$form_end_count}$fill${option_values[@]:$form_bottom_start:$form_end_count}"

  else 
    output+="${fields[@]:$form_start:$field_count}$fill${option_values[@]:$form_start:$field_count}"
  fi
}

Debug(){
  echo -e "$(Focus 1 15)\n\
    action: $action\n\
    frame: $frame\n\
    form: $panel_select\n\
    field: $form_select\n\
    form_count: $form_count\n\
    field_count: $field_count\n\
    form_start: $form_start\n\
    selected: $selected\n\
    option_values: $( echo ${option_values[@]} )\n"

    # form_indices: ${form_idxs[@]}\n\
    # form_names: ${form_names[@]}\n\
    # form_field_counts: ${field_counts[@]}\n\
    # form_commands: ${form_commands[@]}\n\
    # form_defaults: ${form_defaults[@]}\n\
    # form_args: ${form_args[@]}"
  # sleep 15 && exit 0
}

Render(){
  local frame=${focus[0]}
  local panel_select=${focus[1]}
  local form_index=$(( $panel_select + 2 ))
  local form_select=${focus[$form_index]}
  local form_count=${#navigation[*]}
  local field_count=${field_counts[$panel_select]}
  local form_start=${form_idxs[$panel_select]}
  local selected=$(( $form_start + $form_select ))
  local option_value=${option_values[$selected]}

  case $action in
    IN|BS) Draw && echo -e "$output" ;;
    UP|DN|TB) Draw && echo -e "$output" ;;
    *) echo -en "${colors["font"]}$option_value"
  esac

  return 0
}

# Interaction
# ------------

Control(){
  local frame=${focus[0]}
  local panel_select=${focus[1]}
  local form_index=$(( $panel_select + 2 ))
  local form_select=${focus[$form_index]}
  local form_count=${#navigation[*]}
  local field_count=${field_counts[$panel_select]}
  local form_start=${form_idxs[$panel_select]}
  local selected=$(( $form_start + $form_select ))
  local option_value=${option_values[$selected]}

  case $action in
    EN) 
      option_values[$selected]="";
      return 0 ;;
    UP)
      case $frame in
        0) focus[1]=$(Decrease $panel_select) ;;
        1) focus[$form_index]=$(Decrease $form_select) ;;
      esac
      return 0 ;;
    DN)
      case $frame in
        0) focus[1]=$(Increase $panel_select $form_count ) ;;
        1) focus[$form_index]=$(Increase $form_select $field_count) ;;
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
      (( $frame == 1 && $form_select < $field_count )) && option_values[$selected]="$option_value$input";
      return 0 ;;
    *) return 1
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
  Guard
  echo -e "$(Resize 44 88)\e%G\e]50;Cascadia Mono\a"
}

Spin(){
  local input=""
  local action=''
  local output=""

  while Listen; do
    if Control; then
      Render
      if (( $debug == 0 )); then
        Debug
      fi
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
  local debug=0
  # State
  declare -a -i focus=(0 0)
  declare -a option_values=()

  # Output references
  declare -a colors=( 
    ['font']=$(Font $FONT_COLOR)
    ['fill']=$(Fill $FILL_COLOR)
  )
  # Layout
  declare -a navigation=()
  declare -a headers=()
  declare -a fields=()
  declare -a buttons=()
  declare -a fields_select=()
  declare -a buttons_select=()
  declare -a navigation_select=()

  Spawn
  Start
  Spin
  Stop
}

# ----

Hud(){

  declare -a form_names=()
  declare -a form_commands=()
  declare -a form_args=()
  declare -a form_defaults=()
  # Metadata
  declare -a -i form_idxs=()
  declare -a -i field_counts=()

  Initialize "$@"
  Core
}

Hud load --commit="git add -A . && git commit -m (message: default option, option 1, {echo blah}) && git push" --echo="echo charles (hi,bye) && echo (haha,hihi)"
 