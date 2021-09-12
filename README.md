# cs1302-gitdot

```
*   86051d8 (HEAD -> main) Merge branch 'stuff-and-things'
|\
| * 8697605 (test) upate readme again
| * e4b00ee added things
* | e341d0c added stuff
|/
* 53e37a2 adde header to README
* 91cec6b initial commit
```

| Node   | Label     | Parents    |
|--------|-----------|------------|
| `c1`   | `91cec6b` |            |
| `c2`   | `53e37a2` | `c1`       |
| `c3`   | `e341d0c` | `c2`       |
| `c4`   | `e4b00ee` | `c2`       |
| `c5`   | `8697605` | `c3`       |
| `c6`   | `86051d8` | `c3`, `c5` |
| `b1`   | `main`    | `c6`       |
| `b2`   | `test     | `c5`       |
| 'head` | `HEAD`    | `b1`       |

```dot
digraph {
    rankdir=RL
    edge [color=dimgray]
    node [shape=box, style=filled, color=lightgray, fillcolor=whitesmoke, fontname="Roboto Medium", fontsize=11]
    head [label="HEAD", style=filled, color=gold3, fillcolor=gold3, fontcolor=white]
    b1 [label="main", style=filled, color=red3, fillcolor=red3, fontcolor=white]
    b2 [label="test", style=filled, color=red3, fillcolor=red3, fontcolor=white]
    c1 [label="91cec6b"]
    c2 [label="53e37a2"]
    c2 -> c1
    c3 [label="e341d0c"]
    c3 -> c2
    c4 [label="e4b00ee"]
    c4 -> c2
    c5 [label="8697605"]
    c5 -> c4
    c6 [label="86051d8"]
    c6 -> c3
    c6 -> c5
    b2 -> c5
    subgraph b2_sub {
        rank="same"
        b2
        c5
    }
    b1 -> c6
    subgraph b1_sub {
        rank="same"
        b1
        c6
        head
    }
    head -> b1
}
```
