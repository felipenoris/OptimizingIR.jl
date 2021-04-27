
import OptimizingIR
const OIR = OptimizingIR
using Test

@testset "Graph" begin
    include("test_graph.jl")
end

foreign_fun(a, b, c) = a^3 + b^2 + c
julia_basic_block_test_function(x::Number) = (((-((10.0 * 2.0 + x) / 1.0) + (x + 10.0 * 2.0) + 1.0) * 1.0 / 2.0) + (0.0 * x) + 1.0) * 1.0
julia_native_test_function(x::Number, y::Number, z::Number) = x^3 + y^2 + z

function push_into_two_args(num::Integer, a::Vector, b::Vector)
    push!(a, num)
    push!(b, num)
end

const OP_SUM = OIR.Op(+, pure=true, commutative=true, hasleftidentity=true, hasrightidentity=true, identity_element=0)
const OP_SUB = OIR.Op(-, pure=true, hasrightidentity=true, identity_element=0)
const OP_MUL = OIR.Op(*, pure=true, commutative=true, hasleftidentity=true, hasrightidentity=true, identity_element=1)
const OP_DIV = OIR.Op(/, pure=true, hasrightidentity=true, identity_element=1)
const OP_POW = OIR.Op(^, pure=true, hasrightidentity=true, identity_element=1)
const OP_FOREIGN_FUN = OIR.Op(foreign_fun, pure=true)
const OP_ZEROS = OIR.Op(zeros)

const OP_GETINDEX = OIR.Op(Base.getindex, pure=true)
const OP_SETINDEX = OIR.Op(Base.setindex!, pure=false, mutable_arg=1)

const OP_PUSH_INTO_TWO_ARGS = OIR.Op(push_into_two_args, mutable_arg=(2, 3))

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

    @testset "Vector constructor" begin
        v = collect(1:3)
        tb = OIR.LookupTable(v)

        for (i, v) in enumerate(v)
            @test OIR.indexof(tb, v) == i
        end
    end
end

@testset "OptimizationRule" begin
    @test OIR.is_pure(OP_SUM)
    @test !OIR.is_pure(OP_ZEROS)
    @test !OIR.is_impure(OP_SUM)
    @test OIR.is_impure(OP_ZEROS)
    @test !OIR.has_left_identity_property(OP_ZEROS)
    @test OIR.has_left_identity_property(OP_SUM)
    @test !OIR.has_right_identity_property(OP_ZEROS)
    @test OIR.has_right_identity_property(OP_SUM)
    @test OIR.has_identity_property(OP_SUB)
    @test !OIR.has_identity_property(OP_ZEROS)
    @test OIR.has_identity_element(OP_SUM)
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
        arg4 = OIR.addinstruction!(bb, OIR.call(OP_FOREIGN_FUN, var_x, arg2, arg3))

        var_x_2nd_instance = OIR.ImmutableVariable(:x)
        OIR.addinput!(bb, var_x_2nd_instance)
        arg6 = OIR.constant(10.0)
        arg7 = OIR.constant(2.0)
        arg8 = OIR.addinstruction!(bb, OIR.call(OP_FOREIGN_FUN, var_x_2nd_instance, arg6, arg7))
        arg9 = OIR.addinstruction!(bb, OIR.call(OP_SUM, arg4, arg8))
        var_output = OIR.ImmutableVariable(:output)
        OIR.addoutput!(bb, var_output)
        OIR.assign!(bb, var_output, arg9)

        println(bb)
        @test length(bb.instructions) == 3

        input = 20.0
        finterpreter = OIR.compile(OIR.BasicBlockInterpreter, bb)
        @test finterpreter(input) ≈ 2 * (input^3 + 10^2 + 2)

        fnative = OIR.compile(OIR.Native, bb)
        @test fnative(input) ≈ 2 * (input^3 + 10^2 + 2)
    end

    @testset "ImpureCall" begin
        bb = OIR.BasicBlock()
        arg1 = OIR.constant(Float64)
        arg2 = OIR.constant(3)
        arg3 = OIR.addinstruction!(bb, OIR.call(OP_ZEROS, arg1, arg2))
        arg4 = OIR.addinstruction!(bb, OIR.call(OP_ZEROS, arg1, arg2))
        @test length(bb.instructions) == 2
    end
