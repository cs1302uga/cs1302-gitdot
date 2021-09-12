# cs1302-gitdot

```sh
$ git log --all --decorate --oneline --graph
```

```
*   86051d8 (HEAD -> main) Merge branch 'test'
|\
| * 8697605 (test) upate readme again
| * e4b00ee added things
* | e341d0c added stuff
|/
* 53e37a2 adde header to README
* 91cec6b initial commit
```

<img align="center" alt="Example Image Output" src="example.svg">

## Usage

```sh
$ alias gitdot=/path/to/gitdot.sh
```

```
$ gitdot > output.dot
```

If you have [Graphviz](https://graphviz.org/) installed, then you can
generate an image file using the output produced by `gitdot`.

```
$ gitdot | dot -Tsvg > output.svg
```
