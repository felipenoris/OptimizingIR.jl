
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
    println(io, "Slots")
    sep()
    for (sym, value) in b.slots
        println(io, "$sym | $value")
    end
    sep()
end
