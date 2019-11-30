
"An  Intermediate Representation (IR) on steroids."
module OptimizingIR

include("lookup_table.jl")
include("optrule.jl")
include("types.jl")
include("passes.jl")
include("build.jl")
include("interpreter.jl")
include("native.jl")
include("print.jl")

end # module
