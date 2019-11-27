
abstract type AbstractMachine end

struct BasicBlockInterpreter{T} <: AbstractMachine
    program::BasicBlock
    memory::Vector{Any}
    input_values::Vector{T}

    function BasicBlockInterpreter(b::BasicBlock, input_values::Vector{T}) where {T}
        new{T}(b, Vector{Any}(undef, required_memory_size(b)), input_values)
    end
end

required_memory_size(b::BasicBlock) = length(b.instructions)

function run_program!(machine::BasicBlockInterpreter)
    for (i, instruction) in enumerate(machine.program.instructions)
        machine.memory[i] = execute_op(machine, instruction)
    end
end

function execute_op(machine::AbstractMachine, op::Const{T}) :: T where {T}
    return op.val
end

function execute_op(machine::AbstractMachine, op::InputRef)
    input_index = indexof(machine.program.inputs, op.symbol)
    return @inbounds machine.input_values[ input_index ]
end

deref(machine::BasicBlockInterpreter, arg::SSAValue) = machine.memory[arg.index]
deref(machine::BasicBlockInterpreter, args::SSAValue...) = map(ssa -> deref(machine, ssa), args)

execute_op(machine::AbstractMachine, op::OpUnary) = op.op(deref(machine, op.arg))
execute_op(machine::AbstractMachine, op::OpBinary) = op.op(deref(machine, op.arg1), deref(machine, op.arg2))
execute_op(machine::AbstractMachine, op::OpVararg) = op.op(deref(machine, op.args...)...)
execute_op(machine::AbstractMachine, op::OpGetIndex) = getindex(deref(machine, op.array), deref(machine, op.index...)...)
execute_op(machine::AbstractMachine, op::OpSetIndex) = setindex!(deref(machine, op.array), deref(machine, op.value), deref(machine, op.index...)...)

readslot(machine::BasicBlockInterpreter, slotname::Symbol) = deref(machine, addressof(machine.program, slotname))
