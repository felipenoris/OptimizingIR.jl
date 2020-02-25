
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

eachvariable(bb::BasicBlock) = keys(bb.variables)
#hasbranches(bb::BasicBlock) = bb.branch != nothing || bb.next != nothing
is_input(bb::BasicBlock, var::ImmutableVariable) = var ∈ bb.inputs
is_input(bb::BasicBlock, var::MutableVariable) = false
is_output(bb::BasicBlock, var::Variable) = var ∈ bb.outputs

"""
    Op(f::Function;
            pure::Bool=false,
            commutative::Bool=false,
            hasleftidentity::Bool=false,
            hasrightidentity::Bool=false,
            identity_element::T=NULL_IDENTITY_ELEMENT)

Defines a basic instruction with optimization annotations.

# Arguments

* `f` is a Julia function to be executed by the `Op`.

* `pure`: marks the function as pure (`true`) or impure (`false`) .

* `commutative`: marks the `Op` as commutative.

* `hasleftidentity`: marks the `Op` as having an identity when operating from the left, which means that `f(I, v) = v`, where `I` is the `identity_element`.

* `hasrightidentity`: marks the `Op` as having an identity when operating from the right, which means that `f(v, I) = v`, where `I` is the `identity_element`.

# Purity

A function is considered [pure](https://en.wikipedia.org/wiki/Pure_function)
if its return value is the same for the same arguments, and has no side-effects.

Operations marked as **pure** are suitable for [Value-Numbering](https://en.wikipedia.org/wiki/Value_numbering)
optimization.

When marked as impure, all optimization passes are disabled.

# Examples

```julia
const op_sum = OIR.Op(+, pure=true, commutative=true, hasleftidentity=true, hasrightidentity=true, identity_element=0)
const op_sub = OIR.Op(-, pure=true, hasrightidentity=true, identity_element=0)
const op_mul = OIR.Op(*, pure=true, commutative=true, hasleftidentity=true, hasrightidentity=true, identity_element=1)
const op_div = OIR.Op(/, pure=true, hasrightidentity=true, identity_element=1)
const op_pow = OIR.Op(^, pure=true, hasrightidentity=true, identity_element=1)

foreign_fun(a, b, c) = a^3 + b^2 + c
const op_foreign_fun = OIR.Op(foreign_fun, pure=true)

const op_zeros = OIR.Op(zeros)
```
"""
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

struct InstructionIterator{T}
    instructions::T
end
Base.iterate(itr::InstructionIterator) = iterate(itr.instructions)
Base.iterate(itr::InstructionIterator, state) = iterate(itr.instructions, state)
eachinstruction(bb::BasicBlock) = InstructionIterator(bb.instructions)

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
    addinput!(b::BasicBlock, iv::ImmutableVariable)

Registers `iv` as an input variable of the function.
"""
addinput!(b::BasicBlock, iv::ImmutableVariable) = addentry!(b.inputs, iv)

"""
    addoutput!(b::BasicBlock, iv::Variable)

Registers `iv` as an output variable of the function.
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

Creates an instruction that results in the value of `array` at `index`.
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

Creates an instruction that sets `value` in `array` at `index`.
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
