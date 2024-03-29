
#=
MBP Julia v1.6.1
[ Info: Benchmarks
Compile Native:
  0.000830 seconds (338 allocations: 22.781 KiB, 0.05% compilation time)
Compile BasicBlockInterpreter
  0.000006 seconds (7 allocations: 960 bytes)
Compilation Overhead: Native / BasicBlockInterpreter: 96.9x
F Call Native 1st
  0.040432 seconds (46.67 k allocations: 2.885 MiB, 25.46% gc time, 99.96% compilation time)
F Call Native 2nd
  0.000006 seconds (4 allocations: 176 bytes)
F Call Interpreter 1st
  0.054123 seconds (121.41 k allocations: 7.389 MiB, 99.51% compilation time)
F Call Interpreter 2nd
  0.000062 seconds (37 allocations: 976 bytes)
F Call Julia 1st
  0.010146 seconds (16.20 k allocations: 966.099 KiB, 99.81% compilation time)
F Call Julia 2nd
  0.000005 seconds (4 allocations: 176 bytes)
F Call Overhead: BasicBlockInterpreter / julia = 28.9x
F Call Overhead: Native / julia = 0.6x
[ Info: Compilation + F Call
BasicBlockInterpreter: 171.7µs
Native: 714.2µs
Native / BasicBlockInterpreter = 4.2x
=#

function benchmark_julia(x, y)
    v = zeros(Float64, 3)
    v[1] = x
    v[2] = y

    result = (((-( v[1] - v[2])) + 1.0 ) * 2.0) / 1.0

    return v, result
end

bb = OIR.BasicBlock()
in1 = OIR.ImmutableVariable(:x)
in2 = OIR.ImmutableVariable(:y)
OIR.addinput!(bb, in1)
OIR.addinput!(bb, in2)

argvec = OIR.addinstruction!(bb, OIR.call(OP_ZEROS, OIR.constant(Float64), OIR.constant(3)))
var_vec = OIR.MutableVariable(:v)
OIR.assign!(bb, var_vec, argvec)

OIR.addinstruction!(bb, OIR.call(OP_SETINDEX, var_vec, in1, OIR.constant(1)))
OIR.addinstruction!(bb, OIR.call(OP_SETINDEX, var_vec, in2, OIR.constant(2)))

arg1 = OIR.addinstruction!(bb, OIR.call(OP_GETINDEX, var_vec, OIR.constant(1)))
arg2 = OIR.addinstruction!(bb, OIR.call(OP_GETINDEX, var_vec, OIR.constant(2)))

# (((-( x[1] - x[2])) + 1.0 ) * 2.0) / 1.0
arg3 = OIR.addinstruction!(bb, OIR.call(OP_SUB, arg1, arg2))
arg4 = OIR.addinstruction!(bb, OIR.call(OP_SUB, arg3))
arg5 = OIR.addinstruction!(bb, OIR.call(OP_SUM, arg4, OIR.constant(1.0)))
arg6 = OIR.addinstruction!(bb, OIR.call(OP_MUL, arg5, OIR.constant(2.0)))
arg7 = OIR.addinstruction!(bb, OIR.call(OP_DIV, arg6, OIR.constant(1.0)))

var_result = OIR.ImmutableVariable(:result)
OIR.assign!(bb, var_result, arg7)

OIR.addoutput!(bb, var_vec)
OIR.addoutput!(bb, var_result)

println()
@info("Benchmarks")

println("Compile Native:")
@time fnative = OIR.compile(OIR.Native, bb)

println("Compile BasicBlockInterpreter")
@time finterpreter = OIR.compile(OIR.BasicBlockInterpreter, bb)

println("Compile BasicBlockInterpreter{Float64}")
@time finterpreter_float64 = OIR.compile(OIR.BasicBlockInterpreter{Union{Nothing, Float64, Vector{Float64}}}, bb)

compilation_el_native = @elapsed OIR.compile(OIR.Native, bb)
compilation_el_interpreter = @elapsed OIR.compile(OIR.BasicBlockInterpreter, bb)
println("Compilation Overhead: Native / BasicBlockInterpreter: $(round(compilation_el_native / compilation_el_interpreter, digits=1))x")

input = (10.0, 20.0)

println("F Call Native 1st")
@time result_native = fnative(input...)

println("F Call Native 2nd")
@time result_native = fnative(input...)

println("F Call Interpreter 1st")
@time result_interpreter = finterpreter(input...)

println("F Call Interpreter 2nd")
@time result_interpreter = finterpreter(input...)

println("F Call Interpreter Float64 1st")
@time result_interpreter = finterpreter_float64(input...)

println("F Call Interpreter Float64 2nd")
@time result_interpreter = finterpreter_float64(input...)

println("F Call Julia 1st")
@time result_julia = benchmark_julia(input...)

println("F Call Julia 2nd")
@time result_julia = benchmark_julia(input...)

@test result_native == result_julia
@test result_interpreter == result_julia

execution_el_interpreter = @elapsed finterpreter(input...)
execution_el_native = @elapsed fnative(input...)
execution_el_julia = @elapsed benchmark_julia(input...)
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
