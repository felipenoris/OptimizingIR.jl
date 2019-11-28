
abstract type Address end

struct NullPointer <: Address
end

"""
A pointer to an instruction
that computes a value.
"""
struct SSAValue <: Address
    index::Int
end

"""
External input to the program.
It is considered an immutable value.
"""
struct InputRef <: Address
    symbol::Symbol
end

"Constant value to be encoded directly into the IR"
struct Const{T} <: Address
    val::T
end

abstract type Instruction end
abstract type LinearInstruction <: Instruction end
abstract type BranchInstruction <: Instruction end

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
mutable struct GetIndex{N, A<:Address, B<:Address} <: LinearInstruction
    array::A
    index::NTuple{N, B}
end

GetIndex(array::Address, index::Address...) = GetIndex(array, index)

# marking as mutable avoids Value Numbering for this instruction
mutable struct SetIndex{N, A1<:Address, A2<:Address} <: LinearInstruction
    array::A1
    value::A2
    index::NTuple{N, Address}
end

SetIndex(array::Address, value::Address, index::Address...) = SetIndex(array, value, index)

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

abstract type AbstractMachine end

"compile(::Type{T}, program::Program) :: Function where {T<:AbstractMachine}"
function compile end
