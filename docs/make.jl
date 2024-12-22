
using Documenter
import OptimizingIR

makedocs(
    sitename = "OptimizingIR.jl",
    modules = [ OptimizingIR ],
    pages = [
        "Home" => "index.md",
        "API Reference" => "api.md",
    ],
    checkdocs=:none,
)

deploydocs(
    repo = "github.com/felipenoris/OptimizingIR.jl.git",
    target = "build",
)
