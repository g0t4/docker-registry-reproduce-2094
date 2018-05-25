#!/usr/bin/env zsh

# todo tree dump from image snapshots during repro

logmd() {
    echo "$@" | highlight --syntax md -O ansi
}

show_diff(){
    # 02 = no-standout
    logmd "\n## $1 vs $2\n"
    diff --old-group-format=$'\e[0;31m%<\e[0m' \
    --new-group-format=$'\e[0;32m%>\e[0m' \
    --unchanged-group-format=$'\e[0;02m%=\e[0m' \
    temp/${1}.txt temp/${2}.txt
    
}

unset prev_s
# iterate tags which conveniently are already extracted to *.txt files
for s in $(docker image ls --format="{{.Tag}}" reproduce-2094 | sort -h); do
    if [[ -v prev_s ]]; then
        show_diff $prev_s $s
    fi
    prev_s=$s
done