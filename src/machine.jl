
abstract type AbstractMachine end

function compile(::Type{T}, program::Program) where {T<:AbstractMachine}
    return input -> begin
        input_vector = create_input_vector(program, input)
        machine = T(program, input_vector)
        run_program!(machine)
        return return_values(machine)
    end
end

struct BasicBlockInterpreter{T} <: AbstractMachine
    program::BasicBlock
    memory::Vector{Any}
    input_values::Vector{T}

    function BasicBlockInterpreter(b::BasicBlock, input_values::Vector{T}) where {T}
        @assert b.branch == nothing && b.next == nothing "BasicBlockInterpreter does not support branches"
        @assert length(input_values) == length(b.inputs) "Expected `input_values` with $(length(b.inputs)) elements. Got $(length(input_values))."
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

function deref(machine::BasicBlockInterpreter, op::InputRef)
    input_index = indexof(machine.program.inputs, op.symbol)
    return @inbounds machine.input_values[ input_index ]
end

deref(machine::AbstractMachine, arg::Const) = arg.val
deref(machine::BasicBlockInterpreter, arg::SSAValue) = machine.memory[arg.index]
deref(machine::AbstractMachine, args::Address...) = map(ssa -> deref(machine, ssa), args)

execute_op(machine::AbstractMachine, op::CallUnary) = op.op(deref(machine, op.arg))
execute_op(machine::AbstractMachine, op::CallBinary) = op.op(deref(machine, op.arg1), deref(machine, op.arg2))
execute_op(machine::AbstractMachine, op::CallVararg) = op.op(deref(machine, op.args...)...)
execute_op(machine::AbstractMachine, op::ImpureCall) = execute_op(machine, op.op)
execute_op(machine::AbstractMachine, op::GetIndex) = getindex(deref(machine, op.array), deref(machine, op.index...)...)
execute_op(machine::AbstractMachine, op::SetIndex) = setindex!(deref(machine, op.array), deref(machine, op.value), deref(machine, op.index...)...)

readslot(machine::BasicBlockInterpreter, slotname::Symbol) = deref(machine, addressof(machine.program, slotname))

function derefslots(machine::BasicBlockInterpreter)
    result = Dict{Symbol, Any}()
    for (k, v) in machine.program.slots
        result[k] = deref(machine, v)
    end
    return result
end

namedtuple(d::Dict) = NamedTuple{Tuple(keys(d))}(values(d))
return_values(machine::BasicBlockInterpreter) = namedtuple(derefslots(machine))

function create_input_vector(bb::BasicBlock, input::Dict{Symbol, T}) where {T}
    len = length(bb.inputs)
    result = Vector{T}(undef, len)
    for i in 1:len
        @inbounds result[i] = input[bb.inputs[i]]
    end
    return result
end

# no-op
create_input_vector(bb::BasicBlock, input::Vector) = input
