
#=
Benchmarks
  0.000279 seconds (50 allocations: 2.516 KiB)
  0.000003 seconds (6 allocations: 304 bytes)
  0.000004 seconds (6 allocations: 304 bytes)
Interpreter Overhead = 114.1x
Native Overhead = 1.1x
=#

import OptimizingIR
const OIR = OptimizingIR
using Test

foreign_fun(a, b, c) = a^3 + b^2 + c

@testset "LookupTable" begin
    table = OIR.LookupTable{Int}()
    @test isempty(table)
    @test OIR.addentry!(table, 10) == 1
    @test !isempty(table)
    @test OIR.addentry!(table, 20) == 2
    @test length(table) == 2
    @test OIR.addentry!(table, 10) == 1
    @test OIR.addentry!(table, 20) == 2
    @test length(table) == 2
    @test 10 ∈ table
    @test 20 ∈ table
    @test 1 ∉ table
    @test lastindex(table) == 2
    @test OIR.indexof(table, 10) == 1
    @test OIR.indexof(table, 20) == 2
    @test table[1] == 10
    @test table[2] == 20

    for (i, item) in enumerate(table)
        if i == 1
            @test item == 10
        elseif i == 2
            @test item == 20
        else
            @test false
        end
    end

    for item in table
        @test item == 10 || item == 20
    end

    @test collect(table) == [10, 20]
    @test filter(i -> i > 10, table) == [20]
end

@testset "call" begin
    arg1 = OIR.SSAValue(1)
    arg2 = OIR.SSAValue(2)
    @test OIR.iscommutative( OIR.callpure(*, arg1, arg2) )
    @test OIR.iscommutative( OIR.callpure(+, arg1, arg2) )
    @test !OIR.iscommutative( OIR.callpure(/, arg1, arg2) )

    @testset "CallVararg" begin

        bb = OIR.BasicBlock()
        arg1 = OIR.addinput!(bb, :x)
        arg2 = OIR.constant(10.0)
        arg3 = OIR.constant(2.0)
        arg4 = OIR.addinstruction!(bb, OIR.callpure(foreign_fun, arg1, arg2, arg3))

        arg5 = OIR.addinput!(bb, :x)
        arg6 = OIR.constant(10.0)
        arg7 = OIR.constant(2.0)
        arg8 = OIR.addinstruction!(bb, OIR.callpure(foreign_fun, arg5, arg6, arg7))

        arg9 = OIR.addinstruction!(bb, OIR.callpure(+, arg4, arg8))

        OIR.assign!(bb, :output, arg9)

        # println(bb)

        input = 20.0
        f = OIR.compile(OIR.BasicBlockInterpreter, bb)
        @test f([input]).output ≈ 2 * (input^3 + 10^2 + 2)
    end

    @testset "ImpureCall" begin
        bb = OIR.BasicBlock()
        arg1 = OIR.constant(Float64)
        arg2 = OIR.constant(3)
        arg3 = OIR.addinstruction!(bb, OIR.callimpure(zeros, arg1, arg2))
        arg4 = OIR.addinstruction!(bb, OIR.callimpure(zeros, arg1, arg2))
        @test length(bb.instructions) == 2
    end
end

@testset "GetIndex" begin
    bb = OIR.BasicBlock()
    arg1 = OIR.addinput!(bb, :x)
    arg2 = OIR.constant(2)
    arg3 = OIR.addinstruction!(bb, OIR.GetIndex(arg1, arg2)) # reads x[2]
    arg4 = OIR.constant(5.0)
    arg5 = OIR.addinstruction!(bb, OIR.callpure(*, arg4, arg3))
    arg6 = OIR.addinstruction!(bb, OIR.GetIndex(arg1, arg2)) # reads x[2]
    arg7 = OIR.addinstruction!(bb, OIR.callpure(*, arg6, arg5))
    OIR.assign!(bb, :output, arg7)

    # println(bb)

    f = OIR.compile(OIR.BasicBlockInterpreter, bb)
    @test f([[5.0, 6.0, 7.0]]).output ≈ 6.0 * 5.0 * 6.0
end

