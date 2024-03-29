
"""
Generic struct for a lookup table that stores
an ordered list of distinct elements.

* `element` is stored in `entries` vector at index `i`.

* `index[element]` retrieves the index `i`.

Use `addentry!` to add items to the table.
"""
struct LookupTable{T}
    entries::Vector{T}
    index::Dict{T, Int}

    function LookupTable{T}() where {T}
        return new{T}(Vector{T}(), Dict{T, Int}())
    end
end

function LookupTable(v::Vector{T}) where {T}
    result = LookupTable{T}()

    for i in v
        addentry!(result, i)
    end

    return result
end

@inline function Base.in(item::T, collection::LookupTable{T}) :: Bool where {T}
    return haskey(collection.index, item)
end

@inline function indexof(lookup_table::LookupTable{T}, item::T) :: Int where {T}
    return lookup_table.index[item]
end

@inline Base.lastindex(lookup_table::LookupTable) = lastindex(lookup_table.entries)

@inline function Base.getindex(lookup_table::LookupTable{T}, key::Integer) :: T where {T}
    return lookup_table.entries[key]
end

@inline function Base.length(lookup_table::LookupTable{T}) where {T}
    return length(lookup_table.entries)
end

@inline function Base.isempty(lookup_table::LookupTable{T}) :: Bool where {T}
    return isempty(lookup_table.entries)
end

@inline function Base.iterate(lookup_table::LookupTable{T}) where {T}
    return Base.iterate(lookup_table.entries)
end

@inline function Base.iterate(lookup_table::LookupTable{T}, state) where {T}
    return Base.iterate(lookup_table.entries, state)
end

@inline function Base.enumerate(lookup_table::LookupTable{T}) where {T}
    return enumerate(lookup_table.entries)
end

@inline function Base.filter(f, lookup_table::LookupTable{T}) where {T}
    return filter(f, lookup_table.entries)
end

"""
    addentry!(lookup_table::LookupTable{T}, item::T) :: Int where {T}

Adds `item` to `lookup_table` and returns its index
"""
function addentry!(lookup_table::LookupTable{T}, item::T) :: Int where {T}
    if item ∈ lookup_table
        return indexof(lookup_table, item)
    else
        push!(lookup_table.entries, item)
        new_index = length(lookup_table.entries)
        lookup_table.index[item] = new_index
        return new_index
    end
end
