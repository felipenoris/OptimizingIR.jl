
struct BasicBlockInterpreter <: AbstractMachine
    program::BasicBlock
    memory::Vector{Any}
    input_values::Vector{Any}

    function BasicBlockInterpreter(b::BasicBlock)
        #@assert !hasbranches(b) "BasicBlockInterpreter does not support branches"
        return new(b, Vector{Any}(undef, required_memory_size(b)), Vector{Any}(undef, length(input_variables(b))))
    end
end

function compile(::Type{T}, program::Program) where {T<:BasicBlockInterpreter}
    return BasicBlockInterpreter(program)
end

required_memory_size(b::BasicBlock) = length(b.instructions)

function set_input!(machine::BasicBlockInterpreter, input)
    @assert length(input) == length(machine.input_values)
    for i in 1:length(machine.input_values)
        @inbounds machine.input_values[i] = input[i]
    end
    nothing
end

function (machine::BasicBlockInterpreter)(input...)
    set_input!(machine, input)

    for (i, instruction) in enumerate(machine.program.instructions)
        @inbounds machine.memory[i] = execute_op(machine, instruction)
    end

    return return_values(machine)
end

function execute_op(machine::AbstractMachine, op::Const{T}) :: T where {T}
    return op.val
end

deref(machine::AbstractMachine, arg::Const) = arg.val
deref(machine::BasicBlockInterpreter, arg::SSAValue) = machine.memory[arg.address]

function deref(machine::BasicBlockInterpreter, arg::Variable)
    if is_input(machine.program, arg)
        @inbounds machine.input_values[ inputindex(machine.program, arg) ]
    else
        deref(machine, follow(machine.program, arg))
    end
end

deref(machine::AbstractMachine, args::AbstractValue...) = map(ssa -> deref(machine, ssa), args)

execute_op(machine::AbstractMachine, op::PureInstruction) = execute_op(machine, op.call)
execute_op(machine::AbstractMachine, op::ImpureInstruction) = execute_op(machine, op.call)

execute_op(machine::AbstractMachine, op::CallUnary) = op.op(deref(machine, op.arg))
execute_op(machine::AbstractMachine, op::CallBinary) = op.op(deref(machine, op.arg1), deref(machine, op.arg2))
execute_op(machine::AbstractMachine, op::CallVararg) = op.op(deref(machine, op.args...)...)
execute_op(machine::AbstractMachine, op::GetIndex) = getindex(deref(machine, op.array), deref(machine, op.index...)...)
execute_op(machine::AbstractMachine, op::SetIndex) = setindex!(deref(machine, op.array), deref(machine, op.value), deref(machine, op.index...)...)

eachvariable(machine::BasicBlockInterpreter) = eachvariable(machine.program)

function derefvariables(machine::BasicBlockInterpreter)
    result = Dict{Symbol, Any}()
    for variable in eachvariable(machine)
        result[variable.symbol] = deref(machine, variable)
    end
    return result
end

namedtuple(d::Dict) = NamedTuple{Tuple(keys(d))}(values(d))
return_values(machine::BasicBlockInterpreter) = namedtuple(derefvariables(machine))