end

@testset "OP_GETINDEX" begin
    bb = OIR.BasicBlock()
    var_x = OIR.ImmutableVariable(:x)
    OIR.addinput!(bb, var_x)
    arg2 = OIR.constant(2)
    arg3 = OIR.addinstruction!(bb, OIR.call(OP_GETINDEX, var_x, arg2)) # reads x[2]
    arg4 = OIR.constant(5.0)
    arg5 = OIR.addinstruction!(bb, OIR.call(OP_MUL, arg4, arg3))
    arg6 = OIR.addinstruction!(bb, OIR.call(OP_GETINDEX, var_x, arg2)) # reads x[2]
    arg7 = OIR.addinstruction!(bb, OIR.call(OP_MUL, arg6, arg5))
    var_output = OIR.ImmutableVariable(:output)
    OIR.addoutput!(bb, var_output)
    OIR.assign!(bb, var_output, arg7)
    @test length(bb.instructions) == 4

    # println(bb)

    finterpreter = OIR.compile(OIR.BasicBlockInterpreter, bb)
    @test finterpreter([5.0, 6.0, 7.0]) ≈ 6.0 * 5.0 * 6.0

    fnative = OIR.compile(OIR.Native, bb)
    @test fnative([5.0, 6.0, 7.0]) ≈ 6.0 * 5.0 * 6.0
end

@testset "OP_SETINDEX" begin
    bb = OIR.BasicBlock()
    var_x = OIR.ImmutableVariable(:x)
    OIR.addinput!(bb, var_x)
    arg1 = OIR.constant(Float64)
    arg3 = OIR.addinstruction!(bb, OIR.call(OP_ZEROS, arg1, var_x))
    var_vec = OIR.MutableVariable(:vec)
    OIR.assign!(bb, var_vec, arg3)
    arg4 = OIR.constant(1)
    arg_inspect = OIR.addinstruction!(bb, OIR.call(OP_GETINDEX, var_vec, arg4))
    var_inspect1 = OIR.ImmutableVariable(:inspect1)
    OIR.assign!(bb, var_inspect1, arg_inspect)
    arg_input_value = OIR.constant(10)
    arg5 = OIR.addinstruction!(bb, OIR.call(OP_SETINDEX, var_vec, arg_input_value, arg4))
    arg_inspect = OIR.addinstruction!(bb, OIR.call(OP_GETINDEX, var_vec, arg4))
    var_inspect2 = OIR.ImmutableVariable(:inspect2)
    OIR.assign!(bb, var_inspect2, arg_inspect)
    arg6 = OIR.addinstruction!(bb, OIR.call(OP_MUL, OIR.constant(2.0), arg_inspect))
    var_inspect3 = OIR.ImmutableVariable(:inspect3)
    OIR.assign!(bb, var_inspect3, arg6)
    arg7 = OIR.addinstruction!(bb, OIR.call(OP_MUL, OIR.constant(1.0), arg6))
    arg8 = OIR.addinstruction!(bb, OIR.call(OP_MUL, arg7, OIR.constant(1.0)))
    arg9 = OIR.addinstruction!(bb, OIR.call(OP_SUM, arg8, OIR.constant(0.0)))
    arg10 = OIR.addinstruction!(bb, OIR.call(OP_SUM, OIR.constant(0.0), arg9))
    arg11 = OIR.addinstruction!(bb, OIR.call(OP_SUB, arg10, OIR.constant(0.0)))
    arg12 = OIR.addinstruction!(bb, OIR.call(OP_DIV, arg11, OIR.constant(1.0)))
    var_inspect4 = OIR.ImmutableVariable(:inspect4)
    OIR.assign!(bb, var_inspect4, arg12)
    @test length(bb.instructions) == 10

    OIR.addoutput!(bb, var_vec)
    OIR.addoutput!(bb, var_inspect1)
    OIR.addoutput!(bb, var_inspect2)
    OIR.addoutput!(bb, var_inspect3)
    OIR.addoutput!(bb, var_inspect4)

    println(bb)

    let
        finterpreter = OIR.compile(OIR.BasicBlockInterpreter, bb)
        out_vec, out_inspect1, out_inspect2, out_inspect3, out_inspect4 = finterpreter(3)
        @test out_inspect1 ≈ 0.0
        @test out_inspect2 ≈ 10.0
        @test isa(out_inspect2, Float64)
        @test out_inspect3 ≈ 20.0
        @test out_inspect4 ≈ 20.0
        @test out_vec == [ 10.0, 0.0, 0.0 ]
    end

    let
        fnative = OIR.compile(OIR.Native, bb)
        out_vec, out_inspect1, out_inspect2, out_inspect3, out_inspect4 = fnative(3)
        @test out_inspect1 ≈ 0.0
        @test out_inspect2 ≈ 10.0
        @test isa(out_inspect2, Float64)
        @test out_inspect3 ≈ 20.0
        @test out_inspect4 ≈ 20.0
        @test out_vec == [ 10.0, 0.0, 0.0 ]
    end
