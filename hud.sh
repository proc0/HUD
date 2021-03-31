#!/bin/env bash

# WINDOW
ROWS=44
COLS=88

# PALETTE
FILL_COLOR=blue
FONT_COLOR=white
FORM_COLOR=cyan
PANEL_COLOR=green
SELECT_COLOR=brown
FONT_SELECT_COLOR=black

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
  echo "\e[3$(COLOR $1)m"
}

Decrease(){
  local point=$1
  if (( $point > 0 )); then
    point=$(( $point - 1 ))
  fi
  echo $point
}

Increase(){
  local point=$1
  local limit=$(( $2 - 1 ))
  if (( $point < $limit )); then
    point=$(( $point + 1 ))
  fi
  echo $point
}

Focus(){
  # 2. y=$row
  # 1. x=$column
  echo "\e[$2;$1;H" 
}

Draw(){
#   if (( focus > -1 )); then
#     for i in ${!content[@]}; do
#       if [[ -n ${panels[$i]} ]]; then
#         panel+="${panels[$i]}"
#       fi
#       if (( focus == i )); then
#         output+=${focused[$i]}

#       else
#         output+=${content[$i]}
#       fi
#     done
#   else
#     panel+=${panels[@]}
#     output=${content[@]}
#   fi
#   output="$bg\e[2J$panel$output$fg$bg"
  local fill=${theme['fill']}
  output+="$fill\e[2J$fill"

  return 0
}

Debug(){
  output+="$(Focus 1 1)selected: $selected\nframe: ${focus[0]}\nform: ${focus[1]}\nfield: ${focus[$form_index]}\naction: $action"
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
    *) intent=IN ;;
  esac

  if [[ -n $intent ]]; then
    action=$intent
    change=0
  fi
  return 0
}

Control(){
  local frame=${focus[0]}
  local panel_select=${focus[1]}
  local form_index=$(( $panel_select + 2 ))
  local form_select=${focus[$form_index]}
  local form_count=${#forms[*]}
  local field_count=${field_counts[$panel_select]}
  local selected=$(( ${form_idxs[$panel_select]} + $form_select ))
  local option_value=${option_values[$selected]}
  local input_select=${inputs[$selected]}

  case $action in
    EN) option_values[$selected]="" ;;
    UP)
      case $frame in
        0) focus[1]=$(Decrease $panel_select) ;;
        1) focus[$form_index]=$(Decrease $form_select) ;;
      esac ;;
    DN)
      case $frame in
        0) focus[1]=$(Increase $panel_select $form_count ) ;;
        1) focus[$form_index]=$(Increase $form_select $field_count) ;;
      esac ;;
    TB) (( $frame == 0 )) && focus[0]=1 || focus[0]=0 ;;
    IN) (( $frame == 1 )) && option_values[$selected]="$option_value$input" ;;
  esac

  change=1
  return 0
}

Render(){
  local frame=${focus[0]}
  local panel_select=${focus[1]}
  local form_index=$(( $panel_select + 2 ))
  local form_select=${focus[$form_index]}
  local form_count=${#forms[*]}
  local field_count=${field_counts[$panel_select]}
  local selected=$(( ${form_idxs[$panel_select]} + $form_select ))
  local option_value=${option_values[$selected]}
  local input_select=${inputs[$selected]}

  Draw
  Debug
  echo -en "$output$input_select$option_value"
  return 0
}

Spin(){
  local input=""
  local output=""
  local action=''
  local change=1
  while Listen; do
    if (( $change == 0 )); then
      Control
      Render
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

Core(){
  Render
  Spin
}

Stop(){
  Guard
  clear
  exit 0
}

Hud(){
  declare -a -i focus=(0 0 0)
  declare -a -i form_idxs=(0)
  declare -a -i field_counts=(3)
  declare -a forms=(form1)
  declare -a fields=(field1 field2 field3)
  declare -a inputs=('\e[10;10;H' '\e[1;20;H' '\e[30;1;H')
  declare -a option_values=()

  declare -A theme=( 
    [font]=$(Font $FONT_COLOR)
    [fill]=$(Fill $FILL_COLOR)
  )

  # Spawn
  Guard
  Core
  Stop
}

Hud
