
abstract type Mutability end

struct Mutable <: Mutability
end

struct Immutable <: Mutability
end

"""
    AbstractValue{M<:Mutability}

A value can be marked as either Mutable or Immutable.

An immutable value can be assigned only once.
A mutable value can be assigned more than once.
"""
abstract type AbstractValue{M<:Mutability} end

const MutableValue = AbstractValue{Mutable}
const ImmutableValue = AbstractValue{Immutable}

@generated function is_mutable(::Type{T}) :: Bool where {M<:Mutability, T<:AbstractValue{M}}
    M == Mutable
end

@generated function is_immutable(::Type{T}) :: Bool where {M<:Mutability, T<:AbstractValue{M}}
    M == Immutable
end

@generated function is_mutable(v::AbstractValue) :: Bool
    is_mutable(v)
end

@generated function is_immutable(v::AbstractValue) :: Bool
    is_immutable(v)
end

struct NullPointer <: ImmutableValue
end

"""
A pointer to an instruction
that computes a value.
"""
struct SSAValue <: ImmutableValue
    address::Int # instruction location
end

"""
Constant value to be encoded directly into the IR.
The address is the value itself.
"""
struct Const{T} <: ImmutableValue
    val::T
end

"""
    Variable{M<:Mutability}

Creates a variable identified by a symbol
that can be either mutable or immutable.

# Alias

For convenience, the following constants are defined in the package:

```julia
const MutableVariable = Variable{Mutable}
const ImmutableVariable = Variable{Immutable}
```

# Examples

```julia
m = OptimizingIR.MutableVariable(:varmut) # a mutable variable
im = OptimizingIR.ImmutableVariable(:varimut) # an immutable variable
```
"""
struct Variable{M} <: AbstractValue{M}
    symbol::Symbol
end

const MutableVariable = Variable{Mutable}
const ImmutableVariable = Variable{Immutable}

"""
Sets which optimizations are
allowed to an `Op`.
"""
struct OptimizationRule{T, M<:Union{Integer, Tuple, NTuple, Nothing}}
    pure::Bool              # whether the Op itself is pure or impure
    commutative::Bool
    hasleftidentity::Bool   # [left=element] op      right
    hasrightidentity::Bool  #     left       op [right=element]
    identity_element::T
    mutable_arg::M          # which function arguments are mutated (check if mutable)

    function OptimizationRule(pure::Bool, commutative::Bool,
            hasleftidentity::Bool, hasrightidentity::Bool, identity_element::T,
            mutable_arg::M) where {T, M}

        if commutative || hasleftidentity || hasrightidentity
            @assert pure "Can't apply commutative or identity optimization on impure op."
        end

        return new{T,M}(pure, commutative, hasleftidentity, hasrightidentity, identity_element, mutable_arg)
    end
end

# typeof(O) == OptimizationRule
struct Op{F<:Function, O}
    op::F

    function Op(f::F, o::OptimizationRule) where {F<:Function}
        return new{F, o}(f)
    end
end

"""
    Op(f::Function;
            pure::Bool=false,
            commutative::Bool=false,
            hasleftidentity::Bool=false,
            hasrightidentity::Bool=false,
            identity_element::T=NULL_IDENTITY_ELEMENT,
            mutable_arg=nothing)

Defines a basic instruction with optimization annotations.

# Arguments

* `f` is a Julia function to be executed by the `Op`.

* `pure`: marks the function as pure (`true`) or impure (`false`) .

* `commutative`: marks the `Op` as commutative.

* `hasleftidentity`: marks the `Op` as having an identity when operating from the left, which means that `f(I, v) = v`, where `I` is the `identity_element`.

* `hasrightidentity`: marks the `Op` as having an identity when operating from the right, which means that `f(v, I) = v`, where `I` is the `identity_element`.

* `mutable_arg`: either `nothing`, or the index or tuple of indexes of the arguments that need to be mutable.

# Purity

A function is considered [pure](https://en.wikipedia.org/wiki/Pure_function)
if its return value is the same for the same arguments, and has no side-effects.

Operations marked as **pure** are suitable for [Value-Numbering](https://en.wikipedia.org/wiki/Value_numbering)
optimization.

When marked as impure, all optimization passes are disabled.

# Examples

```julia
# this Op allows using `+` as a pure, commutative function. Sets 0 as identity element.
const OP_SUM = OIR.Op(+, pure=true, commutative=true, hasleftidentity=true, hasrightidentity=true, identity_element=0)

# `-` as a pure function. Identity is zero but only `x - 0 = x` case is checked.
const OP_SUB = OIR.Op(-, pure=true, hasrightidentity=true, identity_element=0)

# `*` as pure commutative function. Sets 1 as identity element.
const OP_MUL = OIR.Op(*, pure=true, commutative=true, hasleftidentity=true, hasrightidentity=true, identity_element=1)

# `/` as a pure function. Identity is checked to the right: `a / 1 = a`.
const OP_DIV = OIR.Op(/, pure=true, hasrightidentity=true, identity_element=1)

# power function
const OP_POW = OIR.Op(^, pure=true, hasrightidentity=true, identity_element=1)

# an Op that uses an arbitrary Julia function
foreign_fun(a, b, c) = a^3 + b^2 + c
const OP_FOREIGN_FUN = OIR.Op(foreign_fun, pure=true)

# An Op that is impure: every time we run `zeros` a different Array is returned.
const OP_ZEROS = OIR.Op(zeros)
```
"""
function Op(f::F;
            pure::Bool=false,
            commutative::Bool=false,
            hasleftidentity::Bool=false,
            hasrightidentity::Bool=false,
            identity_element::T=NULL_IDENTITY_ELEMENT,
            mutable_arg=nothing) where {F<:Function, T}

    return Op(f, OptimizationRule(pure, commutative, hasleftidentity, hasrightidentity, identity_element, mutable_arg))
