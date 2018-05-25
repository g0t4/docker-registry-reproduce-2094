#!/bin/sh

# todo tree dump from image snapshots during repro

show_diff(){
    # 02 = no-standout
    diff --old-group-format=$'\e[0;31m%<\e[0m' \
    --new-group-format=$'\e[0;32m%>\e[0m' \
    --unchanged-group-format=$'\e[0;02m%=\e[0m' \
    $1 $2 
}

unset prev_s
# iterate tags which conveniently are already extracted to *.txt files
for s in $(docker image ls --format="{{.Tag}}" reproduce-2094 | sort -h); do
    if [[ -v prev_s ]]; then
        show_diff temp/${prev_s}.txt temp/${s}.txt
    fi
    prev_s=$s
done