#!/usr/bin/zsh
# $1 : Original MH Folder
# $2 : Destination MH Folder (exist or non-exist)

export MH="$2"
if [[ ! -e "$MH" ]]
then
  mkdir "$MH"
fi

find "$1" -type f -name '[0-9]*' | while read i
do
  if [[ "${i:t}" != <->  ]]; then
    print "^^SKIP: ${i}"
    continue
  fi
  print "SORT:: $i"
  maildeliv.localdeliv.rb --nomemo < $i
done
