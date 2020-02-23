
#=
MBP
[ Info: Benchmarks
Compile Native:
  0.000647 seconds (338 allocations: 22.758 KiB)
Compile BasicBlockInterpreter
  0.000006 seconds (6 allocations: 224 bytes)
Compilation Overhead: Native / BasicBlockInterpreter: 291.5x
F Call Native 1st
  0.028092 seconds (48.17 k allocations: 2.647 MiB)
F Call Native 2nd
  0.000005 seconds (9 allocations: 768 bytes)
F Call Interpreter 1st
  0.063945 seconds (53.18 k allocations: 2.954 MiB, 6.68% gc time)
F Call Interpreter 2nd
  0.000042 seconds (55 allocations: 3.000 KiB)
F Call Julia 1st
  0.007132 seconds (16.13 k allocations: 919.125 KiB)
F Call Julia 2nd
  0.000002 seconds (6 allocations: 304 bytes)
F Call Overhead: BasicBlockInterpreter / julia = 22.5x
F Call Overhead: Native / julia = 1.3x
[ Info: Compilation + F Call
BasicBlockInterpreter: 60.9µs
Native: 729.2µs
Native / BasicBlockInterpreter = 12.0x
=#

function benchmark_julia(x::Vector)
    v = zeros(Float64, 3)
    v[1] = x[1]
    v[2] = x[2]

    result = (((-( v[1] - v[2])) + 1.0 ) * 2.0) / 1.0

    return (v=v, result=result)
end

bb = OIR.BasicBlock()
in1 = OIR.ImmutableVariable(:x)
in2 = OIR.ImmutableVariable(:y)
OIR.addinput!(bb, in1)
OIR.addinput!(bb, in2)

argvec = OIR.addinstruction!(bb, OIR.call(op_zeros, OIR.constant(Float64), OIR.constant(3)))
var_vec = OIR.MutableVariable(:v)
OIR.assign!(bb, var_vec, argvec)

OIR.addinstruction!(bb, OIR.callsetindex(var_vec, in1, OIR.constant(1)))
OIR.addinstruction!(bb, OIR.callsetindex(var_vec, in2, OIR.constant(2)))

arg1 = OIR.addinstruction!(bb, OIR.callgetindex(var_vec, OIR.constant(1)))
arg2 = OIR.addinstruction!(bb, OIR.callgetindex(var_vec, OIR.constant(2)))

# (((-( x[1] - x[2])) + 1.0 ) * 2.0) / 1.0
arg3 = OIR.addinstruction!(bb, OIR.call(op_sub, arg1, arg2))
arg4 = OIR.addinstruction!(bb, OIR.call(op_sub, arg3))
arg5 = OIR.addinstruction!(bb, OIR.call(op_sum, arg4, OIR.constant(1.0)))
arg6 = OIR.addinstruction!(bb, OIR.call(op_mul, arg5, OIR.constant(2.0)))
arg7 = OIR.addinstruction!(bb, OIR.call(op_div, arg6, OIR.constant(1.0)))

OIR.assign!(bb, OIR.ImmutableVariable(:result), arg7)

println()
@info("Benchmarks")

println("Compile Native:")
@time fnative = OIR.compile(OIR.Native, bb)

println("Compile BasicBlockInterpreter")
@time finterpreter = OIR.compile(OIR.BasicBlockInterpreter, bb)

compilation_el_native = @elapsed OIR.compile(OIR.Native, bb)
compilation_el_interpreter = @elapsed OIR.compile(OIR.BasicBlockInterpreter, bb)
println("Compilation Overhead: Native / BasicBlockInterpreter: $(round(compilation_el_native / compilation_el_interpreter, digits=1))x")

input = [10.0, 20.0]

println("F Call Native 1st")
@time result_native = fnative(input)

println("F Call Native 2nd")
@time result_native = fnative(input)

println("F Call Interpreter 1st")
@time result_interpreter = finterpreter(input)

println("F Call Interpreter 2nd")
@time result_interpreter = finterpreter(input)

println("F Call Julia 1st")
@time result_julia = benchmark_julia(input)

println("F Call Julia 2nd")
@time result_julia = benchmark_julia(input)

@test result_native.result == result_julia.result
@test result_native.v == result_julia.v
@test result_interpreter.result == result_julia.result
@test result_interpreter.v == result_julia.v

execution_el_interpreter = @elapsed finterpreter(input)
execution_el_native = @elapsed fnative(input)
execution_el_julia = @elapsed benchmark_julia(input)
println("F Call Overhead: BasicBlockInterpreter / julia = $(round(execution_el_interpreter / execution_el_julia, digits=1))x")
println("F Call Overhead: Native / julia = $(round(execution_el_native / execution_el_julia, digits=1))x")

sec2µs(secs) = "$(round(secs*1E6, digits=1))µs"

@info("Compilation + F Call")
total_el_interpreter = compilation_el_interpreter + execution_el_interpreter
total_native = compilation_el_native + execution_el_native
println("BasicBlockInterpreter: $(sec2µs(total_el_interpreter))")
println("Native: $(sec2µs(total_native))")
println("Native / BasicBlockInterpreter = $(round(total_native / total_el_interpreter, digits=1))x")

println()
