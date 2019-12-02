
abstract type Address end
abstract type StaticAddress <: Address end
abstract type MutableAddress <: Address end

struct NullPointer <: StaticAddress
end

"""
A pointer to an instruction
that computes a value.
"""
struct SSAValue <: StaticAddress
    index::Int
end

"""
External input to the program.
It is considered an immutable value.
"""
struct InputValue <: StaticAddress
    symbol::Symbol
end

"Constant value to be encoded directly into the IR"
struct Const{T} <: StaticAddress
    val::T
end

"A mutable output value. See [`OptimizingIR.assign!`](@ref)."
struct Variable <: MutableAddress
    symbol::Symbol
end

struct OptimizationRule{T}
    pure::Bool
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

struct Op{F<:Function, O}
    op::F

    function Op(f::F, o::OptimizationRule) where {F<:Function}
        new{F, o}(f)
    end
end

abstract type Instruction end
abstract type LinearInstruction <: Instruction end
abstract type BranchInstruction <: Instruction end

abstract type AbstractCall{OP<:Op} <: LinearInstruction end
abstract type PureCall{OP} <: AbstractCall{OP} end

struct CallUnary{OP, A<:StaticAddress} <: PureCall{OP}
    op::OP
    arg::A
end

struct CallBinary{OP, A<:StaticAddress, B<:StaticAddress} <: PureCall{OP}
    op::OP
    arg1::A
    arg2::B
end

struct CallVararg{OP, N} <: PureCall{OP}
    op::OP
    args::NTuple{N, StaticAddress}
end

# marking as mutable avoids Value Numbering for this instruction
mutable struct ImpureCall{OP, P<:PureCall{OP}} <: AbstractCall{OP}
    instruction::P

    function ImpureCall(instruction::PureCall{OP}) where {OP}
        @assert !ispure(OP) "Can't create ImpureCall with a pure OptimizationRule."
        new{OP, PureCall{OP}}(instruction)
    end
end

# marking as mutable avoids Value Numbering for this instruction
mutable struct GetIndex{N, A<:StaticAddress, B<:StaticAddress} <: LinearInstruction
    array::A
    index::NTuple{N, B}
end

GetIndex(array::StaticAddress, index::StaticAddress...) = GetIndex(array, index)

# marking as mutable avoids Value Numbering for this instruction
mutable struct SetIndex{N, A1<:StaticAddress, A2<:StaticAddress} <: LinearInstruction
    array::A1
    value::A2
    index::NTuple{N, StaticAddress}
end

SetIndex(array::StaticAddress, value::StaticAddress, index::StaticAddress...) = SetIndex(array, value, index)

abstract type Program end

mutable struct BasicBlock <: Program
    instructions::LookupTable{LinearInstruction}
    inputs::LookupTable{InputValue}
    variables::Dict{Variable, StaticAddress}
    branch::Union{Nothing, BranchInstruction}
    next::Union{Nothing, BasicBlock}
    cfg::Union{Nothing, Program}
end

struct Goto <: BranchInstruction
    target::BasicBlock
end

struct GotoIf{A<:StaticAddress} <: BranchInstruction
    cond::A
    target::BasicBlock
end

struct GotoIfNot{A<:StaticAddress} <: BranchInstruction
    cond::A
    target::BasicBlock
end

mutable struct CFG <: Program
    start::BasicBlock
    globals::Dict{Variable, StaticAddress}
end

abstract type AbstractMachine end

"compile(::Type{T}, program::Program) :: Function where {T<:AbstractMachine}"
function compile end