@testset "SetIndex" begin
    bb = OIR.BasicBlock()
    arginput = OIR.addinput!(bb, :x)
    arg1 = OIR.constant(Float64)
    arg3 = OIR.addinstruction!(bb, OIR.callimpure(zeros, arg1, arginput))
    OIR.assign!(bb, :vec, arg3)
    arg4 = OIR.constant(1)
    arg_inspect = OIR.addinstruction!(bb, OIR.GetIndex(arg3, arg4))
    OIR.assign!(bb, :inspect1, arg_inspect)
    arg_input_value = OIR.constant(10)
    arg5 = OIR.addinstruction!(bb, OIR.SetIndex(arg3, arg_input_value, arg4))
    arg_inspect = OIR.addinstruction!(bb, OIR.GetIndex(arg3, arg4))
    OIR.assign!(bb, :inspect2, arg_inspect)

    println(bb)

    input_vector = [3]
    f = OIR.compile(OIR.BasicBlockInterpreter, bb)
    result = f(input_vector)
    @test result.inspect1 ≈ 0.0
    @test result.inspect2 ≈ 10.0
    @test isa(result.inspect2, Float64)
    @test result.vec == [ 10.0, 0.0, 0.0 ]
end

compiledfunction(x::Vector) = (((-((10.0 * 2.0 + x[1]) / 1.0) + (x[1] + 10.0 * 2.0) + 1.0) * 1.0 / 2.0) + (0.0 * x[1]) + 1.0) * 1.0

@testset "Basic Block" begin
    bb = OIR.BasicBlock()
    x = OIR.addinput!(bb, :x)
    arg1 = OIR.constant(10.0)
    arg2 = OIR.constant(2.0)
    arg3 = OIR.addinstruction!(bb, OIR.callpure(*, arg1, arg2))
    arg4 = OIR.addinstruction!(bb, OIR.callpure(+, arg3, x))
    arg5 = OIR.constant(1.0)
    arg6 = OIR.addinstruction!(bb, OIR.callpure(/, arg4, arg5))
    arg7 = OIR.addinstruction!(bb, OIR.callpure(-, arg6))
    arg8 = OIR.addinstruction!(bb, OIR.callpure(+, x, arg3))
    arg9 = OIR.addinstruction!(bb, OIR.callpure(+, arg8, arg7))
    arg10 = OIR.addinstruction!(bb, OIR.callpure(+, arg9, arg5))
    arg11 = OIR.addinstruction!(bb, OIR.callpure(*, arg10, arg5))
    arg12 = OIR.addinstruction!(bb, OIR.callpure(/, arg11, arg2))
    arg13 = OIR.constant(0.0)
    arg14 = OIR.addinstruction!(bb, OIR.callpure(*, arg13, x))
    arg15 = OIR.addinstruction!(bb, OIR.callpure(+, arg14, arg12))
    arg16 = OIR.constant(1.0)
    arg17 = OIR.addinstruction!(bb, OIR.callpure(+, arg16, arg15))
    arg18 = OIR.addinstruction!(bb, OIR.callpure(*, arg16, arg17))
    OIR.assign!(bb, :output, arg18)

    # println(bb)

    @testset "BasicBlockInterpreter" begin
        input_vector = [10.0]
        f = OIR.compile(OIR.BasicBlockInterpreter, bb)
        result = f(input_vector)
        @test result.output ≈ compiledfunction(input_vector)
    end

    @testset "Multiply by zero" begin
        last_instruction_ssavalue = OIR.lastinstructionaddress(bb)
        arg_zero = OIR.constant(0.0)
        arg_result = OIR.addinstruction!(bb, OIR.callpure(*, last_instruction_ssavalue, arg_zero))
        OIR.assign!(bb, :output, arg_result)

        input_vector = [10.0]
        f = OIR.compile(OIR.BasicBlockInterpreter, bb)
        @test f(input_vector).output == 0.0
    end
end

@testset "Inputs" begin
    bb = OIR.BasicBlock()
    x = OIR.addinput!(bb, :x)
    y = OIR.addinput!(bb, :y)
    z = OIR.addinput!(bb, :z)
    out = OIR.addinstruction!(bb, OIR.callpure(foreign_fun, x, y, z))
    OIR.assign!(bb, :result, out)

    # cannot be optimized to a constant since it depends on the inputs
    @test isa(OIR.instructionof(bb, out), OIR.AbstractCall)

    # println(bb)

    input = Dict(:z => 10.0, :y => 20.0, :x => 30.0)
    f = OIR.compile(OIR.BasicBlockInterpreter, bb)
    @test f(input).result ≈ foreign_fun(30.0, 20.0, 10.0)
end

