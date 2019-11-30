
import OptimizingIR
const OIR = OptimizingIR
using Test

foreign_fun(a, b, c) = a^3 + b^2 + c
julia_basic_block_test_function(x::Vector) = (((-((10.0 * 2.0 + x[1]) / 1.0) + (x[1] + 10.0 * 2.0) + 1.0) * 1.0 / 2.0) + (0.0 * x[1]) + 1.0) * 1.0

function julia_native_test_function(x::Vector)
    result = x[1]^3 + x[2]^2 + x[3]
    out = Dict{Symbol, Any}()
    out[:result] = result
    return OptimizingIR.namedtuple(out)
end

# optrule(pure, commutative, hasleftidentity, hasrightidentity, identity_element)

const op_sum = OIR.Op(+, OIR.optrule(true, true, true, true, 0))
const op_sub = OIR.Op(-, OIR.optrule(true, false, false, true, 0))
const op_mul = OIR.Op(*, OIR.optrule(true, true, true, true, 1))
const op_div = OIR.Op(/, OIR.optrule(true, false, false, true, 1))
const op_pow = OIR.Op(^, OIR.optrule(true, false, false, true, 1))
const op_foreign_fun = OIR.Op(foreign_fun, OIR.optrule(true))

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

@testset "OptimizationRule" begin
    @test OIR.ispure(op_sum)
    @test !OIR.ispure(OIR.Op(zeros))
end

@testset "call" begin

    @testset "CallVararg" begin

        bb = OIR.BasicBlock()
        arg1 = OIR.addinput!(bb, :x)
        arg2 = OIR.constant(10.0)
        arg3 = OIR.constant(2.0)
        arg4 = OIR.addinstruction!(bb, OIR.call(op_foreign_fun, arg1, arg2, arg3))

        arg5 = OIR.addinput!(bb, :x)
        arg6 = OIR.constant(10.0)
        arg7 = OIR.constant(2.0)
        arg8 = OIR.addinstruction!(bb, OIR.call(op_foreign_fun, arg5, arg6, arg7))

        arg9 = OIR.addinstruction!(bb, OIR.call(op_sum, arg4, arg8))

        OIR.assign!(bb, OIR.Slot(:output), arg9)

        @test length(bb.instructions) == 2
        # println(bb)

        input = 20.0
        f = OIR.compile(OIR.BasicBlockInterpreter, bb)
        @test f([input]).output ≈ 2 * (input^3 + 10^2 + 2)
    end

    @testset "ImpureCall" begin
        bb = OIR.BasicBlock()
        arg1 = OIR.constant(Float64)
        arg2 = OIR.constant(3)
        arg3 = OIR.addinstruction!(bb, OIR.call(zeros, arg1, arg2))
        arg4 = OIR.addinstruction!(bb, OIR.call(zeros, arg1, arg2))
        @test length(bb.instructions) == 2
    end
end

@testset "GetIndex" begin
    bb = OIR.BasicBlock()
    arg1 = OIR.addinput!(bb, :x)
    arg2 = OIR.constant(2)
    arg3 = OIR.addinstruction!(bb, OIR.GetIndex(arg1, arg2)) # reads x[2]
    arg4 = OIR.constant(5.0)
    arg5 = OIR.addinstruction!(bb, OIR.call(op_mul, arg4, arg3))
    arg6 = OIR.addinstruction!(bb, OIR.GetIndex(arg1, arg2)) # reads x[2]
    arg7 = OIR.addinstruction!(bb, OIR.call(op_mul, arg6, arg5))
    OIR.assign!(bb, OIR.Slot(:output), arg7)

    @test length(bb.instructions) == 4
    # println(bb)

    f = OIR.compile(OIR.BasicBlockInterpreter, bb)
    @test f([[5.0, 6.0, 7.0]]).output ≈ 6.0 * 5.0 * 6.0
end

