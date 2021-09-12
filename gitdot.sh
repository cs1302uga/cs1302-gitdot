#!/bin/bash
#
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

set -o errexit
set -o pipefail
set -o nounset

readonly STYLE_FONT="fontname=\"Roboto Medium\", fontsize=11"
readonly STYLE_EDGE="color=dimgray"
readonly STYLE_NODE="shape=box, style=filled, color=lightgray, fillcolor=whitesmoke"
readonly STYLE_HEAD="style=filled, color=gold3, fillcolor=gold3, fontcolor=white"
readonly STYLE_BRANCH="style=filled, color=red3, fillcolor=red3, fontcolor=white"

declare -A branches
declare -A commits

# field(LIST)
# Print the fields described by LIST from a space-delimited input string
# constructed from the concatenation of piped input and any remaining
# command-line arguments.
# Usage: cmd | field INDEX        # field INDEX from "$(cmd)"
# Usage: field INDEX ARG...       # field INDEX from "ARG..."
# Usage: cmd | field INDEX ARG... # field INDEX from "$(cmd) ARG..."
function field() {
    local index=$1; shift
    local input=$*
    [[ -p /dev/stdin ]] && local input="$(cat -) $*"
    cat <<<$input | cut -d' ' -f $index
} # field

# git-short-hash()
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

# dot-node(NAME, LABEL[, STYLE])
function dot-node() {
    local name=$1
    local label=$2
    shift 2
    if [[ $# -gt 0 ]]; then
        echo "    ${name} [label=\"${label}\", $*]"
    else
        echo "    ${name} [label=\"${label}\"]"
    fi
} #dot-node

function dot-edge() {
    local node1=$1
    local node2=$2
    shift 2
    if [[ $# -gt 0 ]]; then
        echo "    ${node1} -> ${node2} [$*]"
    else
        echo "    ${node1} -> ${node2}"
    fi
} # dot-edge

function dot-subgraph() {
    local label=$1
    shift
    echo "    subgraph ${label} {"
    echo "        rank=\"same\""
    for node in $@; do
        echo "        ${node}"
    done
    echo "    }"
} # dot-subgraph

function dot-branch-nodes() {
    local i=1
    for branch in $(git-branch-names); do
        branches["b$i"]=$(git-short-hash $branch)
        dot-node "b$i" "$branch" ${STYLE_BRANCH}
        ((i=i+1))
    done
} # dot-branch-nodes

function dot-commit-nodes-and-edges() {
    local i=1
    while read -r line; do
        commit=$(echo $line | field 1)
        commits[$commit]="c$i"
        dot-node "${commits[$commit]}" "$commit"
        if [ $(wc -w <<< $line) -gt 1 ]; then
            parents=$(echo $line | field 2-)
            for parent in $parents; do
                dot-edge "${commits[$commit]}" "${commits[$parent]}"
            done
        fi
        ((i=i+1))
    done < <(git-revs)
} # dot-commit-nodes-and-edges

function dot-branch-edges {
    for branch in "${!branches[@]}"; do
        commit=${branches[${branch}]}
        node=${commits[$commit]}
        dot-edge "$branch" "$node"
        if [ "${commit}" == "$(git-head)" ]; then
            dot-subgraph "${branch}_sub" "${branch}" "${node}" "head"
            dot-edge "head" "${branch}"
        else
            dot-subgraph "${branch}_sub" "${branch}" "${node}"
        fi
    done
} # dot-branch-edges

function dot-digraph {
    cat <<EOF
digraph {
    rankdir=RL
    edge [${STYLE_EDGE}]
    node [${STYLE_NODE}, ${STYLE_FONT}]
    head [label="HEAD", ${STYLE_HEAD}]
EOF
    dot-branch-nodes
    dot-commit-nodes-and-edges
    dot-branch-edges
    cat <<EOF
}
EOF
} # dot-digraph

dot-digraph
