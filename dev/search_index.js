var documenterSearchIndex = {"docs":
[{"location":"api/#API-Reference-1","page":"API Reference","title":"API Reference","text":"","category":"section"},{"location":"api/#Public-API-1","page":"API Reference","title":"Public API","text":"","category":"section"},{"location":"api/#","page":"API Reference","title":"API Reference","text":"OptimizingIR.Op\nOptimizingIR.Variable\nOptimizingIR.call\nOptimizingIR.addinstruction!\nOptimizingIR.addinput!\nOptimizingIR.addoutput!\nOptimizingIR.assign!\nOptimizingIR.constant\nOptimizingIR.compile\nOptimizingIR.has_symbol\nOptimizingIR.generate_unique_variable_symbol","category":"page"},{"location":"api/#OptimizingIR.Op","page":"API Reference","title":"OptimizingIR.Op","text":"Op(f::Function;\n        pure::Bool=false,\n        commutative::Bool=false,\n        hasleftidentity::Bool=false,\n        hasrightidentity::Bool=false,\n        identity_element::T=NULL_IDENTITY_ELEMENT,\n        mutable_arg=nothing)\n\nDefines a basic instruction with optimization annotations.\n\nArguments\n\nf is a Julia function to be executed by the Op.\npure: marks the function as pure (true) or impure (false) .\ncommutative: marks the Op as commutative.\nhasleftidentity: marks the Op as having an identity when operating from the left, which means that f(I, v) = v, where I is the identity_element.\nhasrightidentity: marks the Op as having an identity when operating from the right, which means that f(v, I) = v, where I is the identity_element.\nmutable_arg: either nothing, or the index or tuple of indexes of the arguments that need to be mutable.\n\nPurity\n\nA function is considered pure if its return value is the same for the same arguments, and has no side-effects.\n\nOperations marked as pure are suitable for Value-Numbering optimization.\n\nWhen marked as impure, all optimization passes are disabled.\n\nExamples\n\n# this Op allows using `+` as a pure, commutative function. Sets 0 as identity element.\nconst OP_SUM = OIR.Op(+, pure=true, commutative=true, hasleftidentity=true, hasrightidentity=true, identity_element=0)\n\n# `-` as a pure function. Identity is zero but only `x - 0 = x` case is checked.\nconst OP_SUB = OIR.Op(-, pure=true, hasrightidentity=true, identity_element=0)\n\n# `*` as pure commutative function. Sets 1 as identity element.\nconst OP_MUL = OIR.Op(*, pure=true, commutative=true, hasleftidentity=true, hasrightidentity=true, identity_element=1)\n\n# `/` as a pure function. Identity is checked to the right: `a / 1 = a`.\nconst OP_DIV = OIR.Op(/, pure=true, hasrightidentity=true, identity_element=1)\n\n# power function\nconst OP_POW = OIR.Op(^, pure=true, hasrightidentity=true, identity_element=1)\n\n# an Op that uses an arbitrary Julia function\nforeign_fun(a, b, c) = a^3 + b^2 + c\nconst OP_FOREIGN_FUN = OIR.Op(foreign_fun, pure=true)\n\n# An Op that is impure: every time we run `zeros` a different Array is returned.\nconst OP_ZEROS = OIR.Op(zeros)\n\n\n\n\n\n","category":"type"},{"location":"api/#OptimizingIR.Variable","page":"API Reference","title":"OptimizingIR.Variable","text":"Variable{M<:Mutability}\n\nCreates a variable identified by a symbol that can be either mutable or immutable.\n\nExamples\n\nm = OptimizingIR.MutableVariable(:varmut) # a mutable variable\nim = OptimizingIR.ImmutableVariable(:varimut) # an immutable variable\n\n\n\n\n\n","category":"type"},{"location":"api/#OptimizingIR.call","page":"API Reference","title":"OptimizingIR.call","text":"call(op, args...) :: LinearInstruction\n\nCreates an instruction as a call to operation op with arguments args.\n\nInternally, it returns either a OptimizingIR.PureInstruction or an OptimizingIR.ImpureInstruction.\n\n\n\n\n\n","category":"function"},{"location":"api/#OptimizingIR.addinstruction!","page":"API Reference","title":"OptimizingIR.addinstruction!","text":"addinstruction!(b::BasicBlock, instruction::LinearInstruction) :: ImmutableValue\n\nPushes an instruction to a basic block. Returns the value that represents the result after the execution of the instruction.\n\n\n\n\n\n","category":"function"},{"location":"api/#OptimizingIR.addinput!","page":"API Reference","title":"OptimizingIR.addinput!","text":"addinput!(b::BasicBlock, iv::ImmutableVariable) :: Int\n\nRegisters iv as an input variable of the function. Returns the index of this variable in the tuple of inputs (function arguments).\n\n\n\n\n\n","category":"function"},{"location":"api/#OptimizingIR.addoutput!","page":"API Reference","title":"OptimizingIR.addoutput!","text":"addoutput!(b::BasicBlock, iv::Variable) :: Int\n\nRegisters iv as an output variable of the function. Returns the index of this variable in the tuple of returned values.\n\n\n\n\n\n","category":"function"},{"location":"api/#OptimizingIR.assign!","page":"API Reference","title":"OptimizingIR.assign!","text":"assign!(bb::BasicBlock, lhs::Variable, rhs::AbstractValue)\n\nAssigns the value rhs to variable lhs.\n\n\n\n\n\n","category":"function"},{"location":"api/#OptimizingIR.constant","page":"API Reference","title":"OptimizingIR.constant","text":"constant(val) :: Const\n\nCreates a constant value.\n\n\n\n\n\n","category":"function"},{"location":"api/#OptimizingIR.compile","page":"API Reference","title":"OptimizingIR.compile","text":"compile(::Type{T}, program::Program) where {T<:AbstractMachine}\n\nCompiles the IR to a Julia function. It returns a function or a callable object (functor).\n\nconst OIR = OptimizingIR\nbb = OIR.BasicBlock()\n# (...) add instructions to basic block\nfinterpreter = OIR.compile(OIR.BasicBlockInterpreter, bb)\nfnative = OIR.compile(OIR.Native, bb)\n\n\n\n\n\n","category":"function"},{"location":"api/#OptimizingIR.has_symbol","page":"API Reference","title":"OptimizingIR.has_symbol","text":"has_symbol(bb::BasicBlock, sym::Symbol) :: Bool\n\nReturns true if there is any variable (input, local or output) defined that is identified by the symbol sym.\n\n\n\n\n\n","category":"function"},{"location":"api/#OptimizingIR.generate_unique_variable_symbol","page":"API Reference","title":"OptimizingIR.generate_unique_variable_symbol","text":"generate_unique_variable_symbol(bb::BasicBlock) :: Symbol\n\nOptimizingIR's version of Base.gensym.\n\nReturns a new symbol for which OptimizingIR.has_symbol is false.\n\n\n\n\n\n","category":"function"},{"location":"api/#Internals-1","page":"API Reference","title":"Internals","text":"","category":"section"},{"location":"api/#","page":"API Reference","title":"API Reference","text":"OptimizingIR.AbstractValue\nOptimizingIR.PureInstruction\nOptimizingIR.ImpureInstruction\nOptimizingIR.SSAValue\nOptimizingIR.try_on_add_instruction_passes\nOptimizingIR.LookupTable\nOptimizingIR.Const\nOptimizingIR.OptimizationRule\nOptimizingIR.BasicBlockInterpreter\nOptimizingIR.Native","category":"page"},{"location":"api/#OptimizingIR.AbstractValue","page":"API Reference","title":"OptimizingIR.AbstractValue","text":"AbstractValue{M<:Mutability}\n\nA value can be marked as either Mutable or Immutable.\n\nAn immutable value can be assigned only once. A mutable value can be assigned more than once.\n\n\n\n\n\n","category":"type"},{"location":"api/#OptimizingIR.PureInstruction","page":"API Reference","title":"OptimizingIR.PureInstruction","text":"A PureInstruction is a call to an operation that always returns the same value if the same arguments are passed to the instruction. It is suitable for memoization, in the sense that it can be optimized in the Value-Number algorithm inside a Basic Block.\n\nAn instruction is considered pure if its call has an pure Op and all of its arguments are immutable.\n\n\n\n\n\n","category":"type"},{"location":"api/#OptimizingIR.ImpureInstruction","page":"API Reference","title":"OptimizingIR.ImpureInstruction","text":"An ImpureInstruction is a call to an operation that not always returns the same value if the same arguments are passed to the instruction. It is not suitable for memoization, and the Value-Number optimization must be disabled for this call.\n\nAn instruction is considered impure if its call has an impure Op, or if onde of its arguments is mutable.\n\nMarking as mutable avoids Value-Numbering for this call.\n\n\n\n\n\n","category":"type"},{"location":"api/#OptimizingIR.SSAValue","page":"API Reference","title":"OptimizingIR.SSAValue","text":"A pointer to an instruction that computes a value.\n\n\n\n\n\n","category":"type"},{"location":"api/#OptimizingIR.try_on_add_instruction_passes","page":"API Reference","title":"OptimizingIR.try_on_add_instruction_passes","text":"try_on_add_instruction_passes(program, instruction) :: Union{Nothing, ImmutableValue}\n\nTries to apply all optimization passes available while running addinstruction!:\n\nfunction addinstruction!(b::BasicBlock, instruction::LinearInstruction) :: ImmutableValue\n\n    result = try_on_add_instruction_passes(b, instruction)\n    if result != nothing\n        return result\n    end\n\n    # (...)\nend\n\n\n\n\n\n","category":"function"},{"location":"api/#OptimizingIR.LookupTable","page":"API Reference","title":"OptimizingIR.LookupTable","text":"Generic struct for a lookup table that stores an ordered list of distinct elements.\n\nelement is stored in entries vector at index i.\nindex[element] retrieves the index i.\n\nUse addentry! to add items to the table. It the table already has the item, addentry! will return the existing item's index.\n\n\n\n\n\n","category":"type"},{"location":"api/#OptimizingIR.Const","page":"API Reference","title":"OptimizingIR.Const","text":"Constant value to be encoded directly into the IR. The address is the value itself.\n\n\n\n\n\n","category":"type"},{"location":"api/#OptimizingIR.OptimizationRule","page":"API Reference","title":"OptimizingIR.OptimizationRule","text":"Sets which optimizations are allowed to an Op.\n\n\n\n\n\n","category":"type"},{"location":"api/#OptimizingIR.BasicBlockInterpreter","page":"API Reference","title":"OptimizingIR.BasicBlockInterpreter","text":"Used to compile to a function that is interpreted when executed.\n\n\n\n\n\n","category":"type"},{"location":"api/#OptimizingIR.Native","page":"API Reference","title":"OptimizingIR.Native","text":"Used to compile to a function to machine code.\n\n\n\n\n\n","category":"type"},{"location":"#OptimizingIR.jl-1","page":"Home","title":"OptimizingIR.jl","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"<blockquote><i>\n\"Compilers<br>\nKeep on compilin'<br>\nCause it won't be too long\"<br></i>\nWonder, S.\n</blockquote>","category":"page"},{"location":"#","page":"Home","title":"Home","text":"This package provides an Intermediate Representation (IR) that you can use to build Julia functions at runtime.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"In this IR you can define operations with optimization annotations, so that the IR can run optimization passes in order to generate efficient code.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"The IR can be either interpreted or compiled to machine code. Each approach has a trade-off:","category":"page"},{"location":"#","page":"Home","title":"Home","text":"interpreting the IR has no compilation step, but results in a slower execution time when running the function;\ncompiling the IR to machine code builds a Julia expression for the function body and goes through the Julia's JIT overhead, but the execution time is faster.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"Also, interpreting the IR lets the user inspect each step in the calculation. This is useful for implementing auto-generation of documentation on the calculation performed by the function.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"This package is not very useful if you can write your function by hand. It should be useful if you ever find yourself programmatically building functions out of Julia Expressions when translating from other high-level languages.","category":"page"},{"location":"#Requirements-1","page":"Home","title":"Requirements","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"Julia v1.0 or newer.","category":"page"},{"location":"#Installation-1","page":"Home","title":"Installation","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"From a Julia session, run:","category":"page"},{"location":"#","page":"Home","title":"Home","text":"julia> using Pkg\n\njulia> Pkg.add(\"OptimizingIR\")","category":"page"},{"location":"#Case-Study:-Julia's-IR-1","page":"Home","title":"Case Study: Julia's IR","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"Let's start with a simple Julia function.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"julia_basic_block_test_function(x::Number) = (\n    ((-((10.0 * 2.0 + x) / 1.0)\n    + (x + 10.0 * 2.0) + 1.0) * 1.0 / 2.0)\n    + (0.0 * x) + 1.0) * 1.0\n\njulia_basic_block_test_function(10.0)","category":"page"},{"location":"#","page":"Home","title":"Home","text":"Inspecting Julia's lowered IR we can see that %1 and %5 are repeated instructions that compute the same constant value.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"julia> @code_lowered julia_basic_block_test_function(10.0)\nCodeInfo(\n1 ─ %1  = 10.0 * 2.0\n│   %2  = %1 + x\n│   %3  = %2 / 1.0\n│   %4  = -%3\n│   %5  = 10.0 * 2.0\n│   %6  = x + %5\n│   %7  = %4 + %6 + 1.0\n│   %8  = %7 * 1.0\n│   %9  = %8 / 2.0\n│   %10 = 0.0 * x\n│   %11 = %9 + %10 + 1.0\n│   %12 = %11 * 1.0\n└──       return %12\n)","category":"page"},{"location":"#","page":"Home","title":"Home","text":"The typed IR is better at constant propagation, but still has 13 instructions.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"julia> @code_typed julia_basic_block_test_function(10.0)\nCodeInfo(\n1 ─ %1  = Base.add_float(20.0, x)::Float64\n│   %2  = Base.div_float(%1, 1.0)::Float64\n│   %3  = Base.neg_float(%2)::Float64\n│   %4  = Base.add_float(x, 20.0)::Float64\n│   %5  = Base.add_float(%3, %4)::Float64\n│   %6  = Base.add_float(%5, 1.0)::Float64\n│   %7  = Base.mul_float(%6, 1.0)::Float64\n│   %8  = Base.div_float(%7, 2.0)::Float64\n│   %9  = Base.mul_float(0.0, x)::Float64\n│   %10 = Base.add_float(%8, %9)::Float64\n│   %11 = Base.add_float(%10, 1.0)::Float64\n│   %12 = Base.mul_float(%11, 1.0)::Float64\n└──       return %12\n) => Float64","category":"page"},{"location":"#","page":"Home","title":"Home","text":"Why is that, given that Julia should generate very efficient code? Well, nothing is wrong really. Julia just doesn't have enough information to optimize instructions in the early phase of the Julia's IR.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"When the Julia compiler reaches the LLVM phase, it generates efficient code, reducing the number of instructions to 8.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"julia> @code_llvm julia_basic_block_test_function(10.0)\n\n;  @ REPL[1]:1 within `julia_basic_block_test_function'\ndefine double @julia_julia_basic_block_test_function_16035(double) {\ntop:\n; ┌ @ float.jl:395 within `+'\n   %1 = fadd double %0, 2.000000e+01\n; └\n; ┌ @ operators.jl:529 within `+' @ float.jl:395\n   %2 = fsub double %1, %1\n   %3 = fadd double %2, 1.000000e+00\n; └\n; ┌ @ float.jl:401 within `/'\n   %4 = fmul double %3, 5.000000e-01\n; └\n; ┌ @ float.jl:399 within `*'\n   %5 = fmul double %0, 0.000000e+00\n; └\n; ┌ @ operators.jl:529 within `+' @ float.jl:395\n   %6 = fadd double %5, %4\n   %7 = fadd double %6, 1.000000e+00\n; └\n  ret double %7\n}","category":"page"},{"location":"#","page":"Home","title":"Home","text":"So, why bother using another IR?","category":"page"},{"location":"#","page":"Home","title":"Home","text":"Well, if you're programmatically building functions out of Julia Expressions, you may reach a billion nodes on a single Julia Expression instead of a few thousand nodes that should be sufficient if you had optimizations enabled.","category":"page"},{"location":"#Using-OptimizingIR-1","page":"Home","title":"Using OptimizingIR","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"By using OptimizingIR you give the compiler sufficient information to perform early optimization passes as you build the IR.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"The following example builds the test function from the previous section using OptimizingIR.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"import OptimizingIR\nconst OIR = OptimizingIR\n\n# define op-codes with optimization annotations\nconst OP_SUM = OIR.Op(+, pure=true, commutative=true, hasleftidentity=true, hasrightidentity=true, identity_element=0)\nconst OP_SUB = OIR.Op(-, pure=true, hasrightidentity=true, identity_element=0)\nconst OP_MUL = OIR.Op(*, pure=true, commutative=true, hasleftidentity=true, hasrightidentity=true, identity_element=1)\nconst OP_DIV = OIR.Op(/, pure=true, hasrightidentity=true, identity_element=1)\n\n# build the Julia function out of a Basic Block\nbb = OIR.BasicBlock()\nx = OIR.ImmutableVariable(:x)\nOIR.addinput!(bb, x)\narg1 = OIR.constant(10.0)\narg2 = OIR.constant(2.0)\narg3 = OIR.addinstruction!(bb, OIR.call(OP_MUL, arg1, arg2))\narg4 = OIR.addinstruction!(bb, OIR.call(OP_SUM, arg3, x))\narg5 = OIR.constant(1.0)\narg6 = OIR.addinstruction!(bb, OIR.call(OP_DIV, arg4, arg5))\narg7 = OIR.addinstruction!(bb, OIR.call(OP_SUB, arg6))\narg8 = OIR.addinstruction!(bb, OIR.call(OP_SUM, x, arg3))\narg9 = OIR.addinstruction!(bb, OIR.call(OP_SUM, arg8, arg7))\narg10 = OIR.addinstruction!(bb, OIR.call(OP_SUM, arg9, arg5))\narg11 = OIR.addinstruction!(bb, OIR.call(OP_MUL, arg10, arg5))\narg12 = OIR.addinstruction!(bb, OIR.call(OP_DIV, arg11, arg2))\narg13 = OIR.constant(0.0)\narg14 = OIR.addinstruction!(bb, OIR.call(OP_MUL, arg13, x))\narg15 = OIR.addinstruction!(bb, OIR.call(OP_SUM, arg14, arg12))\narg16 = OIR.constant(1.0)\narg17 = OIR.addinstruction!(bb, OIR.call(OP_SUM, arg16, arg15))\narg18 = OIR.addinstruction!(bb, OIR.call(OP_MUL, arg16, arg17))\nvar_output = OIR.MutableVariable(:output)\nOIR.addoutput!(bb, var_output)\nOIR.assign!(bb, var_output, arg18)\n\nprintln(bb)","category":"page"},{"location":"#","page":"Home","title":"Home","text":"From an IR, you can compile it to a function.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"Compiling with OptimizingIR.BasicBlockInterpreter generates a function that is interpreted when it executes.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"finterpreter = OIR.compile(OIR.BasicBlockInterpreter, bb)\nprintln(\"finterpreter(10.0) = $( finterpreter(10.0) )\")","category":"page"},{"location":"#","page":"Home","title":"Home","text":"Compiling with OptimizingIR.Native will compile a new Julia function to machine code.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"fnative = OIR.compile(OIR.Native, bb)\nprintln(\"fnative(10.0) = $( fnative(10.0) )\")","category":"page"},{"location":"#World-Age-Problem-1","page":"Home","title":"World Age Problem","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"When using OptimizingIR.Native, if you compile a new function and call it before reaching global scope you may get a World Age Problem.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"As an example, consider the following code:","category":"page"},{"location":"#","page":"Home","title":"Home","text":"using OptimizingIR\nconst OIR = OptimizingIR\n\nconst OP_POW = OIR.Op(^, pure=true, hasrightidentity=true, identity_element=1)\n\nfunction gen_and_run()\n    bb = OIR.BasicBlock()\n    input_var = OIR.ImmutableVariable(:x)\n    OIR.addinput!(bb, input_var)\n    c2 = OIR.constant(2)\n    arg1 = OIR.addinstruction!(bb, OIR.call(OP_POW, input_var, c2))\n    var_result = OIR.ImmutableVariable(:result)\n    OIR.assign!(bb, var_result, arg1)\n    OIR.addoutput!(bb, var_result)\n\n    f = OIR.compile(OIR.Native, bb)\n    return f(2) # call the function before reaching global scope\nend","category":"page"},{"location":"#","page":"Home","title":"Home","text":"Calling gen_and_run yield an error.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"julia> gen_and_run()\nERROR: MethodError: no method matching ##371(::Int64)\nThe applicable method may be too new: running in world age 26050, while current world is 26052.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"You can Google for \"julia world age problem\" to get the details. One way to solve this is to use Base.invokelatest to call the function.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"using OptimizingIR\nconst OIR = OptimizingIR\n\nconst OP_POW = OIR.Op(^, pure=true, hasrightidentity=true, identity_element=1)\n\nfunction gen_and_run()\n    bb = OIR.BasicBlock()\n    input_var = OIR.ImmutableVariable(:x)\n    OIR.addinput!(bb, input_var)\n    c2 = OIR.constant(2)\n    arg1 = OIR.addinstruction!(bb, OIR.call(OP_POW, input_var, c2))\n    var_result = OIR.ImmutableVariable(:result)\n    OIR.assign!(bb, var_result, arg1)\n    OIR.addoutput!(bb, var_result)\n\n    f = OIR.compile(OIR.Native, bb)\n    return Base.invokelatest(f, 2) # using Base.invokelatest\nend","category":"page"},{"location":"#","page":"Home","title":"Home","text":"Running the fixed version of gen_and_run yield the expected result.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"julia> gen_and_run()\n4","category":"page"},{"location":"#Limitations-1","page":"Home","title":"Limitations","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"Currently supports Basic Blocks only (no control flow).\nInput variables (function arguments) must be Immutable.","category":"page"},{"location":"#Source-Code-1","page":"Home","title":"Source Code","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"The source code for this package is hosted at https://github.com/felipenoris/OptimizingIR.jl.","category":"page"},{"location":"#License-1","page":"Home","title":"License","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"The source code for the package OptimizingIR.jl is licensed under the MIT License.","category":"page"},{"location":"#Alternative-Packages-1","page":"Home","title":"Alternative Packages","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"IRTools.jl","category":"page"}]
}
