
function Base.show(io::IO, b::T) where {T<:Union{BasicBlock, CompiledBasicBlock}}

    sep() = println(io, "---------------")
    purity_str(instruction) = is_pure(instruction) ? " Pure " : "Impure"

    function print_with_padding(num, max_number)
        lpad("$num", ndigits(max_number))
    end

    println(io, "BasicBlock")
    sep()
    println(io, "")
    println(io, "Instructions")
    sep()
    i_count = length(b.instructions)
    for (i, entry) in enumerate(b.instructions)
        println(io, "$(print_with_padding(i, i_count)) | $(purity_str(entry)) | $(entry.call)")
    end
    sep()
    println(io, "")
    println(io, "Inputs")
    sep()
    for (i, sym) in enumerate(b.inputs)
        println(io, "$i | $sym")
    end
    sep()
    println(io, "")
    println(io, "Variables - Local Mutables")
    sep()
    for v in b.mutable_locals
        println(io, "$v")
    end
    sep()
    println(io, "")
    println(io, "Variables - Local Immutables")
    sep()
    for (sym, value) in b.immutable_locals
        println(io, "$sym | $value")
    end
    sep()
    println(io, "")
    println(io, "Outputs")
    sep()
    for (i, sym) in enumerate(b.outputs)
        println(io, "$i | $sym")
    end
    sep()
end

function Base.show(io::IO, c::Const{T}) where {T}
    print(io, "$(c.val)::$T")
end

Base.show(io::IO, v::Variable) = print(io, "$(v.symbol)")
Base.show(io::IO, ssa::SSAValue) = print(io, "%$(ssa.address)")
Base.show(io::IO, call::CallBinary) = print(io, "call($(call.op), $(call.arg1), $(call.arg2))")
Base.show(io::IO, call::CallUnary) = print(io, "call($(call.op), $(call.arg))")
Base.show(io::IO, call::CallVararg) = print(io, "call($(call.op), $(call.args))")
Base.show(io::IO, op::Op) = print(io, "$(op.op)")
Base.show(io::IO, op::Assignment) = print(io, "$(op.lhs) = $(op.rhs)")
