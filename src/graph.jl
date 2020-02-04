
module Graphs

abstract type AbstractGraph{T} end

mutable struct DirectedGraph{T} <: AbstractGraph{T}
    vertices::Vector{T}
    edges::Matrix{Bool}
    vertices_index::Dict{T, Int}
end

function Base.show(io::IO, g::DirectedGraph)
    println(io, "DirectedGraph{$(eltype(g))}")

    isempty(g) && return

    println(io, "Vertices")
    for (i, v) in enumerate(g.vertices)
        println(io, "[$i] $v")
    end

    println(io, "Edges")
    println(io, g.edges)
end

function Base.eltype(g::DirectedGraph{T}) where {T}
    T
end

function Base.isempty(g::DirectedGraph) :: Bool
    return nv(g) == 0
end

function DirectedGraph(::Type{T}) where {T}
    DirectedGraph(Vector{T}(), Matrix{Bool}(undef, 0, 0), Dict{T, Int}())
end

"Number of Edges"
ne(g::DirectedGraph) = sum(g.edges)

"Number of Vertices"
nv(g::DirectedGraph) = length(g.vertices)

function has_vertex(g::DirectedGraph{T}, v::T) where {T}
    return haskey(g.vertices_index, v)
end

function get_vertex_index(g::DirectedGraph{T}, v::T) where {T}
    return g.vertices_index[v]
end

function get_vertex_from_index(g::DirectedGraph, ind::Integer)
    return g.vertices[ind]
end

function add_vertex!(g::DirectedGraph{T}, v::T) where {T}
    @assert !has_vertex(g, v) "Vertex $v is already in graph"
    push!(g.vertices, v)
    vertex_index = length(g.vertices)
    g.vertices_index[v] = vertex_index
    augment_edges_matrix!(g, vertex_index)

    nothing
end

function augment_edges_matrix!(g::DirectedGraph, vertex_index::Integer)
    @assert size(g.edges) == (vertex_index - 1, vertex_index - 1)
    new_edges = similar(g.edges, vertex_index, vertex_index)

    # copies old content
    for j in 1:(vertex_index - 1), i in 1:(vertex_index - 1)
        new_edges[i, j] = g.edges[i, j]
    end

    # reset new content
    for i in 1:vertex_index
        new_edges[i, vertex_index] = false
        new_edges[vertex_index, i] = false
    end

    # point to the new matrix
    g.edges = new_edges

    nothing
end

function add_edge!(g::DirectedGraph, source::Integer, dest::Integer)
    g.edges[source, dest] = true
    nothing
end

function add_edge!(g::DirectedGraph{T}, source::T, dest::T) where {T}
    add_edge!(g, get_vertex_index(g, source), get_vertex_index(g, dest))
end

has_edge(g::DirectedGraph, source::Integer, dest::Integer) :: Bool = g.edges[source, dest]

function has_edge(g::DirectedGraph{T}, source::T, dest::T) :: Bool where {T}
    return has_edge(g, get_vertex_index(g, source), get_vertex_index(g, dest))
end

function remove_edge!(g::DirectedGraph, source::Integer, dest::Integer)
    g.edges[source, dest] = false
    nothing
end

function remove_edge!(g::DirectedGraph{T}, source::T, dest::T) where {T}
    remove_edge!(g, get_vertex_index(g, source), get_vertex_index(g, dest))
end

abstract type GraphIteratorResult end

struct ReturnIndex <: GraphIteratorResult
end

struct ReturnVertex <: GraphIteratorResult
end

struct GraphIterator{R<:GraphIteratorResult, G<:AbstractGraph, T}
    graph::G
    edges_view::T
    result::R
end

Base.length(iter::GraphIterator) = sum(iter.edges_view)
Base.eltype(iter::GraphIterator{ReturnIndex}) = Int
Base.eltype(iter::GraphIterator{ReturnVertex, G}) where {T, G<:AbstractGraph{T}} = T

