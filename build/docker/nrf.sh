#!/bin/bash
set -e

verbose=false
continueOnError=false

while getopts ":hvc" option; do
  case $option in
    h) echo "usage: $0 [-h] [-v] [-c] fqbn:keyboard:keymap:target"; exit ;;
    v) verbose=true ;;
    c) continueOnError=true ;;
    ?) echo "error: option -$OPTARG is not implemented"; exit ;;
  esac
done

shift $(($OPTIND - 1))
boardParam=$1

arduinoPath="/usr/share/arduino"

#replace this variable with path to your avr installation
arduinoAvrPath="$arduinoPath/hardware/arduino/avr"
firmwarePath=`readlink -f firmware`
outputPath=`readlink -f output`
outputTempPath="/tmp"
buildPath="${outputTempPath}/.build"
buildCachePath="${outputTempPath}/.build-cache"

sourcePath="${outputTempPath}/.source/firmware"
keyboardsPath="${sourcePath}/keyboards"

successfulBuilds=0
failedBuilds=0

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

arduino_compile() {
  set -e
  local fqbn=$1
  local keyboard=$2
  local keymap=$3
  local target=$4

  printf "$fqbn:$keyboard:$keymap:$target... "

  keymapFile="$keyboardsPath/$keyboard/keymaps/$keymap/keymap.h"
  keymapcppFile="$keyboardsPath/$keyboard/keymaps/$keymap/keymap.cpp"
  configFile="$keyboardsPath/$keyboard/$target/keyboard_config.h"

  cp -f $keymapFile $sourcePath/
  cp -f $keymapcppFile $sourcePath/
  cp -f $configFile $sourcePath/

  if $continueOnError; then
    set +e
  fi

  command=""
  if [ $fqbn = "nrf52832" ]; then
    command="arduino-cli compile -v --fqbn adafruit:nrf52:feather52832 --build-path $buildPath --build-cache-path $buildCachePath $sourcePath/firmware.ino  -o $buildPath/firmware"
  elif [[ $fqbn = "nrf52840" ]]; then
    command="arduino-cli compile -v --fqbn adafruit:nrf52:pca10056:softdevice=s140v6,debug=l0 --build-path $buildPath --build-cache-path $buildCachePath $sourcePath/firmware.ino  -o $buildPath/firmware"
  fi

  if $verbose; then 
    $command
  else
    $command > /dev/null
  fi

  (($? != 0)) && failed=true || failed=false

  set -e

  if $failed; then
    failedBuilds=$((failedBuilds+1))
    printf "${RED}Failed${NC} \n"
  else
    [[ -d $outputPath/$keyboard ]] || mkdir $outputPath/$keyboard
    cp -f $buildPath/firmware.ino.zip $outputPath/$keyboard/$keyboard-$keymap-$target.$fqbn.zip
    cp -f $buildPath/firmware.ino.hex $outputPath/$keyboard/$keyboard-$keymap-$target.$fqbn.hex

    successfulBuilds=$((successfulBuilds+1))
    printf "${GREEN}OK${NC} \n"
  fi
}

printf "\n"
printf -- "-----------------------------------------------------------------------\n"
printf "   Arduino ${BLUE}BlueMicro${NC} Build Script\n"
printf -- "-----------------------------------------------------------------------\n"

selectedFqbn="nrf52832"
selectedKeyboard="all"
selectedKeymap="all"
selectedTarget="all"

if [ -z "$boardParam" ]; then
  printf "\n"
  printf "This script can be run with paramters\n"
  printf "./build-macos [-v] [-c] fqbn:keyboard:keymap:target\n"
  printf "availible fqbns are\n"
  printf "\t * nrf52832\n"
  printf "\t * nrf52840\n"


  printf "\n"
  read -p "Fqbn (eg nrf52832) [nrf52832]: " selectedFqbn
  selectedFqbn=${selectedFqbn:-nrf52832}

  read -p "Keyboard name (eg ErgoTravel) [all]: " selectedKeyboard
  selectedKeyboard=${selectedKeyboard:-all}

  if [ "$selectedKeyboard" != "all" ]; then
    read -p "Keymap name (eg default) [all]: " selectedKeymap
    selectedKeymap=${selectedKeymap:-all}

    if [ "$selectedKeymap" != "all" ]; then
      read -p "Target name (eg left / right / master) [all]: " selectedTarget
      selectedTarget=${selectedTarget:-all}
    fi
  fi
else
  IFS=':' read -r -a boardParamSplit <<< "$boardParam"

  selectedFqbn="${boardParamSplit[0]}"
  if [ -z "$selectedFqbn" ]; then
    selectedFqbn="nrf52832"
  fi

  selectedKeyboard="${boardParamSplit[1]}"
  if [ -z "$selectedKeyboard" ]; then
    selectedKeyboard="all"
  fi

  selectedKeymap="${boardParamSplit[2]}"
  if [ -z "$selectedKeymap" ]; then
    selectedKeymap="all"
  fi

  selectedTarget="${boardParamSplit[3]}"
  if [ -z "$selectedTarget" ]; then
    selectedTarget="all"
  fi
fi

if [[ "$selectedFqbn" -ne "nrf52832" ]] || [[ "$selectedFqbn" -ne "nrf52840" ]]; then
  printf "fqbn must be either 'nrf52832' or 'nrf52840'. You specified '$selectedFqbn'\n"
  exit 1
fi

printf "\n"
printf "Building $selectedFqbn:$selectedKeyboard:$selectedKeymap:$selectedTarget\n"

[[ -d $outputPath ]] || mkdir $outputPath
[[ -d $buildPath ]] || mkdir $buildPath
[[ -d $buildCachePath ]] || mkdir $buildCachePath

printf "\n"
printf "Compiling keyboard:keymap:target  $selectedFqbn \n"
printf -- "-----------------------------------------------------\n"

rm -rf $sourcePath
mkdir -p $sourcePath
cp -r $firmwarePath/* $sourcePath

for keyboard in $sourcePath/keyboards/*/; do
  keyboard=${keyboard%*/}
  keyboard=${keyboard##*/}

  if [ "$selectedKeyboard" != "all" ] && [ "$selectedKeyboard" != "$keyboard" ]; then
    continue
  fi

  keymaps=()
  for keymap in $sourcePath/keyboards/$keyboard/keymaps/*/; do
    keymap=${keymap%*/}
    keymap=${keymap##*/}

    if [ "$selectedKeymap" != "all" ] && [ "$selectedKeymap" != "$keymap" ]; then
      continue
    fi

    keymaps+=($keymap)
  done  

  targets=()
  for target in $sourcePath/keyboards/$keyboard/*/; do
    target=${target%*/}
    target=${target##*/}

    if [[ "$target" == "keymaps" ]]; then
      continue
    fi

    if [ "$selectedTarget" != "all" ] && [ "$selectedTarget" != "$target" ]; then
      continue
    fi

    targets+=($target)
  done

  for keymap in "${keymaps[@]}"; do
    for target in "${targets[@]}"; do
      arduino_compile $selectedFqbn $keyboard $keymap $target
    done
  done
done

if ((successfulBuilds == 0)) && ((failedBuilds == 0)); then
   printf "Did not find anything to build for $selectedKeyboard:$selectedKeymap:$selectedTarget\n"
fi

printf "\n"
printf "$selectedFqbn Successful: ${successfulBuilds} Failed: ${failedBuilds}\n"
printf "\n"
printf "Binaries can be found in ${outputPath}\n"
printf "\n"

if ((failedBuilds != 0 || successfulBuilds == 0)); then
  exit 1
fi

