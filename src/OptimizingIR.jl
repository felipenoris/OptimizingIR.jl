
"""
An  Intermediate Representation (IR) on steroids.
"""
module OptimizingIR

include("lookup_table.jl")
include("types.jl")
include("constant_propagation.jl")
include("noop.jl")
include("build.jl")
include("machine.jl")
include("print.jl")

end # module
