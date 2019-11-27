
#=
Benchmarks for BasicBlockInterpreter
  454.574 ns (12 allocations: 192 bytes)
  2.798 ns (0 allocations: 0 bytes)
Overhead = 160.9x
=#

import OptimizingIR
const OIR = OptimizingIR
using Test, BenchmarkTools

compiledfunction(x::Vector) = (((-((10.0 * 2.0 + x[1]) / 1.0) + (x[1] + 10.0 * 2.0) + 1.0) * 1.0 / 2.0) + (0.0 * x[1]) + 1.0) * 1.0

@testset "Ops" begin
    arg1 = OIR.SSAValue(1)
    arg2 = OIR.SSAValue(2)
    @test OIR.iscommutative( OIR.op(*, arg1, arg2) )
    @test OIR.iscommutative( OIR.op(+, arg1, arg2) )
    @test !OIR.iscommutative( OIR.op(/, arg1, arg2) )

    @testset "OpVararg" begin

        f3args(a,b,c) = a^3 + b^2 + c

        bb = OIR.BasicBlock()
        arg1 = OIR.addinput!(bb, :x)
        arg2 = OIR.addinstruction!(bb, OIR.Const(10.0))
        arg3 = OIR.addinstruction!(bb, OIR.Const(2.0))
        arg4 = OIR.addinstruction!(bb, OIR.op(f3args, arg1, arg2, arg3))

        arg5 = OIR.addinput!(bb, :x)
        arg6 = OIR.addinstruction!(bb, OIR.Const(10.0))
        arg7 = OIR.addinstruction!(bb, OIR.Const(2.0))
        arg8 = OIR.addinstruction!(bb, OIR.op(f3args, arg5, arg6, arg7))

        arg9 = OIR.addinstruction!(bb, OIR.op(+, arg4, arg8))

        OIR.assign!(bb, :output, arg9)

        # println(bb)

        @testset "BasicBlockInterpreter" begin
            input_vector = [20.0]
            interpreter = OIR.BasicBlockInterpreter(bb, input_vector)
            OIR.run_program!(interpreter)
            answer = 2 * (input_vector[1]^3 + 10^2 + 2)
            @test OIR.readslot(interpreter, :output) ≈ answer
        end
    end

    @testset "OpGetIndex" begin
        bb = OIR.BasicBlock()
        arg1 = OIR.addinput!(bb, :x)
        arg2 = OIR.addinstruction!(bb, OIR.Const(2))
        arg3 = OIR.addinstruction!(bb, OIR.OpGetIndex(arg1, arg2)) # reads x[2]
        arg4 = OIR.addinstruction!(bb, OIR.Const(5.0))
        arg5 = OIR.addinstruction!(bb, OIR.op(*, arg4, arg3))
        arg6 = OIR.addinstruction!(bb, OIR.OpGetIndex(arg1, arg2)) # reads x[2]
        arg7 = OIR.addinstruction!(bb, OIR.op(*, arg6, arg5))
        OIR.assign!(bb, :output, arg7)

        # println(bb)

        @testset "BasicBlockInterpreter" begin
            # input x is the first element of the input_vector
            input_vector = [[5.0, 6.0, 7.0]]
            interpreter = OIR.BasicBlockInterpreter(bb, input_vector)
            OIR.run_program!(interpreter)
            answer = 6.0 * 5.0 * 6.0
            @test OIR.readslot(interpreter, :output) ≈ answer
        end
    end

    @testset "OpSetIndex" begin
        bb = OIR.BasicBlock()
        arg1 = OIR.addinstruction!(bb, OIR.Const(Float64))
        arg2 = OIR.addinstruction!(bb, OIR.Const(3))
        arg3 = OIR.addinstruction!(bb, OIR.op(zeros, arg1, arg2))
        OIR.assign!(bb, :vec, arg3)
        arg4 = OIR.addinstruction!(bb, OIR.Const(1))
        arg_inspect = OIR.addinstruction!(bb, OIR.OpGetIndex(arg3, arg4))
        OIR.assign!(bb, :inspect1, arg_inspect)
        arg_input_value = OIR.addinstruction!(bb, OIR.Const(10))
        arg5 = OIR.addinstruction!(bb, OIR.OpSetIndex(arg3, arg_input_value, arg4))
        arg_inspect = OIR.addinstruction!(bb, OIR.OpGetIndex(arg3, arg4))
        OIR.assign!(bb, :inspect2, arg_inspect)

        # println(bb)

        @testset "BasicBlockInterpreter" begin
            input_vector = []
            interpreter = OIR.BasicBlockInterpreter(bb, input_vector)
            OIR.run_program!(interpreter)
            @test OIR.readslot(interpreter, :inspect1) ≈ 0.0
            @test OIR.readslot(interpreter, :inspect2) ≈ 10.0
            @test isa(OIR.readslot(interpreter, :inspect2), Float64)
            @test OIR.readslot(interpreter, :vec) == [ 10.0, 0.0, 0.0 ]
        end
    end
