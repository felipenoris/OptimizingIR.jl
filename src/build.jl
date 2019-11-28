
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

@generated function addinstruction!(b::BasicBlock, instruction::LinearInstruction) :: Address

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
end

function assign!(b::BasicBlock, slot::Symbol, value::Address)
    b.slots[slot] = value
    nothing
end

function addinput!(b::BasicBlock, sym::Symbol) :: Address
    addentry!(b.inputs, sym)
    return InputRef(sym)
end

function commute(instruction::CallBinary{F, true}) where {F}
    return callpure(instruction.op, instruction.arg2, instruction.arg1)
end

function iscommutative(::Type{CallBinary{F, commutative, A, B}}) where {F, commutative, A, B}
    commutative
end

iscommutative(op::CallBinary) = iscommutative(typeof(op))
iscommutative(other) = false

@generated function callpure(f::Function, arg1::Address, arg2::Address)
    if f == typeof(+) || f == typeof(*)
        return quote
            CallBinary(f, arg1, arg2, true)
        end
    else
        return quote
            CallBinary(f, arg1, arg2, false)
        end
    end
end

callpure(f::Function, arg::Address) = CallUnary(f, arg)
callpure(f::Function, args::Address...) = CallVararg(f, args)

callimpure(f::Function, arg::Address) = ImpureCall(callpure(f, arg))
callimpure(f::Function, arg1::Address, arg2::Address) = ImpureCall(callpure(f, arg1, arg2))
callimpure(f::Function, args::Address...) = ImpureCall(callpure(f, args...))
