
abstract type Address end

struct SSAValue <: Address
    index::Int # pointer to the instruction the computes the value
end

abstract type Instruction end
abstract type LinearInstruction <: Instruction end
abstract type BranchInstruction <: Instruction end

struct Const{T} <: LinearInstruction
    val::T
end

struct InputRef <: LinearInstruction
    symbol::Symbol
end

struct OpUnary{F<:Function} <: LinearInstruction
    op::F # op shouldn't have side-effects
    arg::SSAValue
end

struct OpBinary{F<:Function, iscommutative} <: LinearInstruction
    op::F # op shouldn't have side-effects
    arg1::SSAValue
    arg2::SSAValue

    function OpBinary(op::Function, arg1::SSAValue, arg2::SSAValue, iscommutative::Bool)
        new{typeof(op), iscommutative}(op, arg1, arg2)
    end
end

struct OpVararg{F<:Function, N} <: LinearInstruction
    op::F
    args::NTuple{N, SSAValue}
end

# making OpGetIndex is a hack to avoid
# Value Numbering this instruction.
# LookupTable will always fail to find existing
# instruction.
# This pairs with OpSetIndex,
# which has side-effects.
mutable struct OpGetIndex{N} <: LinearInstruction
    array::SSAValue
    index::NTuple{N, SSAValue}
end

OpGetIndex(array::SSAValue, index::SSAValue...) = OpGetIndex(array, index)

mutable struct OpSetIndex{N} <: LinearInstruction
    array::SSAValue
    value::SSAValue
    index::NTuple{N, SSAValue}
end

OpSetIndex(array::SSAValue, value::SSAValue, index::SSAValue...) = OpSetIndex(array, value, index)

mutable struct BasicBlock
    instructions::LookupTable{LinearInstruction}
    inputs::LookupTable{Symbol}
    slots::Dict{Symbol, SSAValue}
    branch::Union{Nothing, BranchInstruction}
    next::Union{Nothing, BasicBlock}
end

BasicBlock() = BasicBlock(LookupTable{LinearInstruction}(), LookupTable{Symbol}(), Dict{Symbol, SSAValue}(), nothing, nothing)

struct Goto <: BranchInstruction
    target::BasicBlock
end

struct GotoIf <: BranchInstruction
    cond::SSAValue
    target::BasicBlock
end

struct GotoIfNot <: BranchInstruction
    cond::SSAValue
    target::BasicBlock
end

mutable struct CFG
    start::BasicBlock
end

CFG() = CFG(BasicBlock())
