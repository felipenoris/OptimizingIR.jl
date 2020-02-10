
function Base.show(io::IO, b::BasicBlock)

    sep() = println(io, "---------------")

    println(io, "BasicBlock")
    sep()
    println(io, "")
    println(io, "Instructions")
    sep()
    for (i, entry) in enumerate(b.instructions.entries)
        println(io, "$i | $entry")
    end
    sep()
    println(io, "")
    println(io, "Inputs")
    sep()
    for (i, sym) in enumerate(b.inputs.entries)
        println(io, "$i | $sym")
    end
    sep()
    println(io, "")
    println(io, "Variables")
    sep()
    for (sym, value) in b.variables
        println(io, "$sym | $value")
    end
    sep()
end

function Base.show(io::IO, c::Const{T}) where {T}
    print(io, "$(c.val)::$T")
end

Base.show(io::IO, v::Variable) = print(io, "$(v.symbol)")
Base.show(io::IO, ssa::SSAValue) = print(io, "%$(ssa.index)")
Base.show(io::IO, input::InputVariable) = print(io, input.symbol)
Base.show(io::IO, instruction::GetIndex) = print(io, "GetIndex($(instruction.array), $(instruction.index))")
Base.show(io::IO, instruction::SetIndex) = print(io, "SetIndex($(instruction.array), $(instruction.value), $(instruction.index))")
Base.show(io::IO, call::CallBinary) = print(io, "call($(call.op), $(call.arg1), $(call.arg2))")
Base.show(io::IO, call::CallUnary) = print(io, "call($(call.op), $(call.arg))")
Base.show(io::IO, call::CallVararg) = print(io, "call($(call.op), $(call.args))")
Base.show(io::IO, op::Op) = print(io, "$(op.op)")

function Base.show(io::IO, call::ImpureCall)
    iob = IOBuffer()
    print(iob, call.instruction)
    str = String(take!(iob))
    str_new = replace(str, "call" => "callimpure")
    print(io, str_new)
end
