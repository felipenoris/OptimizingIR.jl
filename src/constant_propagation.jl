
struct ConstantPropagationResult
    success::Bool
    val::Const
end

const FAILED_CONSTANT_PROPAGATION = ConstantPropagationResult(false, Const(0))
try_constant_propagation(b::BasicBlock, instruction) = FAILED_CONSTANT_PROPAGATION

function can_apply_const_propagation_to_function(::Type{F}) :: Bool where {F<:Function}
    F == typeof(+) ||
    F == typeof(-) ||
    F == typeof(*) ||
    F == typeof(/) ||
    F == typeof(^) ||
    F == typeof(sqrt) ||
    F == typeof(min) ||
    F == typeof(max)
end

@generated function try_constant_propagation(b::BasicBlock, instruction::OpUnary{F}) where {F<:Function}

    if can_apply_const_propagation_to_function(F)
        return quote
            arg_instruction = instructionof(b, instruction.arg)
            if isa(arg_instruction, Const)
                return ConstantPropagationResult(true, Const(instruction.op(arg_instruction.val)))
            end
            return FAILED_CONSTANT_PROPAGATION
        end
    end

    return FAILED_CONSTANT_PROPAGATION
end

@generated function try_constant_propagation(b::BasicBlock, instruction::OpBinary{F}) where {F<:Function}

    if can_apply_const_propagation_to_function(F)
        return quote
            argi1 = instructionof(b, instruction.arg1)
            argi2 = instructionof(b, instruction.arg2)
            if isa(argi1, Const) && isa(argi2, Const)
                return ConstantPropagationResult(true, Const(instruction.op(argi1.val, argi2.val)))
            end
            return FAILED_CONSTANT_PROPAGATION
        end
    end

    return FAILED_CONSTANT_PROPAGATION
end
