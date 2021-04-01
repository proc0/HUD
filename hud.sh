#!/bin/env bash

# --------
# Settings
# --------

# COLORS
FILL_COLOR=black
FONT_COLOR=white
FORM_COLOR=green
FORM_FONT_COLOR=white
PANEL_COLOR=blue
PANEL_FONT_COLOR=white
SELECT_COLOR=brown
FONT_SELECT_COLOR=black

# --------------
# Terminal Codes
# --------------

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

# --------------
# Infrastructure
# --------------

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

# ------------
# Constructure
# ------------

Text(){
  # 1. column
  # 2. row
  # 3. text
  # 4. color
  echo "$(Font $4)$(Focus $1 $2)$3"
}

Box(){
  # 1. column
  # 2. row
  # 3. width
  # 4. height
  # 5. fill
  local box=$(Fill $5)
  for y in $( seq 1 $4 ); do 
    box+="$(Focus $1 $(( $2 + $y )))\e[$3;@"
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
  local text=$(Text $(( $1 + 1 )) $(($2 + 1)) $4 $5)
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
  local label=$(Label $1 $2 $3 $4 $5 $6)
  local start=$(Box $1 $(( $2 + 1 )) 1 1 $6)
  local field=$(Box $(( $1 + 1 )) $(( $2 + 1 )) $(( $3 - 2 )) 1 $FILL_COLOR)
  local end=$(Box $(( $1 + $3 - 1 )) $(( $2 + 1 )) 1 1 $6)
  local cap=$(Box $1 $(( $2 + 2 )) $3 1 $6)
  fields+=("$label$start$field$end$cap")
}

Column(){
  local kind=$1
  # row = x + field h
  local row=5
  local col=$(( $x + $w + 10 ))
  for i in ${!members[@]}; do
    row=$(( $i*3 + 5 ))
    case $kind in
      nav) Button $col $row $w ${members[$i]} $FORM_FONT_COLOR $FORM_COLOR ;;
      form) Field $col $row $w ${members[$i]} $FORM_FONT_COLOR $FORM_COLOR ;;
    esac
    inputs+=($(Focus $(( $col + 1 )) $(( $row + 2 )) ))
  done
}

Form(){
  local id=$1
  declare -a members=($2)
  
  forms+=($id)
  navigation+=($(Label $x $y $w $id $PANEL_FONT_COLOR $PANEL_COLOR ))
  Column 'form'
  field_counts+=(${#members[*]})
  form_idxs+=(0)
}

Spawn(){
  local x=2
  local y=2
  local w=25

  Form myForm 'field1 field2 field3'
}

# -----------
# Destructure
# -----------

Draw(){
  local fill=${colors['fill']}

  output+="$fill\e[2J${navigation[@]}"
  for i in ${!fields[@]}; do
    output+=${fields[$i]}
  done
  output+="$fill"

  return 0
}

Debug(){
  output+="$(Focus 1 1)selected: $selected\nframe: ${focus[0]}\nform: ${focus[1]}\nfield: ${focus[$form_index]}\naction: $action"
}

Render(){
  local font_color=${colors['font']}
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
  # Debug
  echo -en "$output$input_select$font_color$option_value"
  return 0
}

# ------------
# Interaction
# ------------

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

  action=$intent
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
    TB) 
      (( $frame == 0 )) && focus[0]=1 || focus[0]=0;
      return 0 ;;
    IN)
      (( $frame == 1 )) && option_values[$selected]="$option_value$input";
      return 0 ;;
    *) return 1
  esac

  return 1
}

# -----------------
#       Main
# -----------------

Spin(){
  local input=""
  local action=''
  local output=""
  while Listen; do
    Control && Render
  done
  return 0
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
  declare -a forms=()
  # Info
  declare -a -i form_idxs=()
  declare -a -i field_counts=()
  declare -a inputs=()
  # State
  declare -a -i focus=(0 0 0)
  declare -a option_values=()
  # Output
  declare -A colors=( 
    [font]=$(Font $FONT_COLOR)
    [fill]=$(Fill $FILL_COLOR)
  )
  # Layout
  declare -a navigation=()
  declare -a fields=()

  Spawn
  Guard
  Core
  Stop
}

Hud