@testset "Passes" begin
    @testset "Constant Propagation" begin
        bb = OIR.BasicBlock()
        x = OIR.constant(30.0)
        y = OIR.constant(20.0)
        z = OIR.constant(10.0)
        out = OIR.addinstruction!(bb, OIR.callpure(foreign_fun, x, y, z))
        OIR.assign!(bb, :result, out)
        @test isa(out, OIR.Const)

        # println(bb)

        input = []
        f = OIR.compile(OIR.BasicBlockInterpreter, bb)
        @test f(input).result ≈ foreign_fun(30.0, 20.0, 10.0)
    end
end

function compiledfunction(x::Vector)
    result = x[1]^3 + x[2]^2 + x[3]
    out = Dict{Symbol, Any}()
    out[:result] = result
    return OptimizingIR.namedtuple(out)
end

@testset "eval" begin
    bb = OIR.BasicBlock()
    in1 = OIR.addinput!(bb, :x)
    in2 = OIR.addinput!(bb, :y)
    in3 = OIR.addinput!(bb, :z)
    c3 = OIR.constant(3)
    c2 = OIR.constant(2)
    arg1 = OIR.addinstruction!(bb, OIR.callpure(^, in1, c3))
    arg2 = OIR.addinstruction!(bb, OIR.callpure(^, in2, c2))
    arg3 = in3
    s1 = OIR.addinstruction!(bb, OIR.callpure(+, arg1, arg2))
    s2 = OIR.addinstruction!(bb, OIR.callpure(+, s1, arg3))
    OIR.assign!(bb, :result, s2)

    input = [30.0, 20.0, 10.0]
    finterpreter = OIR.compile(OIR.BasicBlockInterpreter, bb)
    @test finterpreter(input) == compiledfunction(input)

    f = OIR.compile(OIR.Native, bb)
    @test f(input) == compiledfunction(input)
end

function benchmark_julia(x::Vector)
    v = zeros(Float64, 3)
    v[1] = x[1]
    v[2] = x[2]

    result = (((-( v[1] - v[2])) + 1.0 ) * 2.0) / 1.0

    return (v=v, result=result)
end

@testset "Benchmarks" begin

    bb = OIR.BasicBlock()
    in1 = OIR.addinput!(bb, :x)
    in2 = OIR.addinput!(bb, :y)

    argvec = OIR.addinstruction!(bb, OIR.callimpure(zeros, OIR.constant(Float64), OIR.constant(3)))

    OIR.addinstruction!(bb, OIR.SetIndex(argvec, in1, OIR.constant(1)))
    OIR.addinstruction!(bb, OIR.SetIndex(argvec, in2, OIR.constant(2)))

    OIR.assign!(bb, :v, argvec)

    arg1 = OIR.addinstruction!(bb, OIR.GetIndex(argvec, OIR.constant(1)))
    arg2 = OIR.addinstruction!(bb, OIR.GetIndex(argvec, OIR.constant(2)))

    # (((-( x[1] - x[2])) + 1.0 ) * 2.0) / 1.0
    arg3 = OIR.addinstruction!(bb, OIR.callpure(-, arg1, arg2))
    arg4 = OIR.addinstruction!(bb, OIR.callpure(-, arg3))
    arg5 = OIR.addinstruction!(bb, OIR.callpure(+, arg4, OIR.constant(1.0)))
    arg6 = OIR.addinstruction!(bb, OIR.callpure(*, arg5, OIR.constant(2.0)))
    arg7 = OIR.addinstruction!(bb, OIR.callpure(/, arg6, OIR.constant(1.0)))

    OIR.assign!(bb, :result, arg7)

    fnative = OIR.compile(OIR.Native, bb)
    finterpreter = OIR.compile(OIR.BasicBlockInterpreter, bb)

    input = [10.0, 20.0]

    result_native = fnative(input)
    result_interpreter = finterpreter(input)
    result_julia = benchmark_julia(input)

    @test result_native.result == result_julia.result
    @test result_native.v == result_julia.v
    @test result_interpreter.result == result_julia.result
    @test result_interpreter.v == result_julia.v

    println()
    println("Benchmarks")
    @time finterpreter(input)
    @time fnative(input)
    @time benchmark_julia(input)
    let
        el_interpreter = @elapsed finterpreter(input)
        el_native = @elapsed fnative(input)
        el_julia = @elapsed benchmark_julia(input)
        println("Interpreter Overhead = $(round(el_interpreter / el_julia, digits=1))x")
        println("Native Overhead = $(round(el_native / el_julia, digits=1))x")
    end
    println()
end
