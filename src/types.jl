
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

struct CallUnary{OP, A<:Address} <: PureCall{OP}
    op::OP
    arg::A
end

struct CallBinary{OP, A<:Address, B<:Address} <: PureCall{OP}
    op::OP
    arg1::A
    arg2::B
end

struct CallVararg{OP, N} <: PureCall{OP}
    op::OP
    args::NTuple{N, Address}
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
