module INNERMOD

    import ..OptimizingIR

    struct ResultFun{F}
        f::F
    end

    const OP_SUM = OptimizingIR.Op(+, pure=true, commutative=true, hasleftidentity=true, hasrightidentity=true, identity_element=0)

    function build_fun() :: ResultFun

        bb = OptimizingIR.BasicBlock()
        var_x = OptimizingIR.ImmutableVariable(:x)
        OptimizingIR.addinput!(bb, var_x)
        cnst1 = OptimizingIR.constant(1.0)
        ssa1 = OptimizingIR.addinstruction!(bb, OptimizingIR.call(OP_SUM, var_x, cnst1))
        var_output = OptimizingIR.ImmutableVariable(:output)
        OptimizingIR.addoutput!(bb, var_output)
        OptimizingIR.assign!(bb, var_output, ssa1)

        f = OptimizingIR.compile(OptimizingIR.BasicBlockInterpreter, bb)

        return ResultFun( x -> f(x) )
    end
end
