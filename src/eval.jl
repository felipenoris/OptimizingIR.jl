
struct Native <: AbstractMachine
end

tmpsym(i::Integer) = Symbol(:t, i)

function build_function_body_expr(ir::Program)
    block = Expr(:block)

    itr = eachinstruction(ir)
    for (i, instruction) in enumerate(itr)
        push!(block.args, Expr(:(=), tmpsym(i), julia_lowered_expr(ir, instruction)))
    end

    push!(block.args, return_expr(ir))

    return block
end

function return_expr(bb::BasicBlock)
    ret_expr = Expr(:tuple)

    for (k, v) in bb.slots
        push!(ret_expr.args, Expr(:(=), k, julia_lowered_expr(bb, v)))
    end

    return ret_expr
end

function julia_lowered_expr(bb::BasicBlock, c::CallUnary)
    return Expr(:call, c.op, julia_lowered_expr(bb, c.arg))
end

function julia_lowered_expr(bb::BasicBlock, c::CallBinary)
    return Expr(:call, c.op, julia_lowered_expr(bb, c.arg1), julia_lowered_expr(bb, c.arg2))
end

function julia_lowered_expr(bb::BasicBlock, c::CallVararg)
    return Expr(:call, c.op, map( arg -> julia_lowered_expr(bb, arg), c.args)...)
end

julia_lowered_expr(bb::BasicBlock, c::ImpureCall) = julia_lowered_expr(bb, c.op)

function julia_lowered_expr(bb::BasicBlock, input::InputRef)
    return Expr(:call, Base.getindex, :x, inputindex(bb, input))
end

julia_lowered_expr(bb::BasicBlock, constant::Const) = constant.val
julia_lowered_expr(bb::BasicBlock, ssa::SSAValue) = tmpsym(ssa.index)

function julia_lowered_expr(bb::BasicBlock, op::GetIndex)
    return Expr(:call, Base.getindex, julia_lowered_expr(bb, op.array), map(i -> julia_lowered_expr(bb, i), op.index)...)
end

function julia_lowered_expr(bb::BasicBlock, op::SetIndex)
    return Expr(:call, Base.setindex!, julia_lowered_expr(bb, op.array), julia_lowered_expr(bb, op.value), map(i -> julia_lowered_expr(bb, i), op.index)...)
end

# Based on Mike's IRTools.jl
function func(ir::Program)
    @eval @generated function $(gensym())(x)
        return build_function_body_expr($ir)
    end
end

function compile(::Type{Native}, program::Program)
    f = func(program)

    return input -> begin
        input_vector = create_input_vector(program, input)
        return f(input_vector)
    end
end
