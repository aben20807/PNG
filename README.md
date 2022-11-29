# PNG's Not Go

Interesting go-like compiler modified from my college assignment

Compile go-like language to Java bytecode and run the executable in JVM

Note: Please write the homework yourself: [Build a Simple Compiler](https://aben20807.github.io/series/build-a-simple-compiler/)

## Features

The compiler has following features (tests/input/):

+ arithmetic: `in01_arithmetic.png`
+ precedence: `in02_precedence.png`
+ scope: `in03_scope.png`
+ assignment: `in04_assignment.png`
+ conversion between int and float: `in05_conversion.png`
+ if condition: `in06_if.png`
+ for loop: `in07_for.png`
+ declaration without explicit type: `in17_advanced_declaration.png`
+ simple 1D array: `in12_array.png`, `in15_advanced_array.png`, `in16_advanced_array2.png`
+ function define and function call: `in10_function.png`
+ switch case: `in11_switch.png`
+ nested if condition and for loop: `in13_nested_ifelse_for.png`
+ Error handle
  + type: `in08_type_error.png`
  + variable redeclaration, undefined: `in09_variable_error.png`
  + function redeclaration: `in14_function_redeclare_error.png`

## Build & Run

```bash
$ git clone https://github.com/aben20807/PNG.git
$ cd PNG/
$ git submodule update --init --recursive

$ make
$ ./bin/png_compiler < tests/input/in01_arithmetic.png
$ java -jar 3rdparty/jasmin.jar main.j
Generated: Main.class
$ java Main
5
1
6
1
1
4
3
5.2
1.0
6.5099993
1.4761904
4.1
3.1
```

## Verify

```bash
$ make check

Parser
local-judge: v2.7.2
==============================+==================================
                       Sample | Accept
==============================+==================================
              in01_arithmetic | ✔
==============================+==================================
              in02_precedence | ✔
==============================+==================================
                   in03_scope | ✔
==============================+==================================
              in04_assignment | ✔
==============================+==================================
              in05_conversion | ✔
==============================+==================================
                      in06_if | ✔
==============================+==================================
                     in07_for | ✔
==============================+==================================
              in08_type_error | ✔
==============================+==================================
          in09_variable_error | ✔
==============================+==================================
                in10_function | ✔
==============================+==================================
                  in11_switch | ✔
==============================+==================================
                   in12_array | ✔
==============================+==================================
       in13_nested_ifelse_for | ✔
==============================+==================================
in14_function_redeclare_error | ✔
==============================+==================================
          in15_advanced_array | ✔
==============================+==================================
         in16_advanced_array2 | ✔
==============================+==================================
    in17_advanced_declaration | ✔
==============================+==================================
Correct/Total problems: 17/17
Obtained/Total scores:  100/100

Codegen
local-judge: v2.7.2
==============================+==================================
                       Sample | Accept
==============================+==================================
              in01_arithmetic | ✔
==============================+==================================
              in02_precedence | ✔
==============================+==================================
                   in03_scope | ✔
==============================+==================================
              in04_assignment | ✔
==============================+==================================
              in05_conversion | ✔
==============================+==================================
                      in06_if | ✔
==============================+==================================
                     in07_for | ✔
==============================+==================================
              in08_type_error | ✔
==============================+==================================
          in09_variable_error | ✔
==============================+==================================
                in10_function | ✔
==============================+==================================
                  in11_switch | ✔
==============================+==================================
                   in12_array | ✔
==============================+==================================
       in13_nested_ifelse_for | ✔
==============================+==================================
in14_function_redeclare_error | ✔
==============================+==================================
          in15_advanced_array | ✔
==============================+==================================
         in16_advanced_array2 | ✔
==============================+==================================
    in17_advanced_declaration | ✔
==============================+==================================
Correct/Total problems: 17/17
Obtained/Total scores:  100/100
```

## Debug the Java bytecode

+ Use [jvm-verifier](https://github.com/aben20807/jvm-verifier/releases) and follow the [example](https://github.com/aben20807/jvm-verifier/tree/master/example)

## 3rdparty/jasmin.jar

Jasmin homepage: https://jasmin.sourceforge.net/

## License

MIT
