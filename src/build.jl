
function addressof(bb::BasicBlock, slot::Symbol) :: SSAValue
    return bb.slots[slot]
end

instructionof(bb::BasicBlock, arg::SSAValue) = bb.instructions[arg.index]
lastinstructionaddress(bb::BasicBlock) = SSAValue(lastindex(bb.instructions))

function commute(instruction::OpBinary{F, true}) where {F}
    return op(instruction.op, instruction.arg2, instruction.arg1)
end

@generated function addinstruction!(b::BasicBlock, instruction::LinearInstruction) :: SSAValue

    exp_try_commute = quote
        commuted_instruction = commute(instruction)
        if commuted_instruction ∈ b.instructions
            return SSAValue(indexof(b.instructions, commuted_instruction))
        end
    end

    exp_default = quote

        let
            result = try_constant_propagation(b, instruction)
            if result.success
                return addinstruction!(b, result.val)
            end
        end

        let
            result = try_noop(b, instruction)
            if result.success
                return result.val
            end
        end

        return SSAValue(addentry!(b.instructions, instruction))
    end

    if iscommutative(instruction)
        return quote
            $exp_try_commute
            $exp_default
        end
    else
        return quote
            $exp_default
        end
    end
end

function assign!(b::BasicBlock, slot::Symbol, value::SSAValue)
    b.slots[slot] = value
    nothing
end

function addinput!(b::BasicBlock, sym::Symbol) :: SSAValue
    addentry!(b.inputs, sym)
    return addinstruction!(b, InputRef(sym))
end

function iscommutative(::Type{OpBinary{A, commutative}}) where {A, commutative}
    commutative
end

iscommutative(op::OpBinary) = iscommutative(typeof(op))
iscommutative(other) = false

@generated function op(f::Function, arg1::SSAValue, arg2::SSAValue)
    if f == typeof(+) || f == typeof(*)
        return quote
            OpBinary(f, arg1, arg2, true)
        end
    else
        return quote
            OpBinary(f, arg1, arg2, false)
        end
    end
end

op(f::Function, arg::SSAValue) = OpUnary(f, arg)
op(f::Function, args::SSAValue...) = OpVararg(f, args)
