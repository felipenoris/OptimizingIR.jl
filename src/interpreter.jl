
"Used to compile to a function that is interpreted when executed."
mutable struct BasicBlockInterpreter <: AbstractMachine
    program::BasicBlock
    memory::Vector{Any}
    input_values::Vector{Any}
    runtime_bindings::Dict{MutableVariable, Any}

    function BasicBlockInterpreter(b::BasicBlock)
        #@assert !hasbranches(b) "BasicBlockInterpreter does not support branches"
        required_memory_size = length(b.instructions)
        return new(b, Vector{Any}(undef, required_memory_size), Vector{Any}(undef, length(input_variables(b))), Dict{MutableVariable, Any}())
    end
end

compile(::Type{BasicBlockInterpreter}, program::Program) = BasicBlockInterpreter(program)

function set_input!(machine::BasicBlockInterpreter, input)
    @assert length(input_variables(machine.program)) == length(machine.input_values)
    @assert length(input) == length(machine.input_values) "Expected $(length(machine.input_values)) arguments. Got $(length(input))."

    for i in 1:length(machine.input_values)
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
execute_op(machine::BasicBlockInterpreter, op::CallVararg) = op.op(deref(machine, op.args...)...)
execute_op(machine::BasicBlockInterpreter, op::GetIndex) = getindex(deref(machine, op.array), deref(machine, op.index...)...)
execute_op(machine::BasicBlockInterpreter, op::SetIndex) = setindex!(deref(machine, op.array), deref(machine, op.value), deref(machine, op.index...)...)

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