end

# defines functor for Op so that op(arg1, ...) will call op.op(arg1, ...)
# see https://docs.julialang.org/en/v1/manual/methods/#Function-like-objects-1
(op::Op)(args...) = op.op(args...)

abstract type AbstractCall end
abstract type AbstractOpCall{OP<:Op} <: AbstractCall end
abstract type Instruction end
abstract type LinearInstruction{T<:AbstractCall} <: Instruction end
abstract type BranchInstruction <: Instruction end

# lhs = rhs
struct Assignment{V1<:Variable, V2<:ImmutableValue} <: AbstractCall
    lhs::V1
    rhs::V2
end

"""
A `PureInstruction` is a call to an operation
that always returns the same value
if the same arguments are passed to the instruction.
It is suitable for memoization, in the sense that
it can be optimized in the Value-Number algorithm
inside a Basic Block.

An instruction is considered pure if its `call`
has an pure `Op` and all of its arguments
are immutable.
"""
struct PureInstruction{T} <: LinearInstruction{T}
    call::T

    function PureInstruction(call::G) where {G<:AbstractOpCall}
        # An AbstractOpCall has on Op that is either pure or impure
        @assert is_pure(call) "Call is not pure ($call)."
        return new{G}(call)
    end

    function PureInstruction(call::G) where {G<:AbstractCall}
        # catch other AbstractCalls (GetIndex/SetIndex)
        return new{G}(call)
    end
end

"""
An `ImpureInstruction` is a call to an operation
that not always returns the same value
if the same arguments are passed to the instruction.
It is not suitable for memoization,
and the Value-Number optimization must be
disabled for this call.

An instruction is considered impure if its `call`
has an impure `Op`, or if onde of its arguments
is mutable.

Marking as mutable avoids Value-Numbering for this call.
"""
mutable struct ImpureInstruction{T} <: LinearInstruction{T}
    call::T

    function ImpureInstruction(call::G) where {G<:AbstractOpCall}
        # An AbstractOpCall has on Op that is either pure or impure
        @assert is_impure(call) "Call is not impure ($call)."
        return new{G}(call)
    end

    function ImpureInstruction(call::G) where {G<:AbstractCall}
        # catch other AbstractCalls (GetIndex/SetIndex)
        return new{G}(call)
    end

    function ImpureInstruction(call::Assignment)
        return new{Assignment}(call)
    end
end

struct CallUnary{OP, A<:AbstractValue} <: AbstractOpCall{OP}
    op::OP
    arg::A
end

struct CallBinary{OP, A<:AbstractValue, B<:AbstractValue} <: AbstractOpCall{OP}
    op::OP
    arg1::A
    arg2::B
end

struct Call3Args{OP, A<:AbstractValue, B<:AbstractValue, C<:AbstractValue} <: AbstractOpCall{OP}
    op::OP
    arg1::A
    arg2::B
    arg3::C
end

struct Call4Args{OP, A<:AbstractValue, B<:AbstractValue, C<:AbstractValue, D<:AbstractValue} <: AbstractOpCall{OP}
    op::OP
    arg1::A
    arg2::B
    arg3::C
    arg4::D
end

struct Call5Args{OP, A<:AbstractValue, B<:AbstractValue, C<:AbstractValue, D<:AbstractValue, E<:AbstractValue} <: AbstractOpCall{OP}
    op::OP
    arg1::A
    arg2::B
    arg3::C
    arg4::D
    arg5::E
end

struct Call6Args{OP, A<:AbstractValue, B<:AbstractValue, C<:AbstractValue, D<:AbstractValue, E<:AbstractValue, F<:AbstractValue} <: AbstractOpCall{OP}
    op::OP
    arg1::A
    arg2::B
    arg3::C
    arg4::D
    arg5::E
    arg6::F
end

abstract type Program end

mutable struct BasicBlock <: Program
    instructions::LookupTable{LinearInstruction}
    inputs::LookupTable{ImmutableVariable}
    mutable_locals::LookupTable{MutableVariable}
    immutable_locals::Dict{ImmutableVariable, ImmutableValue}
    outputs::LookupTable{Variable}
#    branch::Union{Nothing, BranchInstruction}
#    next::Union{Nothing, BasicBlock}
#    cfg::Union{Nothing, Program}
end

"""
A CompiledBasicBlock mirrors BasicBlock
but the instructions LookupTable is replaced
with Vector to save memory.
"""
struct CompiledBasicBlock <: Program
    instructions::Vector{LinearInstruction}
    inputs::LookupTable{ImmutableVariable}
    mutable_locals::LookupTable{MutableVariable}
    immutable_locals::Dict{ImmutableVariable, ImmutableValue}
    outputs::LookupTable{Variable}
end

#struct Goto <: BranchInstruction
#    target::BasicBlock
#end

#struct GotoIf{A<:StaticAddress} <: BranchInstruction
#    cond::A
#    target::BasicBlock
#end

#struct GotoIfNot{A<:StaticAddress} <: BranchInstruction
#    cond::A
#    target::BasicBlock
#end

#mutable struct CFG <: Program
#    start::BasicBlock
#    globals::Dict{Variable, StaticAddress}
#end

abstract type AbstractMachine end

"""
    compile(::Type{T}, program::Program) where {T<:AbstractMachine}

Compiles the IR to a Julia function.
It returns a function or a callable object (functor).

```julia
const OIR = OptimizingIR
bb = OIR.BasicBlock()
# (...) add instructions to basic block
finterpreter = OIR.compile(OIR.BasicBlockInterpreter, bb)
fnative = OIR.compile(OIR.Native, bb)
```
"""
function compile end