function view_on_edges(g::DirectedGraph, vertex_index::Integer, fwd::Bool)
    if fwd
        return view(g.edges, vertex_index, :)
    else
        return view(g.edges, :, vertex_index)
    end
end

function GraphIterator(g::AbstractGraph, vertex_index::Integer, fwd::Bool, result::R) where {R<:GraphIteratorResult}
    GraphIterator(
            g,
            view_on_edges(g, vertex_index, fwd),
            result
        )
end

each_adjacent_vertex_index(g::AbstractGraph, vertex_index::Integer, fwd::Bool) = GraphIterator(g, vertex_index, fwd, ReturnIndex())
each_adjacent_vertex(g::AbstractGraph, vertex_index::Integer, fwd::Bool) = GraphIterator(g, vertex_index, fwd, ReturnVertex())
adjacent_vertex_count(g::AbstractGraph, vertex_index::Integer, fwd::Bool) = length(each_adjacent_vertex_index(g, vertex_index, fwd))

function adjacent_vertex_count(g::AbstractGraph{T}, vertex::T, fwd::Bool) where {T}
    return adjacent_vertex_count(g, get_vertex_index(g, vertex), fwd)
end

predecessors_count(g::AbstractGraph, vertex) = adjacent_vertex_count(g, vertex, false)
successors_count(g::AbstractGraph, vertex) = adjacent_vertex_count(g, vertex, true)

function Base.iterate(iter::GraphIterator{R, G, T}, state=1) where {R, G, T}

    if state > length(iter.edges_view)
        return nothing
    end

    for vertex_index in state:length(iter.edges_view)
        if iter.edges_view[vertex_index]
            # edge exists
            next_vertex_index = vertex_index + 1
            if R == ReturnIndex
                return (vertex_index, next_vertex_index)
            else
                return (get_vertex_from_index(iter.graph, vertex_index), next_vertex_index)
            end
        end
    end

    return nothing
end

function each_successor(g::AbstractGraph{T}, from_vertex::T) where {T}
    return each_successor(g, get_vertex_index(g, from_vertex))
end

function each_successor(g::AbstractGraph, from_vertex_index::Integer)
    return each_adjacent_vertex(g, from_vertex_index, true)
end

function each_predecessor(g::AbstractGraph{T}, from_vertex::T) where {T}
    return each_predecessor(g, get_vertex_index(g, from_vertex))
end

function each_predecessor(g::AbstractGraph, from_vertex_index::Integer)
    return each_adjacent_vertex(g, from_vertex_index, false)
end

successors(g::AbstractGraph, from_vertex) = Set(each_successor(g, from_vertex))
predecessors(g::AbstractGraph, from_vertex) = Set(each_predecessor(g, from_vertex))

#
# BFS
#

mutable struct BFSVertex
    index::Int
    color::Symbol
    distance::Int
    π::Union{Nothing, Int} # predecessor vertex index
end

function bfs(g::AbstractGraph{T}, source_vertex_index::Integer, fwd::Bool) where {T}
    vertices_count = nv(g)

    # setup
    bfs_vertices = Vector{BFSVertex}(undef, vertices_count)
    for i in 1:vertices_count
        if i == source_vertex_index
            bfs_vertices[i] = BFSVertex(i, :gray, 0, nothing)
        else
            bfs_vertices[i] = BFSVertex(i, :white, typemax(Int), nothing)
        end
    end
    queue = Vector{Int}()
    push!(queue, source_vertex_index)

    # loop
    while !isempty(queue)
        vertex_index = pop!(queue)

        for adjacent_vertex_index in each_adjacent_vertex_index(g, vertex_index, fwd)
            bfs_vertex = bfs_vertices[adjacent_vertex_index]
            if bfs_vertex.color == :white
                bfs_vertex.color = :gray
                bfs_vertex.distance = bfs_vertices[vertex_index].distance + 1
                bfs_vertex.π = vertex_index
                push!(queue, adjacent_vertex_index)
            end
            bfs_vertices[vertex_index].color = :black
        end
    end

    return bfs_vertices
