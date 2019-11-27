
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
    arg_instruction = instructionof(b, instruction.arg)
    if isa(arg_instruction, Const)
        return ConstantPropagationResult(true, Const(instruction.op(arg_instruction.val)))
    end
    return FAILED_CONSTANT_PROPAGATION
end

function try_constant_propagation(b::BasicBlock, instruction::CallBinary{F}) where {F<:Function}
    argi1 = instructionof(b, instruction.arg1)
    argi2 = instructionof(b, instruction.arg2)
    if isa(argi1, Const) && isa(argi2, Const)
        return ConstantPropagationResult(true, Const(instruction.op(argi1.val, argi2.val)))
    end
    return FAILED_CONSTANT_PROPAGATION
end

function try_constant_propagation(b::BasicBlock, instruction::CallVararg{F, N}) where {F<:Function, N}
    if all(map(arg -> isa(instructionof(b, arg), Const), instruction.args))
        return ConstantPropagationResult(true, Const(instruction.op( map(arg -> instructionof(b, arg).val, instruction.args)... )))
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
            argi = instructionof(b, instruction.arg2)
            if is_const_with_value(argi, 1)
                return NoopResult(true, instruction.arg1)
            end

            return FAILED_NOOP
        end
    end

    if F == typeof(*)
        return quote
            argi1 = instructionof(b, instruction.arg1)
            argi2 = instructionof(b, instruction.arg2)

            # arg * 1 == 1 * arg == arg
            if is_const_with_value(argi1, 1)
                return NoopResult(true, instruction.arg2)
            elseif is_const_with_value(argi2, 1)
                return NoopResult(true, instruction.arg1)
            end

            # arg * 0 == 0 * arg == 0
            if is_const_with_value(argi1, 0)
                return NoopResult(true, instruction.arg1)
            elseif is_const_with_value(argi2, 0)
                return NoopResult(true, instruction.arg2)
            end

            return FAILED_NOOP
        end
    end

    if F == typeof(+)
        return quote
            argi1 = instructionof(b, instruction.arg1)
            argi2 = instructionof(b, instruction.arg2)

            # arg + 0 == 0 + arg == arg
            if is_const_with_value(argi1, 0)
                return NoopResult(true, instruction.arg2)
            elseif is_const_with_value(argi2, 0)
                return NoopResult(true, instruction.arg1)
            end

            return FAILED_NOOP
        end
    end

    return FAILED_NOOP
end
