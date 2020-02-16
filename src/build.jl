
function BasicBlock()
    BasicBlock(
        LookupTable{LinearInstruction}(),
        LookupTable{Variable}(),
        Dict{Variable, ImmutableValue}()
    )
end

constant(val) = Const(val)
eachvariable(bb::BasicBlock) = keys(bb.variables)
#hasbranches(bb::BasicBlock) = bb.branch != nothing || bb.next != nothing
is_input(bb::BasicBlock, var::Variable) = var ∈ bb.inputs

function Op(f::F;
            pure::Bool=false,
            commutative::Bool=false,
            hasleftidentity::Bool=false,
            hasrightidentity::Bool=false,
            identity_element::T=NULL_IDENTITY_ELEMENT) where {F<:Function, T}

    return Op(f, OptimizationRule(pure, commutative, hasleftidentity, hasrightidentity, identity_element))
end

# defines functor for Op so that op(arg1, ...) will call op.op(arg1, ...)
# see https://docs.julialang.org/en/v1/manual/methods/#Function-like-objects-1
(op::Op)(args...) = op.op(args...)

"""
    follow(program::Program, arg::Address) :: StaticAddress

Similar to deref, but returns the static address
for which the argument is pointing to.
"""
function follow(program::BasicBlock, arg::Variable) :: ImmutableValue
    @assert haskey(program.variables, arg) "Variable $arg was not defined."
    return program.variables[arg]
end

follow(bb::BasicBlock, arg::SSAValue) = bb.instructions[arg.address]

struct InstructionIterator{T}
    instructions::T
end
Base.iterate(itr::InstructionIterator) = iterate(itr.instructions)
Base.iterate(itr::InstructionIterator, state) = iterate(itr.instructions, state)
eachinstruction(bb::BasicBlock) = InstructionIterator(bb.instructions)

function addinstruction!(b::BasicBlock, instruction::LinearInstruction) :: ImmutableValue

    result = try_on_add_instruction_passes(b, instruction)
    if result != nothing
        return result
    end

    return SSAValue(addentry!(b.instructions, instruction))
end

function assign!(b::BasicBlock, variable::Variable, value::ImmutableValue)
    b.variables[variable] = value
    nothing
end

inputindex(bb::BasicBlock, op::Variable) = indexof(bb.inputs, op)

function addinput!(b::BasicBlock, iv::Variable)
    addentry!(b.inputs, iv)
    nothing
end

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

function callsetindex(array::Variable{Mutable}, value::AbstractValue, index...) :: LinearInstruction
    return ImpureInstruction(SetIndex(array, value, index))
end