end

@testset "Basic Block" begin
    bb = OIR.BasicBlock()
    x = OIR.addinput!(bb, :x)
    arg1 = OIR.addinstruction!(bb, OIR.Const(10.0))
    arg2 = OIR.addinstruction!(bb, OIR.Const(2.0))
    arg3 = OIR.addinstruction!(bb, OIR.op(*, arg1, arg2))
    arg4 = OIR.addinstruction!(bb, OIR.op(+, arg3, x))
    arg5 = OIR.addinstruction!(bb, OIR.Const(1.0))
    arg6 = OIR.addinstruction!(bb, OIR.op(/, arg4, arg5))
    arg7 = OIR.addinstruction!(bb, OIR.op(-, arg6))
    arg8 = OIR.addinstruction!(bb, OIR.op(+, x, arg3))
    arg9 = OIR.addinstruction!(bb, OIR.op(+, arg8, arg7))
    arg10 = OIR.addinstruction!(bb, OIR.op(+, arg9, arg5))
    arg11 = OIR.addinstruction!(bb, OIR.op(*, arg10, arg5))
    arg12 = OIR.addinstruction!(bb, OIR.op(/, arg11, arg2))
    arg13 = OIR.addinstruction!(bb, OIR.Const(0.0))
    arg14 = OIR.addinstruction!(bb, OIR.op(*, arg13, x))
    arg15 = OIR.addinstruction!(bb, OIR.op(+, arg14, arg12))
    arg16 = OIR.addinstruction!(bb, OIR.Const(1.0))
    arg17 = OIR.addinstruction!(bb, OIR.op(+, arg16, arg15))
    arg18 = OIR.addinstruction!(bb, OIR.op(*, arg16, arg17))
    OIR.assign!(bb, :output, arg18)

    # println(bb)

    @testset "BasicBlockInterpreter" begin
        input_vector = [10.0]
        interpreter = OIR.BasicBlockInterpreter(bb, input_vector)
        OIR.run_program!(interpreter)

        @test OIR.readslot(interpreter, :output) ≈ compiledfunction(input_vector)

        # benchmarks
        println()
        println("Benchmarks for BasicBlockInterpreter")
        @btime OIR.run_program!($interpreter)
        @btime compiledfunction($input_vector)

        let
            el_interpreter = @belapsed OIR.run_program!($interpreter)
            el_compiled = @belapsed compiledfunction($input_vector)
            println("Overhead = $(round(el_interpreter / el_compiled, digits=1))x")
        end
        println()

        @test OIR.readslot(interpreter, :output) ≈ compiledfunction(input_vector)
    end

    @testset "Multiply by zero" begin
        last_instruction_ssavalue = OIR.lastinstructionaddress(bb)
        arg_zero = OIR.addinstruction!(bb, OIR.Const(0.0))
        arg_result = OIR.addinstruction!(bb, OIR.op(*, last_instruction_ssavalue, arg_zero))
        OIR.assign!(bb, :output, arg_result)

        input_vector = [10.0]
        interpreter = OIR.BasicBlockInterpreter(bb, input_vector)
        OIR.run_program!(interpreter)
        @test OIR.readslot(interpreter, :output) == 0.0
    end
end
