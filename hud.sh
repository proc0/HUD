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

SAMPLE_INPUT="--form1 {text1 text2 text3} --form2 {blah4 blah5 blah6}"
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

# Construction
# ------------

Form(){
  local id=$1
  local field_height=3
  local header_height=3
  local first_col=$(( $x + $w + 10 ))
  local first_row=$(( $y + $field_height ))

  headers+=($(Header $first_col $y $w $id $FORM_FONT_COLOR $FORM_COLOR))
  local r_i
  for r_i in ${!arg_fields[@]}; do
    local row=$(( $r_i*$field_height + $first_row ))
    fields+=($(Field $first_col $row $w ${arg_fields[$r_i]} $FORM_FONT_COLOR $FORM_COLOR))
    fields_select+=($(Field $first_col $row $w ${arg_fields[$r_i]} $FONT_SELECT_COLOR $SELECT_COLOR))
    option_values+=($(Focus $(( $first_col + 1 )) $(( $row + 2 )) ))
  done

}

Spawn(){
  local x=2
  local y=2
  local w=25

  declare -a input_args=($SAMPLE_INPUT)

  declare -a args
  declare -a arg_fields
  local current_field_count
  local form_name=''
  local i_i
  for i_i in ${!input_args[@]}; do
    if [[ ${input_args[$i_i]:0:2} == '--' ]]; then
      local nav_row=$(( ${#focus[*]} + $y - 2 ))
      form_name=${input_args[$i_i]:2}
      focus+=(0)
      navigation+=($(Label $x $nav_row $w $form_name $PANEL_FONT_COLOR $PANEL_COLOR ))
      navigation_select+=($(Label $x $nav_row $w $form_name $FONT_SELECT_COLOR $SELECT_COLOR))
    elif [[ ${input_args[$i_i]:0:1} == "{" ]]; then
      current_field_count=1
      arg_fields=(${input_args[$i_i]:1})
    elif [[ ${input_args[$i_i]: -1} == "}" ]]; then
      arg_fields+=(${input_args[$i_i]:0: -1})
      current_field_count=$(( $current_field_count + 1 ))
      field_counts+=($current_field_count)

      if (( ${#field_counts[*]} > 1 )); then
        local form_idx=0
        local count_i
        for count_i in $(( ${#field_counts[*]} - 1 )); do
          form_idx=$(( $form_idx + ${field_counts[$count_i]} ))
        done
        form_idxs+=($form_idx)
      else
        form_idxs+=(0)
      fi

      Form $form_name
      arg_fields=()
      current_field_count=0
    else
      arg_fields+=(${input_args[$i_i]})
      current_field_count=$(( $current_field_count + 1 ))
    fi
  done
}

# Destructure
# -----------

Draw(){
  local fill=${colors["fill"]}

  local output="\e[2J"
  local form_end=$(( $field_count - $form_select - 1 ))
  local form_top=$(( $selected + 1 ))
  local nav_end=$(( $form_count - $panel_select - 1 ))
  local nav_top=$(( $panel_select + 1 ))

  output+="${navigation[@]:0:$panel_select}"
  output+="${navigation_select[$panel_select]}"
  output+="${navigation[@]:$nav_top:$nav_end}"

  output+="${headers[$panel_select]}"

  if (( $frame == 1 )); then
    if (( $form_select > 0 )); then
      output+="${fields[@]:$form_start:$form_select}$fill${option_values[@]:$form_start:$form_select}"      
    fi
    output+="${fields_select[$selected]}$fill"
    output+="${fields[@]:$form_top:$form_end}$fill${option_values[@]:$form_top:$form_end}"
  else 
    output+="${fields[@]:$form_start:$field_count}$fill${option_values[@]:$form_start:$field_count}"
  fi

  echo -e $output
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
    form_indices: ${form_idxs[@]}"
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

  Draw
  Debug
  echo -en "${colors["font"]}$option_value"
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

# Composition
# -----------

Start(){
  Guard
  Render
  echo -e "$(Resize 44 88)\e%G\e]50;Cascadia Mono\a"
}

Spin(){
  local input=""
  local action=''
  local output=""
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
  # Metadata
  declare -a -i form_idxs=()
  declare -a -i field_counts=()
  # State
  declare -a -i focus=(0 0)
  declare -a option_values=()

  # Output references
  declare -a colors=( 
    ['font']=$(Font $FONT_COLOR)
    ['fill']=$(Fill $FILL_COLOR)
  )
  # Layout
  declare -a headers=()
  declare -a fields=()
  declare -a navigation=()
  declare -a fields_select=()
  declare -a navigation_select=()

  Spawn
  Start
  Spin
  Stop
}

# ----

Hud(){
  Core
}

Hud
