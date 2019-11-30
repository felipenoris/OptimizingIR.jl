
struct Native <: AbstractMachine
end

function compile(::Type{Native}, program::Program)
    f = func(program)
    input_syms = input_symbols(program)

    return input -> begin
        input_vector = create_input_vector(input_syms, input)
        return f(input_vector)
    end
end

tmpsym(i::Integer) = Symbol(:t, i)

function build_function_body_expr(ir::Program)
    block = Expr(:block)

    itr = eachinstruction(ir)
    for (i, instruction) in enumerate(itr)
        push!(block.args, Expr(:(=), tmpsym(i), julia_expr(ir, instruction)))
    end

    push!(block.args, return_expr(ir))

    return block
end

function return_expr(bb::BasicBlock)
    ret_expr = Expr(:tuple)

    for (k, v) in bb.slots
        push!(ret_expr.args, Expr(:(=), k, julia_expr(bb, v)))
    end

    return ret_expr
end

julia_expr(bb::BasicBlock, c::CallUnary) = Expr(:call, c.op, julia_expr(bb, c.arg))

function julia_expr(bb::BasicBlock, c::CallBinary)
    Expr(:call, c.op, julia_expr(bb, c.arg1), julia_expr(bb, c.arg2))
end

function julia_expr(bb::BasicBlock, c::CallVararg)
    Expr(:call, c.op, map( arg -> julia_expr(bb, arg), c.args)...)
end

julia_expr(bb::BasicBlock, c::ImpureCall) = julia_expr(bb, c.instruction)

function julia_expr(bb::BasicBlock, input::InputRef)
    Expr(:call, Base.getindex, :x, inputindex(bb, input))
end

julia_expr(bb::BasicBlock, constant::Const) = constant.val
julia_expr(bb::BasicBlock, ssa::SSAValue) = tmpsym(ssa.index)

function julia_expr(bb::BasicBlock, op::GetIndex)
    Expr(:call,
        Base.getindex,
        julia_expr(bb, op.array),
        map(i -> julia_expr(bb, i), op.index)...)
end

function julia_expr(bb::BasicBlock, op::SetIndex)
    Expr(:call,
        Base.setindex!,
        julia_expr(bb, op.array),
        julia_expr(bb, op.value),
        map(i -> julia_expr(bb, i), op.index)...)
end

# Based on Mike's IRTools.jl
function func(ir::Program)
    @eval @generated function $(gensym())(x)
        return build_function_body_expr($ir)
    end
end
