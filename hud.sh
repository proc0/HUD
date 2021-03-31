#!/bin/env bash

# WINDOW
ROWS=44
COLS=88

# PALETTE
BG_COLOR=black
FG_COLOR=white
FORM_COLOR=blue
FORM_FOCUS_COLOR=cyan
FORM_FONT_COLOR=white
FORM_FONT_FOCUS_COLOR=black

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

Mode(){
  local toggle=$1
  local code=$2
  local mode

  if [[ $toggle == '' || $toggle == 'set' ]]; then
    mode=h
  elif [[ $toggle == 'reset' ]]; then
    mode=l
  fi

  echo "\e[?$(CODE $code)$mode" 
}

Background(){
  echo "\e[4$(COLOR $1)m"
}

Foreground(){
  echo "\e[3$(COLOR $1)m"
}

Backward(){
  local point=$1
  if (( $point > 0 )); then
    point=$(( point - 1 ))
  fi
  echo $point
}

Foreward(){
  local point=$1
  local limit=$(( $2 - 1 ))
  if (( $point < $limit )); then
    point=$(( point + 1 ))
  fi
  echo $point
}

Focus(){
  local x=$1
  local y=$2
  echo "\e[$y;$x;H" 
}

Layout(){
#   if (( focus > -1 )); then
#     for i in ${!content[@]}; do
#       if [[ -n ${panels[$i]} ]]; then
#         panel+="${panels[$i]}"
#       fi
#       if (( focus == i )); then
#         layout+=${focused[$i]}

#       else
#         layout+=${content[$i]}
#       fi
#     done
#   else
#     panel+=${panels[@]}
#     layout=${content[@]}
#   fi
#   layout="$bg\e[2J$panel$layout$fg$bg"
  layout+="\e[2J"

#   return 0
}

Debug(){
  layout+="$(Focus 1 1)pointer: $buffer_idx\nframe: ${focus[0]}\nform: ${focus[1]}\nfield: ${focus[$current_form_idx]}"
}

Listen(){
  local command
  read -n1 -r input
  case "$input" in
    $'\e') 
      read -n2 -r -t.001 command
      case $command in
        [A) action=UP ;;
        [B) action=DN ;;
        [C) action=RT ;;
        [D) action=LT ;;
         *) action=QU ;;
      esac ;;
    $'\0d') action=EN ;;
    $'\t') action=TB ;;
    *) action=IN ;;
  esac
}

Control(){
  local page_focus=${focus[0]}
  local panel_focus=${focus[1]}
  local current_form_idx=$(( $panel_focus + 2 ))
  local form_focus=${focus[$current_form_idx]}
  local form_count=${#forms[*]}
  local field_count=${field_counts[$panel_focus]}
  local buffer_idx=$(( ${form_idxs[$panel_focus]} + $form_focus ))
  local option_text=${options[$buffer_idx]}
  local current_focus=${inputs[$buffer_idx]}
  case $action in
    UP)
      case $page_focus in
        0) focus[1]=$(Backward $panel_focus) ;;
        1) focus[$current_form_idx]=$(Backward $form_focus) ;;
      esac ;;
    DN)
      case $page_focus in
        0) focus[1]=$(Foreward $panel_focus $form_count ) ;;
        1) focus[$current_form_idx]=$(Foreward $form_focus $field_count) ;;
      esac ;;    
    # LT) focus[0]=$(Backward $page_focus) ;;
    # RT) focus[0]=$(Foreward $page_focus 2) ;;
    TB) (( $page_focus == 0 )) && focus[0]=1 || focus[0]=0 ;;
    IN) (( $page_focus == 1 )) && options[$buffer_idx]="$option_text$input" ;;
    EN) options[$buffer_idx]="" ;;
    QU) Stop ;;
  esac
}

Render(){
  # local panel
  local layout=""
  local page_focus=${focus[0]}
  local panel_focus=${focus[1]}
  local current_form_idx=$(( $panel_focus + 2 ))
  local form_focus=${focus[$current_form_idx]}
  local form_count=${#forms[*]}
  local field_count=${field_counts[$panel_focus]}
  local buffer_idx=$(( ${form_idxs[$panel_focus]} + $form_focus ))
  local option_text=${options[$buffer_idx]}
  local current_focus=${inputs[$buffer_idx]}
  # if (( $focus != $blur )); then
  Layout
  Debug
  # fi
  echo -en "$layout$current_focus$option_text"

  # if [[ ${handlers[$focus]} == 'FieldHandler' ]]; then
  #   echo -en "$layout${selection[$focus]}$(Mode set cursor)$string"
  # elif [[ ${handlers[$focus]} == 'ButtonHandler' ]]; then
  #   echo -e "$layout${selection[$focus]}"
  #   eval ${handlers[$focus]} $focus $action
  # elif (( $focus != $blur )); then
    # echo -e "$layout"
  # fi

  return 0
}

# Update(){
#   case $action in
#     -2) buffer="${input:2}";
#         string+="$buffer" ;;
#     -3) string="" ;;
#     -9) break ;;
#      *) blur=$focus; focus=$action ;;
#   esac
# }
Spin(){
  local input=""
  local action=''

  while [ : ]; do
    Listen
    if (( ${#input} > 0 )); then

      Control
      Render
      # Update
    fi
  done

  return 0
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
  fi
}

Stop(){
  Guard
  clear
  exit 0
}

Core(){
  # delcare -A theme=( 
  #   [fg]=$(Foreground $FG_COLOR)
  #   [bg]=$(Background $BG_COLOR)
  # )
  #   sleep 10

  Render
  Spin
}

Hud(){
  declare -a -i focus=(0 0 0)
  declare -a -i form_idxs=(0)
  declare -a -i field_counts=(3)
  declare -a forms=(form1)
  declare -a fields=(field1 field2 field3)
  declare -a inputs=('\e[10;10;H' '\e[1;20;H' '\e[30;1;H')
  declare -a options=()

  # Spawn
  Guard
  Core
  Stop
}

Hud
