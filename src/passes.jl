
is_pure(rule::OptimizationRule) = rule.pure
is_impure(rule::OptimizationRule) = !is_pure(rule)
is_commutative(rule::OptimizationRule) = rule.commutative
has_left_identity_property(rule::OptimizationRule) = rule.hasleftidentity
has_right_identity_property(rule::OptimizationRule) = rule.hasrightidentity
has_identity_property(rule::OptimizationRule) = has_right_identity_property(rule) || has_left_identity_property(rule)

struct NullIdentityElement
end

const NULL_IDENTITY_ELEMENT = NullIdentityElement()

has_identity_element(rule::OptimizationRule) = rule.identity_element != NULL_IDENTITY_ELEMENT

function get_identity_element(rule::OptimizationRule)
    @assert has_identity_property(rule) && has_identity_element(rule)
    return rule.identity_element
end

#
# define OpimizationRule methods for Op and AbstractOpCall
#

for fun in (:is_pure, :is_impure, :is_commutative, :has_identity_property, :has_left_identity_property, :has_right_identity_property, :get_identity_element, :has_identity_element)
    @eval begin
        function ($fun)(::Type{Op{F, OPTRULE}}) where {F, OPTRULE}
            @assert typeof(OPTRULE) <: OptimizationRule
            ($fun)(OPTRULE)
        end

        function ($fun)(::Op{F, OPTRULE}) where {F, OPTRULE}
            @assert typeof(OPTRULE) <: OptimizationRule
            ($fun)(OPTRULE)
        end
    end
end

for fun in (:is_commutative, :has_identity_property, :has_left_identity_property, :has_right_identity_property, :get_identity_element, :has_identity_element)
    @eval begin
        function ($fun)(::Type{T}) where {OP, T<:AbstractOpCall{OP}}
            ($fun)(OP)
        end

        function ($fun)(::T) where {OP, T<:AbstractOpCall{OP}}
            ($fun)(OP)
        end
    end
end

# is_pure / is_impure for x, where x::T<:AbstractOpCall
@generated function is_pure(call::CallUnary{OP, A}) where {OP,A}
    is_pure(OP) && is_immutable(A)
end

@generated function is_pure(call::CallBinary{OP, A, B}) where {OP,A,B}
    is_pure(OP) && is_immutable(A) && is_immutable(B)
end

@generated function is_pure(call::Call3Args{OP, A, B, C}) where {OP,A,B,C}
    is_pure(OP) && is_immutable(A) && is_immutable(B) && is_immutable(C)
end

is_impure(call::AbstractOpCall) = !is_pure(call)

is_pure(::PureInstruction) = true
is_pure(::ImpureInstruction) = false
is_impure(i::LinearInstruction) = !is_pure(i)

#
# Commutative ops
#

@generated function commute(instruction::CallBinary{OP}) where {OP}
    @assert is_commutative(OP) "$OP is not commutative."

    return quote
        call(instruction.op, instruction.arg2, instruction.arg1)
    end
end

#
# Constant Propagation
#

struct OptimizationPassResult{A<:ImmutableValue}
    success::Bool
    val::A
end

const FAILED_OPTIMIZATION_PASS = OptimizationPassResult(false, NullPointer())

try_constant_propagation(b::BasicBlock, instruction) = FAILED_OPTIMIZATION_PASS

function try_constant_propagation(b::BasicBlock, instruction::CallUnary{OP, C}) where {OP, C<:Const}
    arg = instruction.arg
    return OptimizationPassResult(true, Const(instruction.op(arg.val)))
end

function try_constant_propagation(b::BasicBlock, instruction::CallBinary{OP, C1, C2}) where {OP, C1<:Const, C2<:Const}
    arg1 = instruction.arg1
    arg2 = instruction.arg2
    return OptimizationPassResult(true, Const(instruction.op(arg1.val, arg2.val)))
end

function try_constant_propagation(b::BasicBlock, instruction::Call3Args{OP, C1, C2, C3}) where {OP, C1<:Const, C2<:Const, C3<:Const}
    arg1 = instruction.arg1
    arg2 = instruction.arg2
    arg3 = instruction.arg3
    return OptimizationPassResult(true, Const(instruction.op(arg1.val, arg2.val, arg3.val)))
end

#
# Identity Element Pass
#

try_identity_element_pass(b::BasicBlock, instruction) = FAILED_OPTIMIZATION_PASS

is_const_with_value(instruction, val) = false
is_const_with_value(c::Const, val) = c.val == val

@generated function try_identity_element_pass(b::BasicBlock, instruction::CallBinary{OP}) where {OP}

    if has_identity_property(OP)

        return quote
            identity_element = get_identity_element(OP)

            if has_right_identity_property(OP)
                if is_const_with_value(instruction.arg2, identity_element)
                    return OptimizationPassResult(true, instruction.arg1)
                end
            end

            if has_left_identity_property(OP)
                if is_const_with_value(instruction.arg1, identity_element)
                    return OptimizationPassResult(true, instruction.arg2)
                end
            end

            return FAILED_OPTIMIZATION_PASS
        end
    else
        return FAILED_OPTIMIZATION_PASS
    end
end

try_commutative_op(::Program, instruction) = FAILED_OPTIMIZATION_PASS

@generated function try_commutative_op(bb::BasicBlock, instruction::CallBinary{OP}) where {OP}
    if is_commutative(OP)

        return quote
            commuted_instruction = commute(instruction)

            if commuted_instruction ∈ bb.instructions
                return OptimizationPassResult(true, SSAValue(indexof(bb.instructions, commuted_instruction)))
            end

            return FAILED_OPTIMIZATION_PASS
        end
    else
        return FAILED_OPTIMIZATION_PASS
    end
end

#
# On-add-instruction passes
#

"""
    try_on_add_instruction_passes(program, instruction) :: Union{Nothing, ImmutableValue}

Tries to apply all optimization passes available
while running `addinstruction!`:

```julia
function addinstruction!(b::BasicBlock, instruction::LinearInstruction) :: ImmutableValue

    result = try_on_add_instruction_passes(b, instruction)
    if result !== nothing
        return result
    end

    # (...)
end
```
"""
function try_on_add_instruction_passes(::Program, instruction::ImpureInstruction)
    # optimization pass only makes sense in the context of a PureCall
    return nothing
end

function try_on_add_instruction_passes(bb::BasicBlock, instruction::PureInstruction) :: Union{Nothing, ImmutableValue}

    # all pure ops go thru constant propagation
    # next we check for identity element
    # last optim is for commutative op
    for fn in (try_constant_propagation, try_identity_element_pass, try_commutative_op)
        result = fn(bb, instruction.call)
        if result.success
            return result.val
        end
    end

    return nothing
end
