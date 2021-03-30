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

Background(){
  echo "\e[4$(COLOR $1)m"
}

Foreground(){
  echo "\e[3$(COLOR $1)m"
}

Backward(){
  local point=$1
  if (( point >= 1 )); then
    point=$(( point - 1 ))
  fi
  echo $point
}

Foreward(){
  local point=$1
  local limit=$2
  if (( point < limit - 1 )); then
    point=$(( $point + 1 ))
  fi
  echo $point
}

# Layout(){
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

#   return 0
# }

Render(){
  # local panel
  # local layout
  # if (( $focus != $blur )); then
  #   Layout $focus $fg $bg
  # fi

  # if [[ ${handlers[$focus]} == 'FieldHandler' ]]; then
  #   echo -en "$layout${selection[$focus]}$(Mode set cursor)$string"
  # elif [[ ${handlers[$focus]} == 'ButtonHandler' ]]; then
  #   echo -e "$layout${selection[$focus]}"
  #   eval ${handlers[$focus]} $focus $action
  # elif (( $focus != $blur )); then
  #   echo -e "$layout"
  # fi

  return 0
}

Listen(){
  local command
  read -n1 -r input
  case "$input" in
    $'\e') 
      read -n2 -r -t.001 command
      case $command in
        [A) input=UP ;;
        [B) input=DN ;;
        [C) input=RT ;;
        [D) input=LT ;;
         *) input=QU ;;
      esac ;;
    $'\0d') input=EN ;;
    *) input="IN$intent" ;;
  esac
}

Control(){
  local page_focus=${focus[0]}
  local panel_focus=${focus[1]}
  local form_focus=${focus[$panel_focus]}
  local field_focus=${focus[$form_focus]}
  local field_count=${field_counts[$form_focus]}
  local buffer_idx=$(( $field_count + $field_focus ))
  case "$input" in
     UP) (( $page_focus == 0 )) && focus[1]=$(Backward $panel_focus) || focus[$form_focus]=$(Backward $field_focus) ;;
     DN) (( $page_focus == 0 )) && focus[1]=$(Foreward $panel_focus ${#field_counts}) || focus[$form_focus]=$(Foreward $field_focus $field_count) ;;
     LT) focus[0]=$(Backward $page_focus) ;;
     RT) focus[0]=$(Foreward $page_focus 2) ;;
    IN*) options[$buffer_idx]="${input:2}" ;;
     EN) options[$buffer_idx]="" ;;
     QU) Stop ;;
  esac
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
  while [ : ]; do
    Listen
    if (( ${#input} > 0 )); then
      Control
      # Update
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

Stop(){
  Guard
  clear
  exit 0
}


Hud(){
  # delcare -A theme=( 
  #   [fg]=$(Foreground $FG_COLOR)
  #   [bg]=$(Background $BG_COLOR)
  # )
  #   sleep 10
  declare -a focus=(0 0 0 0)
  declare -a field_counts=(3)
  declare -a fields=(field1 field2 field3)
  declare -a options=()
  # Spawn
  Guard
  Render
  Spin
  Stop
}

Hud
