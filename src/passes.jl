

ispure(rule::OptimizationRule) = rule.pure
iscommutative(rule::OptimizationRule) = rule.commutative
hasleftidentity(rule::OptimizationRule) = rule.hasleftidentity
hasrightidentity(rule::OptimizationRule) = rule.hasrightidentity
hasidentity(rule::OptimizationRule) = hasrightidentity(rule) || hasleftidentity(rule)

function get_identity_element(rule::OptimizationRule)
    @assert hasidentity(rule)
    return rule.identity_element
end

#
# define OpimizationRule methods for Op and AbstractCall
#

for fun in (:ispure, :iscommutative, :hasidentity, :hasleftidentity, :hasrightidentity, :get_identity_element)
    @eval begin
        function ($fun)(::Type{Op{F, OPTRULE}}) where {F, OPTRULE}
            ($fun)(OPTRULE)
        end

        function ($fun)(::Op{F, OPTRULE}) where {F, OPTRULE}
            ($fun)(OPTRULE)
        end

        function ($fun)(::Type{AbstractCall{OP}}) where {OP}
            ($fun)(OP)
        end

        function ($fun)(::AbstractCall{OP}) where {OP}
            ($fun)(OP)
        end
    end
end

#
# Commutative ops
#

function commute(instruction::CallBinary{OP}) where {OP}
    @assert iscommutative(OP) "$OP is not commutative."
    return call(instruction.op, instruction.arg2, instruction.arg1)
end

#
# Constant Propagation
#

struct OptimizationPassResult{A<:Address}
    success::Bool
    val::A
end

const FAILED_OPTIMIZATION_PASS = OptimizationPassResult(false, NullPointer())

try_constant_propagation(b::BasicBlock, instruction) = FAILED_OPTIMIZATION_PASS

function try_constant_propagation(b::BasicBlock, instruction::CallUnary)
    arg = instruction.arg
    if isa(arg, Const)
        return OptimizationPassResult(true, Const(instruction.op(arg.val)))
    end
    return FAILED_OPTIMIZATION_PASS
end

function try_constant_propagation(b::BasicBlock, instruction::CallBinary)
    arg1 = instruction.arg1
    arg2 = instruction.arg2
    if isa(arg1, Const) && isa(arg2, Const)
        return OptimizationPassResult(true, Const(instruction.op(arg1.val, arg2.val)))
    end
    return FAILED_OPTIMIZATION_PASS
end

function try_constant_propagation(b::BasicBlock, instruction::CallVararg)
    if all(map(arg -> isa(arg, Const), instruction.args))
        return OptimizationPassResult(true, Const(instruction.op( map(arg -> arg.val, instruction.args)... )))
    end
    return FAILED_OPTIMIZATION_PASS
end

#
# Identity Element Pass
#

try_identity_element_pass(b::BasicBlock, instruction) = FAILED_OPTIMIZATION_PASS

is_const_with_value(instruction, val) = false
is_const_with_value(c::Const, val) = c.val == val

function try_identity_element_pass(b::BasicBlock, instruction::CallBinary{OP}) where {OP}

    if hasidentity(OP)

        identity_element = get_identity_element(OP)

        if hasrightidentity(OP)
            if is_const_with_value(instruction.arg2, identity_element)
                return OptimizationPassResult(true, instruction.arg1)
            end
        end

        if hasleftidentity(OP)
            if is_const_with_value(instruction.arg1, identity_element)
                return OptimizationPassResult(true, instruction.arg2)
            end
        end
    end

    return FAILED_OPTIMIZATION_PASS
end

try_commutative_op(::Program, instruction) = FAILED_OPTIMIZATION_PASS

function try_commutative_op(bb::BasicBlock, instruction::CallBinary{OP}) where {OP}
    if iscommutative(OP)
        commuted_instruction = commute(instruction)
        if commuted_instruction ∈ bb.instructions
            return OptimizationPassResult(true, SSAValue(indexof(bb.instructions, commuted_instruction)))
        end
    end

    return FAILED_OPTIMIZATION_PASS
end

#
# On-add-instruction passes
#

"""
    try_on_add_instruction_passes(program, instruction) :: Union{Nothing, Address}

Tries to apply all optimization passes available
while running `addinstruction!`:

```julia
function addinstruction!(b::BasicBlock, instruction::LinearInstruction) :: Address

    result = try_on_add_instruction_passes(b, instruction)
    if result != nothing
        return result
    end

    ...
end
```
"""
function try_on_add_instruction_passes(::Program, instruction::LinearInstruction)
    # optimization pass only makes sense in the context of a PureCall
    return nothing
end

function try_on_add_instruction_passes(bb::BasicBlock, instruction::PureCall{OP}) :: Union{Nothing, Address} where {OP}
    @assert ispure(OP) "Beloved?"

    # all pure ops go thru constant propagation
    result = try_constant_propagation(bb, instruction)
    if result.success
        return result.val
    end

    # next we check for identity element
    result = try_identity_element_pass(bb, instruction)
    if result.success
        return result.val
    end

    # last optim is for commutative op
    result = try_commutative_op(bb, instruction)
    if result.success
        return result.val
    end

    return nothing
end
