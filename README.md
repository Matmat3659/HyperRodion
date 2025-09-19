# HyperRodion/Rodya

Random codes I made because I am bored, some useful, some just for fun.
The name comes from or inspired by the benchmarking tool hyperfine made in rust, thats where hyper is from, Rodion/Rodya on the other hand is from a character in Limbus company Rodion, or Rod from Nimrod

## Contents

- `hyperrodion.nim` — main project, probably not the only one!
- `extras/` — extras and random stuff
- `LICENSE` — MIT License for my code and third party stuff

---

## Usage

hyperrodion is simple, used for benchmark, like
```
./hyperrodion ls
```
doing this will make hyperrodion bench and run the command ls 10 times or more set by -t, just run ./hyperrodion for its help or -h
quick warning, if you are going to bench cp(copy) like "cp bigfile somewhere", then be aware hyperrodion wont delete that

```bash
# Example: compile hyperrodion
nim c -d:release hyperrodion.nim
```
## REQUIREMENTS
nim, ofcourse, currently this project is mostly on Nim(or Nimrod), and c/cpp compiler
