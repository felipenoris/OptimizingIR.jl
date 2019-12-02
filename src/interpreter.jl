
struct BasicBlockInterpreter{T} <: AbstractMachine
    program::BasicBlock
    memory::Vector{Any}
    input_values::Vector{T}

    function BasicBlockInterpreter(b::BasicBlock, input_values::Vector{T}) where {T}
        @assert !hasbranches(b) "BasicBlockInterpreter does not support branches"
        @assert length(input_values) == length(b.inputs) "Expected `input_values` with $(length(b.inputs)) elements. Got $(length(input_values))."
        return new{T}(b, Vector{Any}(undef, required_memory_size(b)), input_values)
    end
end

function compile(::Type{T}, program::Program) where {T<:BasicBlockInterpreter}
    return input -> begin
        input_vector = create_input_vector(input_symbols(program), input)
        machine = T(program, input_vector)
        run_program!(machine)
        return return_values(machine)
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

function deref(machine::BasicBlockInterpreter, op::InputValue)
    return @inbounds machine.input_values[ inputindex(machine.program, op) ]
end

deref(machine::AbstractMachine, arg::Const) = arg.val
deref(machine::BasicBlockInterpreter, arg::SSAValue) = machine.memory[arg.index]
deref(machine::BasicBlockInterpreter, arg::Variable) = deref(machine, follow(machine.program, arg))
deref(machine::AbstractMachine, args::Address...) = map(ssa -> deref(machine, ssa), args)

execute_op(machine::AbstractMachine, op::CallUnary) = op.op(deref(machine, op.arg))
execute_op(machine::AbstractMachine, op::CallBinary) = op.op(deref(machine, op.arg1), deref(machine, op.arg2))
execute_op(machine::AbstractMachine, op::CallVararg) = op.op(deref(machine, op.args...)...)
execute_op(machine::AbstractMachine, op::ImpureCall) = execute_op(machine, op.instruction)
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

function create_input_vector(input_symbols::LookupTable{InputValue}, input_values::Dict{InputValue, T}) where {T}
    result = Vector{T}(undef, length(input_symbols))
    for (i, sym) in enumerate(input_symbols)
        @inbounds result[i] = input_values[sym]
    end
    return result
end

function create_input_vector(input_symbols::LookupTable{InputValue}, input_values::Vector)
    @assert length(input_symbols) == length(input_values)
    return input_values
end

input_symbols(bb::BasicBlock) = bb.inputs
