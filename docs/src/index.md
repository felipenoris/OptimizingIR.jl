
# OptimizingIR.jl

```@raw html
<blockquote><i>
"Compilers<br>
Keep on compilin'<br>
Cause it won't be too long"<br></i>
Wonder, S.
</blockquote>
```

This package provides an [Intermediate Representation (IR)](https://en.wikipedia.org/wiki/Intermediate_representation)
that you can use to build Julia functions at runtime.

In this IR you can define operations with optimization annotations, so that
the IR can run optimization passes in order to generate efficient code.

The IR can be either interpreted or compiled to machine code.
Each approach has a trade-off:

* interpreting the IR has no compilation step, but results in a slower execution time when running the function;

* compiling the IR to machine code builds a Julia expression for the function body and goes through the Julia's JIT overhead, but the execution time is faster.

Also, interpreting the IR lets the user inspect each step in the calculation.
This is useful for implementing auto-generation of documentation on
the calculation performed by the function.

This package is not very useful if you can write your function by hand.
It should be useful if you ever find yourself programmatically building
functions out of [Julia Expressions](https://docs.julialang.org/en/v1/manual/metaprogramming/#Expressions-and-evaluation-1)
when translating from other high-level languages.

## Case Study: Julia's IR

Let's start with a simple Julia function.

```@example case_study
julia_basic_block_test_function(x::Number) = (
    ((-((10.0 * 2.0 + x) / 1.0)
    + (x + 10.0 * 2.0) + 1.0) * 1.0 / 2.0)
    + (0.0 * x) + 1.0) * 1.0

julia_basic_block_test_function(10.0)
```

Inspecting Julia's lowered IR we can see that `%1` and `%5` are repeated instructions that compute the same constant value.

```julia
julia> @code_lowered julia_basic_block_test_function(10.0)
CodeInfo(
1 ─ %1  = 10.0 * 2.0
│   %2  = %1 + x
│   %3  = %2 / 1.0
│   %4  = -%3
│   %5  = 10.0 * 2.0
│   %6  = x + %5
│   %7  = %4 + %6 + 1.0
│   %8  = %7 * 1.0
│   %9  = %8 / 2.0
│   %10 = 0.0 * x
│   %11 = %9 + %10 + 1.0
│   %12 = %11 * 1.0
└──       return %12
)
```

The typed IR is better at constant propagation, but still has 13 instructions.

```julia
julia> @code_typed julia_basic_block_test_function(10.0)
CodeInfo(
1 ─ %1  = Base.add_float(20.0, x)::Float64
│   %2  = Base.div_float(%1, 1.0)::Float64
│   %3  = Base.neg_float(%2)::Float64
│   %4  = Base.add_float(x, 20.0)::Float64
│   %5  = Base.add_float(%3, %4)::Float64
│   %6  = Base.add_float(%5, 1.0)::Float64
│   %7  = Base.mul_float(%6, 1.0)::Float64
│   %8  = Base.div_float(%7, 2.0)::Float64
│   %9  = Base.mul_float(0.0, x)::Float64
│   %10 = Base.add_float(%8, %9)::Float64
│   %11 = Base.add_float(%10, 1.0)::Float64
│   %12 = Base.mul_float(%11, 1.0)::Float64
└──       return %12
) => Float64
```

Why is that, given that Julia should generate very efficient code?
Well, nothing is wrong really. Julia just doesn't have enough information to
optimize instructions in the early phase of the Julia IR.

When the Julia compiler reaches the LLVM phase, it generates efficient code,
reducing the number of instructions to 8.

```julia
julia> @code_llvm julia_basic_block_test_function(10.0)

;  @ REPL[1]:1 within `julia_basic_block_test_function'
define double @julia_julia_basic_block_test_function_16035(double) {
top:
; ┌ @ float.jl:395 within `+'
   %1 = fadd double %0, 2.000000e+01
; └
; ┌ @ operators.jl:529 within `+' @ float.jl:395
   %2 = fsub double %1, %1
   %3 = fadd double %2, 1.000000e+00
; └
; ┌ @ float.jl:401 within `/'
   %4 = fmul double %3, 5.000000e-01
; └
; ┌ @ float.jl:399 within `*'
   %5 = fmul double %0, 0.000000e+00
; └
; ┌ @ operators.jl:529 within `+' @ float.jl:395
   %6 = fadd double %5, %4
   %7 = fadd double %6, 1.000000e+00
; └
  ret double %7
}
```

*So, why bother using another IR?*

Well, if you're programmatically building functions out of Julia Expressions,
you may reach a billion nodes on a single Julia Expression instead of
a few thousand nodes that should be sufficient if you had optimizations enabled.

## Using OptimizingIR

By using OptimizingIR you give the compiler sufficient information to perform early optimization
passes as you build the IR.

The following example builds the test function from the previous section using `OptimizingIR`.

```@example case_study
import OptimizingIR
const OIR = OptimizingIR

# define op-codes with optimization annotations
const op_sum = OIR.Op(+, pure=true, commutative=true, hasleftidentity=true, hasrightidentity=true, identity_element=0)
const op_sub = OIR.Op(-, pure=true, hasrightidentity=true, identity_element=0)
const op_mul = OIR.Op(*, pure=true, commutative=true, hasleftidentity=true, hasrightidentity=true, identity_element=1)
const op_div = OIR.Op(/, pure=true, hasrightidentity=true, identity_element=1)

# build the Julia function out of a Basic Block
bb = OIR.BasicBlock()
x = OIR.ImmutableVariable(:x)
OIR.addinput!(bb, x)
arg1 = OIR.constant(10.0)
arg2 = OIR.constant(2.0)
arg3 = OIR.addinstruction!(bb, OIR.call(op_mul, arg1, arg2))
arg4 = OIR.addinstruction!(bb, OIR.call(op_sum, arg3, x))
arg5 = OIR.constant(1.0)
arg6 = OIR.addinstruction!(bb, OIR.call(op_div, arg4, arg5))
arg7 = OIR.addinstruction!(bb, OIR.call(op_sub, arg6))
arg8 = OIR.addinstruction!(bb, OIR.call(op_sum, x, arg3))
arg9 = OIR.addinstruction!(bb, OIR.call(op_sum, arg8, arg7))
arg10 = OIR.addinstruction!(bb, OIR.call(op_sum, arg9, arg5))
arg11 = OIR.addinstruction!(bb, OIR.call(op_mul, arg10, arg5))
arg12 = OIR.addinstruction!(bb, OIR.call(op_div, arg11, arg2))
arg13 = OIR.constant(0.0)
arg14 = OIR.addinstruction!(bb, OIR.call(op_mul, arg13, x))
arg15 = OIR.addinstruction!(bb, OIR.call(op_sum, arg14, arg12))
arg16 = OIR.constant(1.0)
arg17 = OIR.addinstruction!(bb, OIR.call(op_sum, arg16, arg15))
arg18 = OIR.addinstruction!(bb, OIR.call(op_mul, arg16, arg17))
var_output = OIR.MutableVariable(:output)
OIR.addoutput!(bb, var_output)
OIR.assign!(bb, var_output, arg18)

println(bb)
```

From an IR, you can compile it to a function.

Compiling with a `BasicBlockInterpreter` will return a function
that is interpreted when called.

```@example case_study
finterpreter = OIR.compile(OIR.BasicBlockInterpreter, bb)
println("finterpreter(10.0) = $( finterpreter(10.0) )")
```

Compiling with a `Native` will compile a new Julia function
to machine code.

```@example case_study
fnative = OIR.compile(OIR.Native, bb)
println("fnative(10.0) = $( fnative(10.0) )")
```

## Requirements

* Julia v1.0 or newer.

## Limitations

* Currently supports Basic Blocks only (no control flow).

* Input variables (function arguments) must be Immutable.

## Source Code

The source code for this package is hosted at
[https://github.com/felipenoris/OptimizingIR.jl](https://github.com/felipenoris/OptimizingIR.jl).

## License

The source code for the package **OptimizingIR.jl** is licensed under
the [MIT License](https://raw.githubusercontent.com/felipenoris/OptimizingIR.jl/master/LICENSE).

## Alternative Packages

* [IRTools.jl](https://github.com/MikeInnes/IRTools.jl)
