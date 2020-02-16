
import OptimizingIR
const OIR = OptimizingIR
using Test

@testset "Graph" begin
    include("test_graph.jl")
end

foreign_fun(a, b, c) = a^3 + b^2 + c
julia_basic_block_test_function(x::Vector) = (((-((10.0 * 2.0 + x[1]) / 1.0) + (x[1] + 10.0 * 2.0) + 1.0) * 1.0 / 2.0) + (0.0 * x[1]) + 1.0) * 1.0

function julia_native_test_function(x::Vector)
    result = x[1]^3 + x[2]^2 + x[3]
    out = Dict{Symbol, Any}()
    out[:result] = result
    return OptimizingIR.namedtuple(out)
end

const op_sum = OIR.Op(+, pure=true, commutative=true, hasleftidentity=true, hasrightidentity=true, identity_element=0)
const op_sub = OIR.Op(-, pure=true, hasrightidentity=true, identity_element=0)
const op_mul = OIR.Op(*, pure=true, commutative=true, hasleftidentity=true, hasrightidentity=true, identity_element=1)
const op_div = OIR.Op(/, pure=true, hasrightidentity=true, identity_element=1)
const op_pow = OIR.Op(^, pure=true, hasrightidentity=true, identity_element=1)
const op_foreign_fun = OIR.Op(foreign_fun, pure=true)
const op_zeros = OIR.Op(zeros)

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
    @test OIR.is_pure(op_sum)
    @test !OIR.is_pure(op_zeros)
end

@testset "AbstractValue" begin
    @test OIR.is_immutable(OIR.NullPointer())
    @test OIR.is_immutable(OIR.SSAValue(1))
    @test OIR.is_immutable(OIR.Const(1.0))
    @test OIR.is_immutable(OIR.ImmutableVariable(:sym))
    @test !OIR.is_immutable(OIR.MutableVariable(:sym))
    @test OIR.is_immutable(OIR.Variable{OIR.Immutable})

    @test !OIR.is_mutable(OIR.NullPointer())
    @test !OIR.is_mutable(OIR.SSAValue(1))
    @test !OIR.is_mutable(OIR.Const(1.0))
    @test !OIR.is_mutable(OIR.ImmutableVariable(:sym))
    @test OIR.is_mutable(OIR.MutableVariable(:sym))
end

@testset "call" begin

    @testset "CallVararg" begin

        bb = OIR.BasicBlock()
        var_x = OIR.ImmutableVariable(:x)
        OIR.addinput!(bb, var_x)
        arg2 = OIR.constant(10.0)
        arg3 = OIR.constant(2.0)
        arg4 = OIR.addinstruction!(bb, OIR.call(op_foreign_fun, var_x, arg2, arg3))

        var_x_2nd_instance = OIR.ImmutableVariable(:x)
        OIR.addinput!(bb, var_x_2nd_instance)
        arg6 = OIR.constant(10.0)
        arg7 = OIR.constant(2.0)
        arg8 = OIR.addinstruction!(bb, OIR.call(op_foreign_fun, var_x_2nd_instance, arg6, arg7))
        arg9 = OIR.addinstruction!(bb, OIR.call(op_sum, arg4, arg8))
        OIR.assign!(bb, OIR.ImmutableVariable(:output), arg9)
        @test length(bb.instructions) == 2

        # println(bb)

        input = 20.0
        finterpreter = OIR.compile(OIR.BasicBlockInterpreter, bb)
        @test finterpreter([input]).output ≈ 2 * (input^3 + 10^2 + 2)

        fnative = OIR.compile(OIR.Native, bb)
        @test fnative([input]).output ≈ 2 * (input^3 + 10^2 + 2)
    end

    @testset "ImpureCall" begin
        bb = OIR.BasicBlock()
        arg1 = OIR.constant(Float64)
        arg2 = OIR.constant(3)
        arg3 = OIR.addinstruction!(bb, OIR.call(op_zeros, arg1, arg2))
        arg4 = OIR.addinstruction!(bb, OIR.call(op_zeros, arg1, arg2))
        @test length(bb.instructions) == 2
    end
end

@testset "GetIndex" begin
    bb = OIR.BasicBlock()
    var_x = OIR.ImmutableVariable(:x)
    OIR.addinput!(bb, var_x)
    arg2 = OIR.constant(2)
    arg3 = OIR.addinstruction!(bb, OIR.callgetindex(var_x, arg2)) # reads x[2]
    arg4 = OIR.constant(5.0)
    arg5 = OIR.addinstruction!(bb, OIR.call(op_mul, arg4, arg3))
    arg6 = OIR.addinstruction!(bb, OIR.callgetindex(var_x, arg2)) # reads x[2]
    arg7 = OIR.addinstruction!(bb, OIR.call(op_mul, arg6, arg5))
    OIR.assign!(bb, OIR.ImmutableVariable(:output), arg7)
    @test length(bb.instructions) == 3

    # println(bb)

    finterpreter = OIR.compile(OIR.BasicBlockInterpreter, bb)
    @test finterpreter([[5.0, 6.0, 7.0]]).output ≈ 6.0 * 5.0 * 6.0

    fnative = OIR.compile(OIR.Native, bb)
    @test fnative([[5.0, 6.0, 7.0]]).output ≈ 6.0 * 5.0 * 6.0
