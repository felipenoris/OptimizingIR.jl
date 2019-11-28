
#
# Constant Propagation
#

struct ConstantPropagationResult
    success::Bool
    val::Const
end

const FAILED_CONSTANT_PROPAGATION = ConstantPropagationResult(false, Const(0))
try_constant_propagation(b::BasicBlock, instruction) = FAILED_CONSTANT_PROPAGATION

function try_constant_propagation(b::BasicBlock, instruction::CallUnary{F}) where {F<:Function}
    arg = instruction.arg
    if isa(arg, Const)
        return ConstantPropagationResult(true, Const(instruction.op(arg.val)))
    end
    return FAILED_CONSTANT_PROPAGATION
end

function try_constant_propagation(b::BasicBlock, instruction::CallBinary{F}) where {F<:Function}
    arg1 = instruction.arg1
    arg2 = instruction.arg2
    if isa(arg1, Const) && isa(arg2, Const)
        return ConstantPropagationResult(true, Const(instruction.op(arg1.val, arg2.val)))
    end
    return FAILED_CONSTANT_PROPAGATION
end

function try_constant_propagation(b::BasicBlock, instruction::CallVararg{F, N}) where {F<:Function, N}
    if all(map(arg -> isa(arg, Const), instruction.args))
        return ConstantPropagationResult(true, Const(instruction.op( map(arg -> arg.val, instruction.args)... )))
    end
    return FAILED_CONSTANT_PROPAGATION
end

#
# No-Op
#

struct NoopResult{A<:Address}
    success::Bool
    val::A
end

const FAILED_NOOP = NoopResult(false, NullPointer())
try_noop(b::BasicBlock, instruction) = FAILED_NOOP

is_const_with_value(instruction, val) = false
is_const_with_value(c::Const, val) = c.val == val

@generated function try_noop(b::BasicBlock, instruction::CallBinary{F}) where {F<:Function}

    # arg / 1 == arg
    if F == typeof(/)
        return quote
            if is_const_with_value(instruction.arg2, 1)
                return NoopResult(true, instruction.arg1)
            end

            return FAILED_NOOP
        end
    end

    if F == typeof(*)
        return quote
            # arg * 1 == 1 * arg == arg
            if is_const_with_value(instruction.arg1, 1)
                return NoopResult(true, instruction.arg2)
            elseif is_const_with_value(instruction.arg2, 1)
                return NoopResult(true, instruction.arg1)
            end

            # arg * 0 == 0 * arg == 0
            if is_const_with_value(instruction.arg1, 0)
                return NoopResult(true, instruction.arg1)
            elseif is_const_with_value(instruction.arg2, 0)
                return NoopResult(true, instruction.arg2)
            end

            return FAILED_NOOP
        end
    end

    if F == typeof(+)
        return quote
            # arg + 0 == 0 + arg == arg
            if is_const_with_value(instruction.arg1, 0)
                return NoopResult(true, instruction.arg2)
            elseif is_const_with_value(instruction.arg2, 0)
                return NoopResult(true, instruction.arg1)
            end

            return FAILED_NOOP
        end
    end

    return FAILED_NOOP
end
