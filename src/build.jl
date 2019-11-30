
constant(val) = Const(val)

function addressof(bb::BasicBlock, slot::Symbol) :: Address
    return bb.slots[slot]
end

instructionof(bb::BasicBlock, arg::SSAValue) = bb.instructions[arg.index]
instructionof(bb::BasicBlock, arg::InputRef) = nothing
instructionof(bb::BasicBlock, arg::Const) = nothing
lastinstructionaddress(bb::BasicBlock) = SSAValue(lastindex(bb.instructions))

struct InstructionIterator{T}
    instructions::T
end
Base.iterate(itr::InstructionIterator) = iterate(itr.instructions)
Base.iterate(itr::InstructionIterator, state) = iterate(itr.instructions, state)
eachinstruction(bb::BasicBlock) = InstructionIterator(bb.instructions)

hasbranches(bb::BasicBlock) = bb.branch != nothing || bb.next != nothing

function addinstruction!(b::BasicBlock, instruction::LinearInstruction) :: Address

    result = try_on_add_instruction_passes(b, instruction)
    if result != nothing
        return result
    end

    return SSAValue(addentry!(b.instructions, instruction))

#=
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
                return result.val
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
=#
end

function assign!(b::BasicBlock, slot::Symbol, value::Address)
    b.slots[slot] = value
    nothing
end

function addinput!(b::BasicBlock, sym::Symbol) :: Address
    addentry!(b.inputs, sym)
    return InputRef(sym)
end

call(op::Op, arg::Address) = wrap_if_impure(CallUnary(op, arg))
call(op::Op, arg1::Address, arg2::Address) = wrap_if_impure(CallBinary(op, arg1, arg2))
call(op::Op, args::Address...) = wrap_if_impure(CallVararg(op, args))

function wrap_if_impure(instruction::PureCall{OP}) where {OP}
    if ispure(OP)
        return instruction
    else
        return ImpureCall(instruction)
    end
end

call(f::Function, arg::Address) = call(Op(f), arg)
call(f::Function, arg1::Address, arg2::Address) = call(Op(f), arg1, arg2)
call(f::Function, args::Address...) = call(Op(f), args...)
