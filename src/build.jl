
function BasicBlock()
    BasicBlock(
        LookupTable{LinearInstruction}(),          # instructions
        LookupTable{ImmutableVariable}(),          # inputs
        LookupTable{MutableVariable}(),            # mutable_locals
        Dict{ImmutableVariable, ImmutableValue}(), # immutable_locals
        LookupTable{Variable}()                    # outputs
    )
end

input_variables(bb::BasicBlock) = bb.inputs
output_variables(bb::BasicBlock) = bb.outputs

"""
    constant(val) :: Const

Creates a constant value.
"""
constant(val) = Const(val)

#hasbranches(bb::BasicBlock) = bb.branch != nothing || bb.next != nothing
is_input(bb::BasicBlock, var::ImmutableVariable) = var ∈ bb.inputs
is_input(bb::BasicBlock, var::MutableVariable) = false
is_output(bb::BasicBlock, var::Variable) = var ∈ bb.outputs

struct InstructionIterator{T}
    instructions::T
end
Base.iterate(itr::InstructionIterator) = iterate(itr.instructions)
Base.iterate(itr::InstructionIterator, state) = iterate(itr.instructions, state)
eachinstruction(bb::BasicBlock) = InstructionIterator(bb.instructions)

"""
    has_symbol(bb::BasicBlock, sym::Symbol) :: Bool

Returns `true` if there is any variable (input, local or output)
defined that is identified by the symbol `sym`.
"""
function has_symbol(bb::BasicBlock, sym::Symbol) :: Bool
    for itr in (bb.inputs, bb.mutable_locals, keys(bb.immutable_locals), bb.outputs)
        if any(v -> v.symbol == sym, itr)
            return true
        end
    end

    return false
end

"""
    generate_unique_variable_symbol(bb::BasicBlock) :: Symbol

OptimizingIR's version of `Base.gensym`.

Returns a new symbol for which [`OptimizingIR.has_symbol`](@ref)
is `false`.
"""
function generate_unique_variable_symbol(bb::BasicBlock) :: Symbol
    local new_sym::Symbol = gensym()

    while has_symbol(bb, new_sym)
        new_sym = gensym()
    end

    return new_sym
end

"""
    addinstruction!(b::BasicBlock, instruction::LinearInstruction) :: ImmutableValue

Pushes an instruction to a basic block.
Returns the value that represents the result
after the execution of the instruction.
"""
function addinstruction!(b::BasicBlock, instruction::LinearInstruction) :: ImmutableValue

    result = try_on_add_instruction_passes(b, instruction)
    if result != nothing
        return result
    end

    return SSAValue(addentry!(b.instructions, instruction))
end

inputindex(bb::BasicBlock, op::Variable) = indexof(bb.inputs, op)

"""
    addinput!(b::BasicBlock, iv::ImmutableVariable) :: Int

Registers `iv` as an input variable of the function.
Returns the index of this variable in the tuple of inputs (function arguments).
"""
addinput!(b::BasicBlock, iv::ImmutableVariable) = addentry!(b.inputs, iv)

"""
    addoutput!(b::BasicBlock, iv::Variable) :: Int

Registers `iv` as an output variable of the function.
Returns the index of this variable in the tuple of returned values.
"""
addoutput!(b::BasicBlock, iv::Variable) = addentry!(b.outputs, iv)

"""
    call(op, args...) :: LinearInstruction

Creates an instruction as a call to operation `op`
with arguments `args`.

Internally, it returns either a [`OptimizingIR.PureInstruction`](@ref)
or an [`OptimizingIR.ImpureInstruction`](@ref).
"""
@generated function call(op::Op, arg::A) :: LinearInstruction where {A<:AbstractValue}
    # a call is pure if the Op itself is pure and the argument is immutable
    pure = is_pure(op) && is_immutable(A)
    wrapper_type = pure ? :PureInstruction : :ImpureInstruction
    return quote
        $wrapper_type(CallUnary(op, arg))
    end
end

@generated function call(op::Op, arg1::A, arg2::B) :: LinearInstruction where {A<:AbstractValue, B<:AbstractValue}
    pure = is_pure(op) && is_immutable(arg1) && is_immutable(arg2)
    wrapper_type = pure ? :PureInstruction : :ImpureInstruction
    return quote
        $wrapper_type(CallBinary(op, arg1, arg2))
    end
end

@generated function call(op::Op, args...) :: LinearInstruction
    for a in args
        @assert a <: AbstractValue
    end

    pure = is_pure(op) && all(is_immutable.(args))
    wrapper_type = pure ? :PureInstruction : :ImpureInstruction
    return quote
        $wrapper_type(CallVararg(op, args))
    end
end

"""
    callgetindex(array, index...) :: LinearInstruction

Creates an instruction that calls `Base.getindex(array, index...)`
when executed.
"""
@generated function callgetindex(array::Variable, index...) :: LinearInstruction
    for a in index
        @assert a <: AbstractValue
    end

    pure = is_immutable(array) && all(is_immutable.(index))
    wrapper_type = pure ? :PureInstruction : :ImpureInstruction
    return quote
        $wrapper_type(GetIndex(array, index))
    end
end

"""
    callsetindex(array, value, index...) :: LinearInstruction

Creates an instruction that calls `Base.setindex!(array, value, index...)`
when executed.
"""
function callsetindex(array::MutableVariable, value::AbstractValue, index...) :: LinearInstruction
    ImpureInstruction(SetIndex(array, value, index))
end

"""
    assign!(bb::BasicBlock, lhs::Variable, rhs::AbstractValue)

Assigns the value `rhs` to variable `lhs`.
"""
function assign!(bb::BasicBlock, lhs::ImmutableVariable, rhs::ImmutableValue)
    @assert !haskey(bb.immutable_locals, lhs) "Cannot assign to immmutable variable `$lhs` twice."
    bb.immutable_locals[lhs] = rhs
    addentry!(bb.instructions, ImpureInstruction(Assignment(lhs, rhs)))
    nothing
end

function assign!(bb::BasicBlock, lhs::MutableVariable, rhs::ImmutableValue)
    addentry!(bb.mutable_locals, lhs)
    addentry!(bb.instructions, ImpureInstruction(Assignment(lhs, rhs)))
    nothing
end
