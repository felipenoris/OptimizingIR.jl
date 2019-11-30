
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
struct InputRef <: StaticAddress
    symbol::Symbol
end

"Constant value to be encoded directly into the IR"
struct Const{T} <: StaticAddress
    val::T
end

"A mutable output value"
struct Slot <: MutableAddress
    symbol::Symbol
end

struct Op{F<:Function, O}
    op::F

    function Op(f::F, o::OptimizationRule) where {F<:Function}
        new{F, o}(f)
    end
end

Op(f::Function) = Op(f, optrule())

# defines functor for Op so that op(arg1, ...) will call op.op(arg1, ...)
# see https://docs.julialang.org/en/v1/manual/methods/#Function-like-objects-1
(op::Op)(args...) = op.op(args...)

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
    inputs::LookupTable{Symbol}
    slots::Dict{Slot, StaticAddress}
    branch::Union{Nothing, BranchInstruction}
    next::Union{Nothing, BasicBlock}
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

mutable struct CFG
    start::BasicBlock
    globals::Dict{Symbol, StaticAddress}
end

BasicBlock() = BasicBlock(LookupTable{LinearInstruction}(), LookupTable{Symbol}(), Dict{Symbol, Address}(), nothing, nothing)
CFG() = CFG(BasicBlock(), Dict{Symbol, StaticAddress}())

abstract type AbstractMachine end

"compile(::Type{T}, program::Program) :: Function where {T<:AbstractMachine}"
function compile end