end

@testset "Basic Block" begin
    bb = OIR.BasicBlock()
    x = OIR.ImmutableVariable(:x)
    @test !OIR.has_symbol(bb, :x)
    OIR.addinput!(bb, x)
    @test OIR.has_symbol(bb, :x)
    arg1 = OIR.constant(10.0)
    arg2 = OIR.constant(2.0)
    arg3 = OIR.addinstruction!(bb, OIR.call(OP_MUL, arg1, arg2))
    arg4 = OIR.addinstruction!(bb, OIR.call(OP_SUM, arg3, x))
    arg5 = OIR.constant(1.0)
    arg6 = OIR.addinstruction!(bb, OIR.call(OP_DIV, arg4, arg5))
    arg7 = OIR.addinstruction!(bb, OIR.call(OP_SUB, arg6))
    arg8 = OIR.addinstruction!(bb, OIR.call(OP_SUM, x, arg3))
    arg9 = OIR.addinstruction!(bb, OIR.call(OP_SUM, arg8, arg7))
    arg10 = OIR.addinstruction!(bb, OIR.call(OP_SUM, arg9, arg5))
    arg11 = OIR.addinstruction!(bb, OIR.call(OP_MUL, arg10, arg5))
    arg12 = OIR.addinstruction!(bb, OIR.call(OP_DIV, arg11, arg2))
    arg13 = OIR.constant(0.0)
    arg14 = OIR.addinstruction!(bb, OIR.call(OP_MUL, arg13, x))
    arg15 = OIR.addinstruction!(bb, OIR.call(OP_SUM, arg14, arg12))
    arg16 = OIR.constant(1.0)
    arg17 = OIR.addinstruction!(bb, OIR.call(OP_SUM, arg16, arg15))
    arg18 = OIR.addinstruction!(bb, OIR.call(OP_MUL, arg16, arg17))
    @test !OIR.has_symbol(bb, :output)
    var_output = OIR.MutableVariable(:output)
    OIR.addoutput!(bb, var_output)
    @test OIR.has_symbol(bb, :output)
    OIR.assign!(bb, var_output, arg18)
    @test length(bb.instructions) == 9

    # println(bb)

    let
        input = 10.0
        f = OIR.compile(OIR.BasicBlockInterpreter, bb)
        @test f(input) ≈ julia_basic_block_test_function(input)
    end

    let
        input = 10.0
        f = OIR.compile(OIR.Native, bb)
        @test f(input) ≈ julia_basic_block_test_function(input)
    end

    @testset "Multiply by zero" begin
        last_instruction_ssavalue = OIR.SSAValue(lastindex(bb.instructions))
        arg_zero = OIR.constant(0.0)
        arg_result = OIR.addinstruction!(bb, OIR.call(OP_MUL, last_instruction_ssavalue, arg_zero))
        OIR.assign!(bb, var_output, arg_result)

        let
            f = OIR.compile(OIR.BasicBlockInterpreter, bb)
            @test f(10.0) == 0.0
        end

        let
            f = OIR.compile(OIR.Native, bb)
            @test f(10.0) == 0.0
        end
    end
end