end

@testset "SetIndex" begin
    bb = OIR.BasicBlock()
    var_x = OIR.ImmutableVariable(:x)
    OIR.addinput!(bb, var_x)
    arg1 = OIR.constant(Float64)
    arg3 = OIR.addinstruction!(bb, OIR.call(op_zeros, arg1, var_x))
    var_vec = OIR.MutableVariable(:vec)
    OIR.assign!(bb, var_vec, arg3)
    arg4 = OIR.constant(1)
    arg_inspect = OIR.addinstruction!(bb, OIR.callgetindex(var_vec, arg4))
    OIR.assign!(bb, OIR.ImmutableVariable(:inspect1), arg_inspect)
    arg_input_value = OIR.constant(10)
    arg5 = OIR.addinstruction!(bb, OIR.callsetindex(var_vec, arg_input_value, arg4))
    arg_inspect = OIR.addinstruction!(bb, OIR.callgetindex(var_vec, arg4))
    OIR.assign!(bb, OIR.ImmutableVariable(:inspect2), arg_inspect)
    arg6 = OIR.addinstruction!(bb, OIR.call(op_mul, OIR.constant(2.0), arg_inspect))
    OIR.assign!(bb, OIR.ImmutableVariable(:inspect3), arg6)
    arg7 = OIR.addinstruction!(bb, OIR.call(op_mul, OIR.constant(1.0), arg6))
    arg8 = OIR.addinstruction!(bb, OIR.call(op_mul, arg7, OIR.constant(1.0)))
    arg9 = OIR.addinstruction!(bb, OIR.call(op_sum, arg8, OIR.constant(0.0)))
    arg10 = OIR.addinstruction!(bb, OIR.call(op_sum, OIR.constant(0.0), arg9))
    arg11 = OIR.addinstruction!(bb, OIR.call(op_sub, arg10, OIR.constant(0.0)))
    arg12 = OIR.addinstruction!(bb, OIR.call(op_div, arg11, OIR.constant(1.0)))
    OIR.assign!(bb, OIR.ImmutableVariable(:inspect4), arg12)
    @test length(bb.instructions) == 5

    println(bb)

    input_vector = [3]

    let
        finterpreter = OIR.compile(OIR.BasicBlockInterpreter, bb)
        result = finterpreter(input_vector)
        @test result.inspect1 ≈ 0.0
        @test result.inspect2 ≈ 10.0
        @test isa(result.inspect2, Float64)
        @test result.inspect3 ≈ 20.0
        @test result.inspect4 ≈ 20.0
        @test result.vec == [ 10.0, 0.0, 0.0 ]
    end

    let
        fnative = OIR.compile(OIR.Native, bb)
        result = fnative(input_vector)
        @test result.inspect1 ≈ 0.0
        @test result.inspect2 ≈ 10.0
        @test isa(result.inspect2, Float64)
        @test result.inspect3 ≈ 20.0
        @test result.inspect4 ≈ 20.0
        @test result.vec == [ 10.0, 0.0, 0.0 ]
    end
end

@testset "Basic Block" begin
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
    OIR.assign!(bb, OIR.ImmutableVariable(:output), arg18)
    @test length(bb.instructions) == 8

    # println(bb)

    let
        input_vector = [10.0]
        f = OIR.compile(OIR.BasicBlockInterpreter, bb)
        result = f(input_vector)
        @test result.output ≈ julia_basic_block_test_function(input_vector)
    end

    let
        input_vector = [10.0]
        f = OIR.compile(OIR.Native, bb)
        result = f(input_vector)
        @test result.output ≈ julia_basic_block_test_function(input_vector)
    end

    @testset "Multiply by zero" begin
        last_instruction_ssavalue = OIR.SSAValue(lastindex(bb.instructions))
        arg_zero = OIR.constant(0.0)
        arg_result = OIR.addinstruction!(bb, OIR.call(op_mul, last_instruction_ssavalue, arg_zero))
        OIR.assign!(bb, OIR.ImmutableVariable(:output), arg_result)

        let
            input_vector = [10.0]
            f = OIR.compile(OIR.BasicBlockInterpreter, bb)
            @test f(input_vector).output == 0.0
        end

        let
            input_vector = [10.0]
            f = OIR.compile(OIR.Native, bb)
            @test f(input_vector).output == 0.0
        end
    end
end