@testset "SetIndex" begin
    bb = OIR.BasicBlock()
    arginput = OIR.addinput!(bb, :x)
    arg1 = OIR.constant(Float64)
    arg3 = OIR.addinstruction!(bb, OIR.call(zeros, arg1, arginput))
    OIR.assign!(bb, OIR.Slot(:vec), arg3)
    arg4 = OIR.constant(1)
    arg_inspect = OIR.addinstruction!(bb, OIR.GetIndex(arg3, arg4))
    OIR.assign!(bb, OIR.Slot(:inspect1), arg_inspect)
    arg_input_value = OIR.constant(10)
    arg5 = OIR.addinstruction!(bb, OIR.SetIndex(arg3, arg_input_value, arg4))
    arg_inspect = OIR.addinstruction!(bb, OIR.GetIndex(arg3, arg4))
    OIR.assign!(bb, OIR.Slot(:inspect2), arg_inspect)
    arg6 = OIR.addinstruction!(bb, OIR.call(op_mul, OIR.constant(2.0), arg_inspect))
    OIR.assign!(bb, OIR.Slot(:inspect3), arg6)
    arg7 = OIR.addinstruction!(bb, OIR.call(op_mul, OIR.constant(1.0), arg6))
    arg8 = OIR.addinstruction!(bb, OIR.call(op_mul, arg7, OIR.constant(1.0)))
    arg9 = OIR.addinstruction!(bb, OIR.call(op_sum, arg8, OIR.constant(0.0)))
    arg10 = OIR.addinstruction!(bb, OIR.call(op_sum, OIR.constant(0.0), arg9))
    arg11 = OIR.addinstruction!(bb, OIR.call(op_sub, arg10, OIR.constant(0.0)))
    arg12 = OIR.addinstruction!(bb, OIR.call(op_div, arg11, OIR.constant(1.0)))
    OIR.assign!(bb, OIR.Slot(:inspect4), arg12)

    @test length(bb.instructions) == 5
    println(bb)

    input_vector = [3]
    f = OIR.compile(OIR.BasicBlockInterpreter, bb)
    result = f(input_vector)
    @test result.inspect1 ≈ 0.0
    @test result.inspect2 ≈ 10.0
    @test isa(result.inspect2, Float64)
    @test result.inspect3 ≈ 20.0
    @test result.inspect4 ≈ 20.0
    @test result.vec == [ 10.0, 0.0, 0.0 ]
end

@testset "Basic Block" begin
    bb = OIR.BasicBlock()
    x = OIR.addinput!(bb, :x)
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
    OIR.assign!(bb, OIR.Slot(:output), arg18)

    @test length(bb.instructions) == 8
    # println(bb)

    @testset "BasicBlockInterpreter" begin
        input_vector = [10.0]
        f = OIR.compile(OIR.BasicBlockInterpreter, bb)
        result = f(input_vector)
        @test result.output ≈ julia_basic_block_test_function(input_vector)
    end

    @testset "Multiply by zero" begin
        last_instruction_ssavalue = OIR.lastinstructionaddress(bb)
        arg_zero = OIR.constant(0.0)
        arg_result = OIR.addinstruction!(bb, OIR.call(op_mul, last_instruction_ssavalue, arg_zero))
        OIR.assign!(bb, OIR.Slot(:output), arg_result)

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
    out = OIR.addinstruction!(bb, OIR.call(op_foreign_fun, x, y, z))
    OIR.assign!(bb, OIR.Slot(:result), out)

    # cannot be optimized to a constant since it depends on the inputs
    @test isa(OIR.instructionof(bb, out), OIR.AbstractCall)
    @test length(bb.instructions) == 1

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
        out = OIR.addinstruction!(bb, OIR.call(op_foreign_fun, x, y, z))
        OIR.assign!(bb, OIR.Slot(:result), out)
        @test isa(out, OIR.Const)

        # println(bb)

        input = []
        f = OIR.compile(OIR.BasicBlockInterpreter, bb)
        @test f(input).result ≈ foreign_fun(30.0, 20.0, 10.0)
    end
end

@testset "Slots" begin
    bb = OIR.BasicBlock()
    x = OIR.addinput!(bb, :x)
    z = OIR.constant(1.0)
    slot = OIR.Slot(:slot)
    OIR.assign!(bb, slot, z)
    out = OIR.addinstruction!(bb, OIR.call(op_sum, OIR.follow(bb, slot), x))
    OIR.assign!(bb, slot, out)
    out = OIR.addinstruction!(bb, OIR.call(op_sum, OIR.follow(bb, slot), x))
    OIR.assign!(bb, OIR.Slot(:output), out)

    @test length(bb.instructions) == 2
    # println(bb)

    input = [10.0]
    f = OIR.compile(OIR.BasicBlockInterpreter, bb)
    @test f(input).slot == 11.0
    @test f(input).output == 1.0 + 10.0 + 10.0

    fc = OIR.compile(OIR.Native, bb)
    @test fc(input).slot == 11.0
    @test fc(input).output == 1.0 + 10.0 + 10.0
end

@testset "Native" begin
    bb = OIR.BasicBlock()
    in1 = OIR.addinput!(bb, :x)
    in2 = OIR.addinput!(bb, :y)
    in3 = OIR.addinput!(bb, :z)
    c3 = OIR.constant(3)
    c2 = OIR.constant(2)
    arg1 = OIR.addinstruction!(bb, OIR.call(op_pow, in1, c3))
    arg2 = OIR.addinstruction!(bb, OIR.call(op_pow, in2, c2))
    arg3 = in3
    s1 = OIR.addinstruction!(bb, OIR.call(op_sum, arg1, arg2))
    s2 = OIR.addinstruction!(bb, OIR.call(op_sum, s1, arg3))
    OIR.assign!(bb, OIR.Slot(:result), s2)

    input = [30.0, 20.0, 10.0]
    finterpreter = OIR.compile(OIR.BasicBlockInterpreter, bb)
    @test finterpreter(input) == julia_native_test_function(input)

    f = OIR.compile(OIR.Native, bb)
    @test f(input) == julia_native_test_function(input)
end

@testset "Benchmarks" begin
    include("benchmarks.jl")
end
