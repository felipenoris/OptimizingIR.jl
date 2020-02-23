
abstract type Mutability end

struct Mutable <: Mutability
end

struct Immutable <: Mutability
end

abstract type AbstractValue{M<:Mutability} end

abstract type MutableValue <: AbstractValue{Mutable} end
abstract type ImmutableValue <: AbstractValue{Immutable} end

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
A variable that can be
assigned with [`OptimizingIR.assign!`](@ref).
"""
struct Variable{M} <: AbstractValue{M}
    symbol::Symbol
end

MutableVariable(sym::Symbol) = Variable{Mutable}(sym)
ImmutableVariable(sym::Symbol) = Variable{Immutable}(sym)

"""
Sets which optimizations are
allowed to an `Op`.
"""
struct OptimizationRule{T}
    pure::Bool              # whether the Op itself is pure or impure
    commutative::Bool
    hasleftidentity::Bool   # [left=element] op      right
    hasrightidentity::Bool  #     left       op [right=element]
    identity_element::T

    function OptimizationRule(pure::Bool, commutative::Bool,
            hasleftidentity::Bool, hasrightidentity::Bool, identity_element::T) where {T}

        if commutative || hasleftidentity || hasrightidentity
            @assert pure "Can't apply commutative or identity optimization on impure op."
        end

        new{T}(pure, commutative, hasleftidentity, hasrightidentity, identity_element)
    end
end

# typeof(O) == OptimizationRule
struct Op{F<:Function, O}
    op::F

    function Op(f::F, o::OptimizationRule) where {F<:Function}
        new{F, o}(f)
    end
end

abstract type AbstractCall end
abstract type AbstractOpCall{OP<:Op} <: AbstractCall end
abstract type Instruction end
abstract type LinearInstruction{T<:AbstractCall} <: Instruction end
abstract type BranchInstruction <: Instruction end

"""
A `PureInstruction` is a call to an operation
that always returns the same value
if the same arguments are passed to the instruction.
It is suitable for memoization, in the sense that
it can be optimized in the Value-Number algorithm
inside a Basic Block.
"""
struct PureInstruction{T} <: LinearInstruction{T}
    call::T

    function PureInstruction(call::G) where {G<:AbstractOpCall}
        # An AbstractOpCall has on Op that is either pure or impure
        @assert is_pure(call) "$G must be a pure call."
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

Marking as mutable avoids Value-Numbering for this call.
"""
mutable struct ImpureInstruction{T} <: LinearInstruction{T}
    call::T

    function ImpureInstruction(call::G) where {G<:AbstractOpCall}
        # An AbstractOpCall has on Op that is either pure or impure
        @assert is_impure(G) "$G must be an impure call."
        return new{G}(call)
    end

    function ImpureInstruction(call::G) where {G<:AbstractCall}
        # catch other AbstractCalls (GetIndex/SetIndex)
        return new{G}(call)
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

struct CallVararg{OP, N} <: AbstractOpCall{OP}
    op::OP
    args::NTuple{N, AbstractValue}
end

struct GetIndex{N, A<:Variable} <: AbstractCall
    array::A
    index::NTuple{N, AbstractValue}
end

GetIndex(array::Variable, index::AbstractValue...) = GetIndex(array, index)

struct SetIndex{N, A<:AbstractValue} <: AbstractCall
    array::Variable{Mutable}
    value::A
    index::NTuple{N, AbstractValue}
end

SetIndex(array::Variable{Mutable}, value::AbstractValue, index::AbstractValue...) = SetIndex(array, value, index)

abstract type Program end

mutable struct BasicBlock <: Program
    instructions::LookupTable{LinearInstruction}
    inputs::LookupTable{Variable}
    variables::Dict{Variable, ImmutableValue}
    outputs::LookupTable{Variable}
#    branch::Union{Nothing, BranchInstruction}
#    next::Union{Nothing, BasicBlock}
#    cfg::Union{Nothing, Program}
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

"compile(::Type{T}, program::Program) :: Function where {T<:AbstractMachine}"
function compile end
