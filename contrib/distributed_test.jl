
using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
Pkg.instantiate()

import OptimizingIR

using Distributed
addprocs(2)
@everywhere begin
    using Pkg
    Pkg.activate(joinpath(@__DIR__, ".."))
    import OptimizingIR
    include("innermod.jl")
end

@everywhere begin

    function run(x)
        fun = INNERMOD.build_fun()
        result = fun.f(x)
        println("Worker $(myid()): result = $result")
        return result
    end
end

inputs = [ 1.0, 2.0, 3.0 ]
results = pmap( g -> run(g), inputs)

println("Results: $results")