end

function bfs(g::AbstractGraph{T}, source_vertex::T, fwd::Bool) where {T}
    return bfs(g, get_vertex_index(g, source_vertex), fwd)
end

"Returns the Set of Vertices that are reachable from `source_vertex`."
function reachable(g::AbstractGraph{T}, source_vertex, fwd::Bool) where {T}
    result = Set{T}()

    for bfs_vertex in bfs(g, source_vertex, fwd)
        if bfs_vertex.color != :white
            push!(result, get_vertex_from_index(g, bfs_vertex.index))
        end
    end

    return result
end

#
# Dominance
#

"""
In a flow graph with entry node V1,
node Vi dominates node Vj if and only if
Vi lies on every path from V1 to Vj.
"""
function dominator_sets(g::AbstractGraph)

    local dom::Vector{Set{Int}}
    vertices_count = nv(g)

    if vertices_count == 0
        error("Can't execute dominance analysis on an empty graph")
    elseif vertices_count == 1
        return Set([1])
    end

    let
        # initial state: Dom(n0) = {n0}, Dom(n) = N, n != n0, N = all vertices
        all_vertices = Set([ i for i in 1:vertices_count ])
        dom = [ (i == 1 ? Set([1]) : copy(all_vertices)) for i in 1:vertices_count ]
    end

    @assert isempty(predecessors(g, 1)) "First vertex $(get_vertex_from_index(1)) can't have a predecessor."

    local changed::Bool = true

    while changed
        changed = false

        for i in 2:vertices_count
            temp = ∪(Set([i]), ∩([ dom[j] for j in each_adjacent_vertex_index(g, i, false) ]...))
            if temp != dom[i]
                dom[i] = temp
                changed = true
            end
        end
    end

    return dom
end

function strict_dominator_sets(g::AbstractGraph)
    sets = dominator_sets(g)
    for (i, set) in enumerate(sets)
        pop!(set, i)
    end
    return sets
end

"""
Returns the index of the nearest reachable vertex from a given `set`
Throws error if there is a vertex in `set` that is not reachable from `vertex_index`.
"""
function nearest_reachable_vertex_from_set(g::AbstractGraph, vertex_index::Integer, set::Set{Int}, fwd::Bool) :: Int
    bfs_vertices = bfs(g, vertex_index, fwd)

    distance_to_vertex = Dict{Int, Int}()
    for vertex in set
        bfs_vertex = bfs_vertices[vertex]
        @assert bfs_vertex.color != :white "vertex $vertex is not reachable."
        distance_to_vertex[bfs_vertex.distance] = vertex
    end

    nearest_distance = min(keys(distance_to_vertex)...)
    return distance_to_vertex[nearest_distance]
end

function idominators(g::AbstractGraph)
    result = Vector{Union{Nothing, Int}}(undef, nv(g))

    for (i, set) in enumerate(strict_dominator_sets(g))
        if isempty(set)
            result[i] = nothing
        elseif length(set) == 1
            result[i] = pop!(set)
        else
            result[i] = nearest_reachable_vertex_from_set(g, i, set, false)
        end
    end

    return result
end

function dominance_frontiers(g::AbstractGraph)
    idoms = idominators(g)
    vertices_count = nv(g)

    local runner::Int

    # initial state -> empty sets for all vertices
    result = [ Set{Int}() for i in 1:vertices_count ]

    for vertex_index in 1:vertices_count
        if predecessors_count(g, vertex_index) > 1
            for pred_vertex_index in each_adjacent_vertex_index(g, vertex_index, false)
                runner = pred_vertex_index
                while runner != idoms[vertex_index]
                    result[runner] = ∪(result[runner], Set(vertex_index))
                    runner = idoms[runner]
                end
            end
        end
    end

    return result
end

end
