
struct NoopResult
    success::Bool
    val::SSAValue
end

const FAILED_NOOP = NoopResult(false, SSAValue(0))
try_noop(b::BasicBlock, instruction) = FAILED_NOOP

is_const_with_value(instruction, val) = false
is_const_with_value(c::Const, val) = c.val == val

@generated function try_noop(b::BasicBlock, instruction::OpBinary{F}) where {F<:Function}

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
