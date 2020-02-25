
"""
Generic struct for a lookup table that stores
an ordered list of distinct elements.

* `element` is stored in `entries` vector at index `i`.

* `index[element]` retrieves the index `i`.

Use `addentry!` to add items to the table.
It the table already has the item, `addentry!`
will return the existing item's index.
"""
mutable struct LookupTable{T}
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

function Base.in(item::T, collection::LookupTable{T}) :: Bool where {T}
    return haskey(collection.index, item)
end

function indexof(lookup_table::LookupTable{T}, item::T) :: Int where {T}
    return lookup_table.index[item]
end

Base.lastindex(lookup_table::LookupTable) = lastindex(lookup_table.entries)

function Base.getindex(lookup_table::LookupTable{T}, key::Integer) :: T where {T}
    return lookup_table.entries[key]
end

function Base.length(lookup_table::LookupTable{T}) where {T}
    return length(lookup_table.entries)
end

function Base.isempty(lookup_table::LookupTable{T}) :: Bool where {T}
    return isempty(lookup_table.entries)
end

function Base.iterate(lookup_table::LookupTable{T}) where {T}
    return Base.iterate(lookup_table.entries)
end

function Base.iterate(lookup_table::LookupTable{T}, state) where {T}
    return Base.iterate(lookup_table.entries, state)
end

function Base.enumerate(lookup_table::LookupTable{T}) where {T}
    return enumerate(lookup_table.entries)
end

function Base.filter(f, lookup_table::LookupTable{T}) where {T}
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
