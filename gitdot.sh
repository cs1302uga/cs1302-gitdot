#!/usr/bin/env bash
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

declare -A branches # branches[branch_node_name] -> commit_short_hash
declare -A commits  # commits[commit_short_hash] -> commit_node_name

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

# Print the abbreviated (short) SHA-1 hash for a commit HASH.
# Usage: cmd | git-short-hash # short hash for HASH from "$(cmd)"
# Usage: git-short-hash HASH  # short hash for HASH
function git-short-hash() {
    [[ -p /dev/stdin ]] && local args="$(cat -)" || local args=$*
    git rev-parse --short $args
} # git-short-hash

# Print the abbreviated (short) commit hash for HEAD.
# Usage: git-head
function git-head() {
    git-short-hash HEAD
} # git-head

# Print a space-delimited list of branch names.
# Usage: git-branch-names
function git-branch-names() {
    git branch --format "%(refname:short)"
} # git-branch-names

# Print all revisions with parents, if applicable, in chronological order.
# Each line in the output looks like this for some commit:
#
#     commit_hash [parent_hash]...
#
# Usage: git-revs
function git-revs() {
    # Since Git stores its history in reverse chronological order (i.e., the
    # most recent commit is first), we use '--reverse' to get the commits in
    # chronological order.
    git rev-list --all --parents --reverse | while read -r line; do
        hashes=()
        for arg in $line; do
            hashes+=($(echo $arg | git-short-hash))
        done
        echo "${hashes[@]}"
    done
} # git-revs

# Print a dot node named NAME with a specified LABEL. If more arguments are
# provided, then they are treated as one long quoted string and concatenated to
# the node's attribute list.
# Usage: dot-node NAME LABEL
# Usage: dot-node NAME LABEL ATTRIBUTES...
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

# Prints a directed dot edge from NODE1 to NODE2. If more arguments are
# provided, then they are treated as one long quoted string and concatenated to
# the edges's attribute list.
# Usage: dot-edge NODE1 NODE2
# Usage: dot-node NODE1 NODE2 ATTRIBUTES...
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

# Prints a dot subgraph named NAME where all nodes have the same rank.
# Subsequent arguments are assumed to be entries in the subgraph.
# Usage: dot-subgraph NAME ENTRY...
function dot-subgraph() {
    local name=$1
    shift 1
    local entries=$@
    echo "    subgraph ${name} {"
    echo "        rank=\"same\""
    for entry in ${entries}; do
        echo "        ${entry}"
    done
    echo "    }"
} # dot-subgraph

# Prints one dot node for each branch in the current repository.
# Usage: dot-branch-nodes
function dot-branch-nodes() {
    local i=1
    for branch in $(git-branch-names); do
        branches["b$i"]=$(git-short-hash $branch) # save for later
        dot-node "b$i" "$branch" ${STYLE_BRANCH}
        ((i=i+1))
    done
} # dot-branch-nodes

# Prints a dot node for each commit and one dot edge from that commit to each of
# its parents.
# Usage: dot-commit-nodes-and-edges
function dot-commit-nodes-and-edges() {
    local i=1
    while read -r line; do
        local commit_short_hash=$(echo $line | field 1)
        local commit_node_name="c$i"
        commits[$commit_short_hash]=${commit_node_name} # save for later
        dot-node "${commit_node_name}" "$commit_short_hash"
        if [ $(wc -w <<< $line) -gt 1 ]; then
            local parent_hashes=$(echo $line | field 2-)
            for parent_hash in $parent_hashes; do
                local parent_node_name="${commits[$parent_hash]}"
                dot-edge "${commit_node_name}" "${parent_node_name}"
            done
        fi
        ((i=i+1))
    done < <(git-revs)
} # dot-commit-nodes-and-edges

# Print a dot subgraph for each branch that contains relevant nodes and edges.
# This currently assumes that 'dot-branch-nodes' has already been called and
# the 'branches' array has already been populated.
# Usage: dot-branch-edges
function dot-branch-edges() {
    for branch_node_name in "${!branches[@]}"; do
        local commit_short_hash=${branches[${branch_node_name}]}
        local commit_node_name=${commits[${commit_short_hash}]}
        dot-edge "${branch_node_name}" "${commit_node_name}"
        if [ "${commit_short_hash}" == "$(git-head)" ]; then
            dot-subgraph "${branch_node_name}_sub" \
                         "${branch_node_name}" "${commit_node_name}" "head"
            dot-edge "head" "${branch_node_name}"
        else
            dot-subgraph "${branch_node_name}_sub" \
                         "${branch_node_name}" "${commit_node_name}"
        fi
    done
} # dot-branch-edges

# Prints a dot digraph representing the current Git repository.
# Usage: dot-digraph
function dot-digraph() {
    cat <<EOF
digraph {
    bgcolor="transparent"
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

# The designated start of the program.
function main() {
    git status >> /dev/null
    dot-digraph
} # main

main
