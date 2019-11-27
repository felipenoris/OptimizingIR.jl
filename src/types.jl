
abstract type Address end

struct NullPointer <: Address
end

struct SSAValue <: Address
    index::Int # pointer to the instruction the computes the value
end

abstract type Instruction end
abstract type LinearInstruction <: Instruction end
abstract type BranchInstruction <: Instruction end

"Constant value to be encoded directly into the IR"
struct Const{T} <: LinearInstruction
    val::T
end

"""
External input to the program.
It is considered a immutable variable.
"""
struct InputRef <: LinearInstruction
    symbol::Symbol
end

abstract type AbstractCall <: LinearInstruction end
abstract type PureCall <: AbstractCall end

struct CallUnary{F<:Function, A<:Address} <: PureCall
    op::F
    arg::A
end

struct CallBinary{F<:Function, iscommutative, A<:Address, B<:Address} <: PureCall
    op::F
    arg1::A
    arg2::B

    function CallBinary(op::Function, arg1::A1, arg2::A2, iscommutative::Bool) where {A1<:Address, A2<:Address}
        new{typeof(op), iscommutative, A1, A2}(op, arg1, arg2)
    end
end

struct CallVararg{F<:Function, N} <: PureCall
    op::F
    args::NTuple{N, Address}
end

# marking as mutable avoids Value Numbering for this instruction
mutable struct ImpureCall{O<:PureCall} <: AbstractCall
    op::O
end

# marking as mutable avoids Value Numbering for this instruction
mutable struct GetIndex{N, A<:Address} <: LinearInstruction
    array::SSAValue
    index::NTuple{N, A}
end

GetIndex(array::SSAValue, index::Address...) = GetIndex(array, index)

# marking as mutable avoids Value Numbering for this instruction
mutable struct SetIndex{N, A1<:Address, A2<:Address} <: LinearInstruction
    array::A1
    value::A2
    index::NTuple{N, Address}
end

SetIndex(array::SSAValue, value::Address, index::Address...) = SetIndex(array, value, index)

abstract type Program end

mutable struct BasicBlock <: Program
    instructions::LookupTable{LinearInstruction}
    inputs::LookupTable{Symbol}
    slots::Dict{Symbol, Address}
    branch::Union{Nothing, BranchInstruction}
    next::Union{Nothing, BasicBlock}
end

struct Goto <: BranchInstruction
    target::BasicBlock
end

struct GotoIf{A<:Address} <: BranchInstruction
    cond::A
    target::BasicBlock
end

struct GotoIfNot{A<:Address} <: BranchInstruction
    cond::A
    target::BasicBlock
end

mutable struct CFG
    start::BasicBlock
    globals::Dict{Symbol, Address}
end

BasicBlock() = BasicBlock(LookupTable{LinearInstruction}(), LookupTable{Symbol}(), Dict{Symbol, Address}(), nothing, nothing)
CFG() = CFG(BasicBlock(), Dict{Symbol, Address}())
