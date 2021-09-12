#!/bin/bash -e
# gitdot - generate a dot digraph of the current Git repository
#
# MIT License
#
# Copyright (c) 2021 Michael E. Cotterell and the University of Georgia. Any
# content or opinions expressed in the source code and documentation for this
# project do not necessarily reflect the views of nor are they endorsed by the
# University of Georgia or the University System of Georgia.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

declare -A branches
declare -A commits
declare -A parents

# first([args])
# Return the first token.
function first() {
    [[ -p /dev/stdin ]] && local args="$(cat -)" || local args=$*
    cat <<<$args | cut -d' ' -f1
} # first

# take(void)
# Return the first 7 characters from standard input.
function git-short-hash() {
    [[ -p /dev/stdin ]] && local args="$(cat -)" || local args=$*
    git rev-parse --short $args
} # git-short-hash

# git-head(void)
# Return the commit hash for HEAD.
function git-head() {
    git-short-hash HEAD
} # git-head

# git-branch-names(void)
# Return a space-delimited list of branch names.
function git-branch-names() {
    git branch --format "%(refname:short)"
} # git-branch-names

# git-revs([args])
# Return all revisions with parents, if applicable.
# Each Line: commit_hash [parent_hash]...
function git-revs() {
    git rev-list --all --parents --reverse | while read -r line; do
        hashes=()
        for arg in $line; do
            hashes+=($(echo $arg | git-short-hash))
        done
        echo "${hashes[@]}"
    done
} # git-revs

HEAD=$(git-head)

cat <<EOF
digraph {
    rankdir=RL
    edge [color=dimgray]
    node [shape=box, style=filled, color=lightgray, fillcolor=whitesmoke, fontname="Roboto Medium", fontsize=11]
    head [label="HEAD", style=filled, color=gold3, fillcolor=gold3, fontcolor=white]
EOF

i=1
for branch in $(git-branch-names); do
    branches["b$i"]=$(git-short-hash $branch)
    echo "    b$i [label=\"$branch\", style=filled, color=red3, fillcolor=red3, fontcolor=white]"
    ((i=i+1))
done

i=1
while read -r line; do
    commit=$(echo $line | first)
    commits[$commit]="c$i"
    echo "    ${commits[$commit]} [label=\"$commit\"]"
    if [ $(wc -w <<< $line) -gt 1 ]; then
        for parent in $(echo $line | cut -d ' ' -f 2-); do
            parents[$commit]=${commits[$parent]}
            echo "    ${commits[$commit]} -> ${parents[$commit]}"
        done
    fi
    ((i=i+1))
done < <(git-revs)

for branch in "${!branches[@]}"; do
    commit=${branches[${branch}]}
    ref=${commits[$commit]}
    echo "    $branch -> $ref"
    echo "    subgraph ${branch}_sub {"
    echo "        rank=\"same\""
    echo "        $branch"
    echo "        $ref"
    if [ "$commit" == "$HEAD" ]; then
        echo "        head"
    fi
    echo "    }"
    if [ "$commit" == "$HEAD" ]; then
        echo "    head -> $branch"
    fi
done

cat <<EOF
}
EOF