@testset "Inputs" begin
    bb = OIR.BasicBlock()
    x = OIR.ImmutableVariable(:x)
    y = OIR.ImmutableVariable(:y)
    z = OIR.ImmutableVariable(:z)
    @test OIR.addinput!(bb, x) == 1
    @test OIR.addinput!(bb, y) == 2
    @test OIR.addinput!(bb, z) == 3
    @test OIR.addinput!(bb, OIR.ImmutableVariable(:y)) == 2
    out = OIR.addinstruction!(bb, OIR.call(OP_FOREIGN_FUN, x, y, z))
    var_result = OIR.ImmutableVariable(:result)
    @test OIR.addoutput!(bb, var_result) == 1
    @test OIR.addoutput!(bb, OIR.ImmutableVariable(:result)) == 1
    OIR.assign!(bb, var_result, out)

    # cannot be optimized to a constant since it depends on the inputs
    @test length(bb.instructions) == 2

    # println(bb)

    let
        f = OIR.compile(OIR.BasicBlockInterpreter, bb)
        @test f(30.0, 20.0, 10.0) ≈ foreign_fun(30.0, 20.0, 10.0)
    end

    let
        f = OIR.compile(OIR.Native, bb)
        @test f(30.0, 20.0, 10.0) ≈ foreign_fun(30.0, 20.0, 10.0)
    end
end

@testset "Passes" begin
    @testset "Constant Propagation" begin
        bb = OIR.BasicBlock()
        x = OIR.constant(30.0)
        y = OIR.constant(20.0)
        z = OIR.constant(10.0)
        out = OIR.addinstruction!(bb, OIR.call(OP_FOREIGN_FUN, x, y, z))
        var_result = OIR.ImmutableVariable(:result)
        OIR.addoutput!(bb, var_result)
        OIR.assign!(bb, var_result, out)
        @test isa(out, OIR.Const)

        # println(bb)

        let
            f = OIR.compile(OIR.BasicBlockInterpreter, bb)
            @test f() ≈ foreign_fun(30.0, 20.0, 10.0)
        end

        let
            f = OIR.compile(OIR.Native, bb)
            @test f() ≈ foreign_fun(30.0, 20.0, 10.0)
        end
    end
end

@testset "Variables" begin
    bb = OIR.BasicBlock()
    x = OIR.ImmutableVariable(:x)
    OIR.addinput!(bb, x)
    z = OIR.constant(1.0)
    var_cnst = OIR.ImmutableVariable(:cnst)
    OIR.assign!(bb, var_cnst, z)
    var_slot = OIR.MutableVariable(:slot)
    OIR.assign!(bb, var_slot, z)
    out = OIR.addinstruction!(bb, OIR.call(OP_SUM, var_slot, x))
    OIR.assign!(bb, var_slot, out)
    out = OIR.addinstruction!(bb, OIR.call(OP_SUM, var_slot, x))
    var_output = OIR.ImmutableVariable(:output)
    OIR.assign!(bb, var_output, out)
    @test length(bb.instructions) == 6

    OIR.addoutput!(bb, var_cnst)
    OIR.addoutput!(bb, var_slot)
    OIR.addoutput!(bb, var_output)

    # println(bb)

    input = 10.0

    let
        f = OIR.compile(OIR.BasicBlockInterpreter, bb)
        cnst, slot, output = f(input)
        @test slot == 11.0
        @test output == 1.0 + 10.0 + 10.0
        @test cnst == 1.0
    end

    let
        f = OIR.compile(OIR.BasicBlockInterpreter, OIR.CompiledBasicBlock(bb))
        cnst, slot, output = f(input)
        @test slot == 11.0
        @test output == 1.0 + 10.0 + 10.0
        @test cnst == 1.0
    end

    let
        mem_buff = Vector{Any}(undef, 10_000)
        input_buff = Vector{Any}(undef, 1_000)

        f = OIR.BasicBlockInterpreter(bb, mem_buff, input_buff)
        cnst, slot, output = f(input)
        @test slot == 11.0
        @test output == 1.0 + 10.0 + 10.0
        @test cnst == 1.0

        @test length(mem_buff) == 10_000
        @test length(input_buff) == 1_000
    end

    let
        f = OIR.compile(OIR.Native, bb)
        cnst, slot, output = f(input)
        @test slot == 11.0
        @test output == 1.0 + 10.0 + 10.0
        @test cnst == 1.0
    end

    let
        f = OIR.compile(OIR.Native, OIR.CompiledBasicBlock(bb))
        cnst, slot, output = f(input)
        @test slot == 11.0
        @test output == 1.0 + 10.0 + 10.0
        @test cnst == 1.0
    end
