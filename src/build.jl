
BasicBlock() = BasicBlock(LookupTable{LinearInstruction}(), LookupTable{InputValue}(), Dict{Variable, StaticAddress}(), nothing, nothing, nothing)

function CFG()
    cfg = CFG(BasicBlock(), Dict{Variable, StaticAddress}())
    cfg.start.cfg = cfg
    cfg
end

constant(val) = Const(val)
eachvariable(bb::BasicBlock) = keys(bb.variables)
hasbranches(bb::BasicBlock) = bb.branch != nothing || bb.next != nothing

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
function follow(program::BasicBlock, arg::Variable) :: StaticAddress
    @assert haskey(program.variables, arg) "Variable $arg was not defined."
    return program.variables[arg]
end

follow(bb::BasicBlock, arg::SSAValue) = bb.instructions[arg.index]

struct InstructionIterator{T}
    instructions::T
end
Base.iterate(itr::InstructionIterator) = iterate(itr.instructions)
Base.iterate(itr::InstructionIterator, state) = iterate(itr.instructions, state)
eachinstruction(bb::BasicBlock) = InstructionIterator(bb.instructions)

function addinstruction!(b::BasicBlock, instruction::LinearInstruction) :: StaticAddress

    result = try_on_add_instruction_passes(b, instruction)
    if result != nothing
        return result
    end

    return SSAValue(addentry!(b.instructions, instruction))
end

function assign!(b::BasicBlock, variable::Variable, value::StaticAddress)
    b.variables[variable] = value
    nothing
end

inputindex(bb::BasicBlock, op::InputValue) = indexof(bb.inputs, op)

function addinput!(b::BasicBlock, iv::InputValue) :: StaticAddress
    addentry!(b.inputs, iv)
    return iv
end

call(op::Op, arg::StaticAddress) = wrap_if_impure(CallUnary(op, arg))
call(op::Op, arg1::StaticAddress, arg2::StaticAddress) = wrap_if_impure(CallBinary(op, arg1, arg2))
call(op::Op, args::StaticAddress...) = wrap_if_impure(CallVararg(op, args))

function wrap_if_impure(instruction::PureCall{OP}) where {OP}
    if ispure(OP)
        return instruction
    else
        return ImpureCall(instruction)
    end
end

call(f::Function, arg::StaticAddress) = call(Op(f), arg)
call(f::Function, arg1::StaticAddress, arg2::StaticAddress) = call(Op(f), arg1, arg2)
call(f::Function, args::StaticAddress...) = call(Op(f), args...)