@testset "Inputs" begin
    bb = OIR.BasicBlock()
    x = OIR.ImmutableVariable(:x)
    y = OIR.ImmutableVariable(:y)
    z = OIR.ImmutableVariable(:z)
    OIR.addinput!(bb, x)
    OIR.addinput!(bb, y)
    OIR.addinput!(bb, z)
    out = OIR.addinstruction!(bb, OIR.call(op_foreign_fun, x, y, z))
    OIR.assign!(bb, OIR.ImmutableVariable(:result), out)

    # cannot be optimized to a constant since it depends on the inputs
    @test length(bb.instructions) == 1

    # println(bb)

    input = Dict(OIR.ImmutableVariable(:z) => 10.0, OIR.ImmutableVariable(:y) => 20.0, OIR.ImmutableVariable(:x) => 30.0)

    let
        f = OIR.compile(OIR.BasicBlockInterpreter, bb)
        @test f(input).result ≈ foreign_fun(30.0, 20.0, 10.0)
    end

    let
        f = OIR.compile(OIR.Native, bb)
        @test f(input).result ≈ foreign_fun(30.0, 20.0, 10.0)
    end
end

@testset "Passes" begin
    @testset "Constant Propagation" begin
        bb = OIR.BasicBlock()
        x = OIR.constant(30.0)
        y = OIR.constant(20.0)
        z = OIR.constant(10.0)
        out = OIR.addinstruction!(bb, OIR.call(op_foreign_fun, x, y, z))
        OIR.assign!(bb, OIR.ImmutableVariable(:result), out)
        @test isa(out, OIR.Const)

        # println(bb)

        input = []

        let
            f = OIR.compile(OIR.BasicBlockInterpreter, bb)
            @test f(input).result ≈ foreign_fun(30.0, 20.0, 10.0)
        end

        let
            f = OIR.compile(OIR.Native, bb)
            @test f(input).result ≈ foreign_fun(30.0, 20.0, 10.0)
        end
    end
end

@testset "Variables" begin
    bb = OIR.BasicBlock()
    x = OIR.ImmutableVariable(:x)
    OIR.addinput!(bb, x)
    z = OIR.constant(1.0)
    cnst = OIR.ImmutableVariable(:cnst)
    OIR.assign!(bb, cnst, z)
    slot = OIR.ImmutableVariable(:slot)
    OIR.assign!(bb, slot, z)
    out = OIR.addinstruction!(bb, OIR.call(op_sum, OIR.follow(bb, slot), x))
    OIR.assign!(bb, slot, out)
    out = OIR.addinstruction!(bb, OIR.call(op_sum, OIR.follow(bb, slot), x))
    OIR.assign!(bb, OIR.ImmutableVariable(:output), out)
    @test length(bb.instructions) == 2

    # println(bb)

    input = [10.0]

    let
        f = OIR.compile(OIR.BasicBlockInterpreter, bb)
        @test f(input).slot == 11.0
        @test f(input).output == 1.0 + 10.0 + 10.0
        @test f(input).cnst == 1.0
    end

    let
        fc = OIR.compile(OIR.Native, bb)
        @test fc(input).slot == 11.0
        @test fc(input).output == 1.0 + 10.0 + 10.0
        @test fc(input).cnst == 1.0
    end
end

@testset "Native" begin
    bb = OIR.BasicBlock()
    in1 = OIR.ImmutableVariable(:x)
    in2 = OIR.ImmutableVariable(:y)
    in3 = OIR.ImmutableVariable(:z)
    OIR.addinput!(bb, in1)
    OIR.addinput!(bb, in2)
    OIR.addinput!(bb, in3)
    c3 = OIR.constant(3)
    c2 = OIR.constant(2)
    arg1 = OIR.addinstruction!(bb, OIR.call(op_pow, in1, c3))
    arg2 = OIR.addinstruction!(bb, OIR.call(op_pow, in2, c2))
    arg3 = in3
    s1 = OIR.addinstruction!(bb, OIR.call(op_sum, arg1, arg2))
    s2 = OIR.addinstruction!(bb, OIR.call(op_sum, s1, arg3))
    OIR.assign!(bb, OIR.ImmutableVariable(:result), s2)

    input = [30.0, 20.0, 10.0]

    let
        finterpreter = OIR.compile(OIR.BasicBlockInterpreter, bb)
        @test finterpreter(input) == julia_native_test_function(input)
    end

    let
        f = OIR.compile(OIR.Native, bb)
        @test f(input) == julia_native_test_function(input)
    end
end

#=
function fif(x)
   y = 0
   if x > 1
       y = y + 1
   end
   return y * 2
end

#=
1 ─      y = 0
│   %2 = x > 1
└──      goto #3 if not %2
2 ─      y = y + 1
3 ┄ %5 = y * 2
└──      return %5
=#

@testset "CFG" begin
    cfg = OIR.CFG()
    bb = cfg.start
    OIR.assign!(bb, OIR.Variable(:y), OIR.constant(0))
end
=#

@testset "Benchmarks" begin
    include("benchmarks.jl")
end
