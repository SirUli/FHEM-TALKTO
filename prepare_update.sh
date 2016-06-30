#!/bin/bash
# Copied and adapted from this repository, thank you: https://github.com/uniqueck/fhem-abfall/blob/master/prepare_update.sh
rm controls_talkto.txt
find ./FHEM -type f \( ! -iname ".*" \) -print0 | while IFS= read -r -d '' f; 
  do
   echo "DEL ${f}" >> controls_talkto.txt
   out="UPD "$(stat -c %y  $f | cut -d. -f1 | awk '{printf "%s_%s",$1,$2}')" "$(stat -c %s $f)" ${f}"
   echo ${out//.\//} >> controls_talkto.txt
done

# CHANGED file
#echo "FHEM TALKTOME and TALKTOUSER last change:" > CHANGED
#echo $(date +"%Y-%m-%d") >> CHANGED
#echo " - $(git log -1 --pretty=%B)" >> CHANGED