end

@testset "has_symbol" begin
    @testset "input" begin
        bb = OIR.BasicBlock()
        @test !OIR.has_symbol(bb, :x)
        OIR.addinput!(bb, OIR.ImmutableVariable(:x))
        @test OIR.has_symbol(bb, :x)
    end

    @testset "locals" begin
        bb = OIR.BasicBlock()
        @test !OIR.has_symbol(bb, :x)
        OIR.assign!(bb, OIR.ImmutableVariable(:x), OIR.constant(1.0))
        @test OIR.has_symbol(bb, :x)
        @test !OIR.has_symbol(bb, :y)
        OIR.assign!(bb, OIR.MutableVariable(:y), OIR.constant(1.0))
        @test OIR.has_symbol(bb, :y)
    end

    @testset "output mut" begin
        bb = OIR.BasicBlock()
        @test !OIR.has_symbol(bb, :z)
        OIR.addoutput!(bb, OIR.MutableVariable(:z))
        @test OIR.has_symbol(bb, :z)
    end

    @testset "output immut" begin
        bb = OIR.BasicBlock()
        @test !OIR.has_symbol(bb, :z)
        OIR.addoutput!(bb, OIR.ImmutableVariable(:z))
        @test OIR.has_symbol(bb, :z)
    end
end

@testset "gensym" begin
    bb = OIR.BasicBlock()
    sym = OIR.generate_unique_variable_symbol(bb)
    OIR.addinput!(bb, OIR.ImmutableVariable(sym))
    new_sym = OIR.generate_unique_variable_symbol(bb)
    @test new_sym != sym
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
    arg1 = OIR.addinstruction!(bb, OIR.call(OP_POW, in1, c3))
    arg2 = OIR.addinstruction!(bb, OIR.call(OP_POW, in2, c2))
    arg3 = in3
    s1 = OIR.addinstruction!(bb, OIR.call(OP_SUM, arg1, arg2))
    s2 = OIR.addinstruction!(bb, OIR.call(OP_SUM, s1, arg3))
    var_result = OIR.ImmutableVariable(:result)
    OIR.assign!(bb, var_result, s2)
    OIR.addoutput!(bb, var_result)

    let
        finterpreter = OIR.compile(OIR.BasicBlockInterpreter, bb)
        @test finterpreter(30.0, 20.0, 10.0) == julia_native_test_function(30.0, 20.0, 10.0)
    end

    let
        f = OIR.compile(OIR.Native, bb)
        @test f(30.0, 20.0, 10.0) == julia_native_test_function(30.0, 20.0, 10.0)
    end
end

@testset "World Age Problem" begin

    function gen_and_run()
        bb = OIR.BasicBlock()
        input_var = OIR.ImmutableVariable(:x)
        OIR.addinput!(bb, input_var)
        c2 = OIR.constant(2)
        arg1 = OIR.addinstruction!(bb, OIR.call(OP_POW, input_var, c2))
        var_result = OIR.ImmutableVariable(:result)
        OIR.assign!(bb, var_result, arg1)
        OIR.addoutput!(bb, var_result)

        f = OIR.compile(OIR.Native, bb)
        @test Base.invokelatest(f, 2) == 4
    end

    gen_and_run()
end

@testset "can't mutate input" begin
    bb = OIR.BasicBlock()
    var_input = OIR.ImmutableVariable(:x)
    OIR.addinput!(bb, var_input)
    cnst_index = OIR.constant(1)
    cnst_val = OIR.constant(2)
    @test_throws AssertionError OIR.addinstruction!(bb, OIR.call(OP_SETINDEX, var_input, cnst_val, cnst_index))
    @test_throws AssertionError OIR.addinstruction!(bb, OIR.call(OP_PUSH_INTO_TWO_ARGS, cnst_val, cnst_val, cnst_val))

    var_mutable_a = OIR.MutableVariable(:a)
    var_mutable_b = OIR.MutableVariable(:b)
    OIR.addinstruction!(bb, OIR.call(OP_PUSH_INTO_TWO_ARGS, cnst_val, var_mutable_a, var_mutable_b))
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
