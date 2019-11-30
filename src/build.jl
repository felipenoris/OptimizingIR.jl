
constant(val) = Const(val)

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
eachslot(bb::BasicBlock) = keys(bb.slots)

hasbranches(bb::BasicBlock) = bb.branch != nothing || bb.next != nothing

function addinstruction!(b::BasicBlock, instruction::LinearInstruction) :: StaticAddress

    result = try_on_add_instruction_passes(b, instruction)
    if result != nothing
        return result
    end

    return SSAValue(addentry!(b.instructions, instruction))
end

function assign!(b::BasicBlock, slot::Slot, value::StaticAddress)
    b.slots[slot] = value
    nothing
end

function addinput!(b::BasicBlock, sym::Symbol) :: StaticAddress
    addentry!(b.inputs, sym)
    return InputRef(sym)
end

"""
    follow(program::BasicBlock, arg::Slot) :: StaticAddress

Similar to deref, but returns the static address
for which the slot is pointing to.
"""
function follow(program::BasicBlock, arg::Slot) :: StaticAddress
    @assert haskey(program.slots, arg) "Slot $arg was not defined."
    return program.slots[arg]
end

call(op::Op, arg::StaticAddress) = wrap_if_impure(CallUnary(op, arg))
call(op::Op, arg1::StaticAddress, arg2::StaticAddress) = wrap_if_impure(CallBinary(op, arg1, arg2))
call(op::Op, args::StaticAddress...) = wrap_if_impure(CallVararg(op, args))

function wrap_if_impure(instruction::PureCall{OP}) where {OP}
    if ispure(OP)
        return instruction
    else
        return ImpureCall(instruction)
    end
end

call(f::Function, arg::StaticAddress) = call(Op(f), arg)
call(f::Function, arg1::StaticAddress, arg2::StaticAddress) = call(Op(f), arg1, arg2)
call(f::Function, args::StaticAddress...) = call(Op(f), args...)
