
function CompiledBasicBlock(b::BasicBlock)
    return CompiledBasicBlock(b.instructions.entries, b.inputs, b.mutable_locals, b.immutable_locals, b.outputs)
end

@inline input_variables(bb::CompiledBasicBlock) = bb.inputs
@inline output_variables(bb::CompiledBasicBlock) = bb.outputs
@inline is_input(bb::CompiledBasicBlock, var::ImmutableVariable) = var ∈ bb.inputs
@inline is_input(bb::CompiledBasicBlock, var::MutableVariable) = false
@inline is_output(bb::CompiledBasicBlock, var::Variable) = var ∈ bb.outputs
@inline inputindex(bb::CompiledBasicBlock, op::Variable) = indexof(bb.inputs, op)

@inline required_memory_size(program::CompiledBasicBlock) = length(program.instructions)
@inline required_input_values_size(program::CompiledBasicBlock) = length(input_variables(program))
@inline required_memory_size(program::BasicBlock) = length(program.instructions)
@inline required_input_values_size(program::BasicBlock) = length(input_variables(program))

"Used to compile to a function that is interpreted when executed."
mutable struct BasicBlockInterpreter{T} <: AbstractMachine
    program::CompiledBasicBlock
    memory::Vector{T}
    input_values::Vector{T}
    runtime_bindings::Dict{MutableVariable, T}

    function BasicBlockInterpreter(
                program::CompiledBasicBlock,
                memory_buffer::Vector{T},
                input_values_buffer::Vector{T};
                auto_resize_buffers::Bool=true
            ) where {T}

        #@assert !hasbranches(b) "BasicBlockInterpreter does not support branches"

        if auto_resize_buffers
            if length(memory_buffer) < required_memory_size(program)
                resize!(memory_buffer, required_memory_size(program))
            end

            if length(input_values_buffer) < required_input_values_size(program)
                resize!(input_values_buffer, required_input_values_size(program))
            end
        else
            @assert length(memory_buffer) >= required_memory_size(program)
            @assert length(input_values_buffer) >= required_input_values_size(program)
        end

        return new{T}(program, memory_buffer, input_values_buffer, Dict{MutableVariable, T}())
    end
end

function BasicBlockInterpreter(
            b::BasicBlock,
            memory_buffer::Vector{T},
            input_values_buffer::Vector{T};
            auto_resize_buffers::Bool=true
        ) where {T}

    return BasicBlockInterpreter(CompiledBasicBlock(b), memory_buffer, input_values_buffer, auto_resize_buffers=auto_resize_buffers)
end

function BasicBlockInterpreter(b::BasicBlock; word_type::Type{T}=Any) where {T}
    return BasicBlockInterpreter(b, Vector{word_type}(undef, required_memory_size(b)), Vector{word_type}(undef, required_input_values_size(b)), auto_resize_buffers=false)
end

function BasicBlockInterpreter(b::CompiledBasicBlock; word_type::Type{T}=Any) where {T}
    return BasicBlockInterpreter(b, Vector{word_type}(undef, required_memory_size(b)), Vector{word_type}(undef, required_input_values_size(b)), auto_resize_buffers=false)
end

compile(::Type{BasicBlockInterpreter}, program::Program) = BasicBlockInterpreter(program)
compile(::Type{BasicBlockInterpreter{T}}, program::Program) where {T} = BasicBlockInterpreter(program, word_type=T)

function set_input!(machine::BasicBlockInterpreter, input)

    input_variables_count = length(input_variables(machine.program))

    @assert input_variables_count <= length(machine.input_values)
    @assert input_variables_count == length(input) "Expected $input_variables_count arguments. Got $(length(input))."

    for i in 1:input_variables_count
        @inbounds machine.input_values[i] = input[i]
    end

    nothing
end

# `machine(args...)` will run the program
function (machine::BasicBlockInterpreter)(input...)
    set_input!(machine, input)

    for (i, instruction) in enumerate(machine.program.instructions)
        @inbounds machine.memory[i] = execute_op(machine, instruction)
    end

    return return_values(machine)
end

function execute_op(machine::BasicBlockInterpreter, op::Const{T}) :: T where {T}
    return op.val
end

deref(::BasicBlockInterpreter, arg::Const) = arg.val
deref(machine::BasicBlockInterpreter, arg::SSAValue) = machine.memory[arg.address]
deref(machine::BasicBlockInterpreter, arg::MutableVariable) = machine.runtime_bindings[arg]

function deref(machine::BasicBlockInterpreter, arg::ImmutableVariable)
    if is_input(machine.program, arg)
        @inbounds machine.input_values[ inputindex(machine.program, arg) ]
    else
        deref(machine, machine.program.immutable_locals[arg])
    end
end

deref(machine::BasicBlockInterpreter, args::AbstractValue...) = map(ssa -> deref(machine, ssa), args)

execute_op(machine::BasicBlockInterpreter, op::PureInstruction) = execute_op(machine, op.call)
execute_op(machine::BasicBlockInterpreter, op::ImpureInstruction) = execute_op(machine, op.call)
execute_op(machine::BasicBlockInterpreter, op::CallUnary) = op.op(deref(machine, op.arg))
execute_op(machine::BasicBlockInterpreter, op::CallBinary) = op.op(deref(machine, op.arg1), deref(machine, op.arg2))
execute_op(machine::BasicBlockInterpreter, op::Call3Args) = op.op(deref(machine, op.arg1), deref(machine, op.arg2), deref(machine, op.arg3))
execute_op(machine::BasicBlockInterpreter, op::Call4Args) = op.op(deref(machine, op.arg1), deref(machine, op.arg2), deref(machine, op.arg3), deref(machine, op.arg4))
execute_op(machine::BasicBlockInterpreter, op::Call5Args) = op.op(deref(machine, op.arg1), deref(machine, op.arg2), deref(machine, op.arg3), deref(machine, op.arg4), deref(machine, op.arg5))
execute_op(machine::BasicBlockInterpreter, op::Call6Args) = op.op(deref(machine, op.arg1), deref(machine, op.arg2), deref(machine, op.arg3), deref(machine, op.arg4), deref(machine, op.arg5), deref(machine, op.arg6))

function execute_op(::BasicBlockInterpreter, ::Assignment{V}) where {V<:ImmutableVariable}
    # no-op
    nothing
end

function execute_op(machine::BasicBlockInterpreter, assignment::Assignment{V}) where {V<:MutableVariable}
    runtime_bind!(machine, assignment.lhs, deref(machine, assignment.rhs))
end

function runtime_bind!(machine::BasicBlockInterpreter, var::MutableVariable, val::Any)
    machine.runtime_bindings[var] = val
end

eachvariable(machine::BasicBlockInterpreter) = eachvariable(machine.program)

function return_values(machine::BasicBlockInterpreter)
    out_vars = output_variables(machine.program)

    if isempty(out_vars)
        return nothing
    elseif length(out_vars) == 1
        return deref(machine, out_vars[1])
    else
        return Tuple( deref(machine, variable) for variable in output_variables(machine.program) )
    end
end
