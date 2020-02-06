
struct VX
    id::Int
end

@testset "Basic Operations" begin

    g = OptimizingIR.Graphs.DirectedGraph(VX)

    @test OptimizingIR.Graphs.ne(g) == 0
    @test OptimizingIR.Graphs.nv(g) == 0

    v1 = VX(1)
    v2 = VX(2)

    OptimizingIR.Graphs.add_vertex!(g, v1)
    @test !OptimizingIR.Graphs.has_edge(g, v1, v1)

    @test OptimizingIR.Graphs.ne(g) == 0
    @test OptimizingIR.Graphs.nv(g) == 1

    OptimizingIR.Graphs.add_edge!(g, v1, v1)
    @test OptimizingIR.Graphs.has_edge(g, v1, v1)
    @test OptimizingIR.Graphs.ne(g) == 1
    OptimizingIR.Graphs.remove_edge!(g, v1, v1)
    @test !OptimizingIR.Graphs.has_edge(g, v1, v1)
    @test OptimizingIR.Graphs.ne(g) == 0

    OptimizingIR.Graphs.add_vertex!(g, v2)
    @test OptimizingIR.Graphs.ne(g) == 0
    @test OptimizingIR.Graphs.nv(g) == 2

    OptimizingIR.Graphs.add_edge!(g, v1, v2)
    @test OptimizingIR.Graphs.has_edge(g, v1, v2)
    @test !OptimizingIR.Graphs.has_edge(g, v2, v1)
    @test OptimizingIR.Graphs.ne(g) == 1
    @test OptimizingIR.Graphs.nv(g) == 2

    OptimizingIR.Graphs.add_edge!(g, v2, v2)
    @test OptimizingIR.Graphs.has_edge(g, v2, v2)
    @test !OptimizingIR.Graphs.has_edge(g, v2, v1)
    @test OptimizingIR.Graphs.ne(g) == 2
    @test OptimizingIR.Graphs.nv(g) == 2

    println(g)
end

@testset "CFG Example" begin
    cfg = OptimizingIR.Graphs.DirectedGraph(VX)

    for i in 0:8
        OptimizingIR.Graphs.add_vertex!(cfg, VX(i))
    end

    OptimizingIR.Graphs.add_edge!(cfg, VX(0), VX(1))
    OptimizingIR.Graphs.add_edge!(cfg, VX(1), VX(2))
    OptimizingIR.Graphs.add_edge!(cfg, VX(1), VX(5))
    OptimizingIR.Graphs.add_edge!(cfg, VX(2), VX(3))
    OptimizingIR.Graphs.add_edge!(cfg, VX(3), VX(4))
    OptimizingIR.Graphs.add_edge!(cfg, VX(5), VX(6))
    OptimizingIR.Graphs.add_edge!(cfg, VX(5), VX(8))
    OptimizingIR.Graphs.add_edge!(cfg, VX(6), VX(7))
    OptimizingIR.Graphs.add_edge!(cfg, VX(8), VX(7))
    OptimizingIR.Graphs.add_edge!(cfg, VX(7), VX(3))
    OptimizingIR.Graphs.add_edge!(cfg, VX(3), VX(1))

    @test OptimizingIR.Graphs.ne(cfg) == 11
    @test OptimizingIR.Graphs.nv(cfg) == 9

    # successors
    @test collect(OptimizingIR.Graphs.each_successor(cfg, VX(0))) == [ VX(1) ]
    @test OptimizingIR.Graphs.successors(cfg, VX(1)) == Set([ VX(2), VX(5) ])
    @test OptimizingIR.Graphs.successors(cfg, VX(1)) == Set([ VX(5), VX(2) ])
    @test OptimizingIR.Graphs.successors(cfg, VX(2)) == Set([ VX(3) ])
    @test OptimizingIR.Graphs.successors(cfg, VX(3)) == Set([ VX(1), VX(4) ])
    @test OptimizingIR.Graphs.successors(cfg, VX(4)) == Set()
    @test OptimizingIR.Graphs.successors_count(cfg, VX(4)) == 0
    @test eltype(OptimizingIR.Graphs.successors(cfg, VX(4))) == VX
    @test OptimizingIR.Graphs.successors(cfg, VX(5)) == Set([ VX(6), VX(8) ])
    @test OptimizingIR.Graphs.successors(cfg, VX(6)) == Set([ VX(7) ])
    @test OptimizingIR.Graphs.successors(cfg, VX(8)) == Set([ VX(7) ])
    @test OptimizingIR.Graphs.successors(cfg, VX(7)) == Set([ VX(3) ])
    @test OptimizingIR.Graphs.successors_count(cfg, VX(7)) == 1

    # predecessors
    @test OptimizingIR.Graphs.predecessors(cfg, VX(0)) == Set()
    @test OptimizingIR.Graphs.predecessors_count(cfg, VX(0)) == 0
    @test eltype(OptimizingIR.Graphs.predecessors(cfg, VX(0))) == VX
    @test OptimizingIR.Graphs.predecessors(cfg, VX(1)) == Set([ VX(0), VX(3) ])
    @test OptimizingIR.Graphs.predecessors(cfg, VX(2)) == Set([ VX(1) ])
    @test OptimizingIR.Graphs.predecessors(cfg, VX(3)) == Set([ VX(2), VX(7) ])
    @test OptimizingIR.Graphs.predecessors(cfg, VX(4)) == Set([ VX(3) ])
    @test OptimizingIR.Graphs.predecessors(cfg, VX(5)) == Set([ VX(1) ])
    @test OptimizingIR.Graphs.predecessors(cfg, VX(6)) == Set([ VX(5) ])
    @test OptimizingIR.Graphs.predecessors(cfg, VX(7)) == Set([ VX(6), VX(8) ])
    @test OptimizingIR.Graphs.predecessors_count(cfg, VX(7)) == 2

    # BFS
    @test OptimizingIR.Graphs.reachable_vertices(cfg, VX(4), true) == Set([ VX(4) ])
    @test OptimizingIR.Graphs.reachable_vertices(cfg, VX(3), true) == Set([ VX(1), VX(2), VX(3), VX(4), VX(5), VX(6), VX(7), VX(8) ])
    @test OptimizingIR.Graphs.reachable_vertices(cfg, VX(1), false) == Set([ VX(0), VX(1), VX(2), VX(3), VX(5), VX(6), VX(7), VX(8) ])

    # dominance
    @test OptimizingIR.Graphs.dominator_sets(cfg) == [Set([1]), Set([2, 1]), Set([2, 3, 1]), Set([4, 2, 1]), Set([4, 2, 5, 1]), Set([2, 6, 1]), Set([7, 2, 6, 1]), Set([2, 8, 6, 1]), Set([9, 2, 6, 1])]
    @test OptimizingIR.Graphs.strict_dominator_sets(cfg) == [Set(), Set([1]), Set([2, 1]), Set([2, 1]), Set([4, 2, 1]), Set([2, 1]), Set([2, 6, 1]), Set([2, 6, 1]), Set([2, 6, 1])]
    @test OptimizingIR.Graphs.idominators(cfg) == [nothing, 1, 2, 2, 4, 2, 6, 6, 6]
    @test OptimizingIR.Graphs.dominance_frontiers(cfg) == [Set([]), Set([2]), Set([4]), Set([2]), Set([]), Set([4]), Set([8]), Set([4]), Set([8])]
end
