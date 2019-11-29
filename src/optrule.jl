
struct OptimizationRule{T}
    pure::Bool
    commutative::Bool
    hasleftidentity::Bool   # [left=element] op       right
    hasrightidentity::Bool  #     left       op  [right=element]
    identity_element::T

    function OptimizationRule(pure::Bool, commutative::Bool,
            hasleftidentity::Bool, hasrightidentity::Bool, identity_element::T) where {T}

        if commutative || hasleftidentity || hasrightidentity
            @assert pure "Can't apply commutative or identity optimization on impure op."
        end

        new{T}(pure, commutative, hasleftidentity, hasrightidentity, identity_element)
    end
end

optrule() = OptimizationRule(false, false, false, false, 0)
optrule(pure) = OptimizationRule(pure, false, false, false, 0)
optrule(pure, commutative) = OptimizationRule(pure, commutative, false, false, 0)

function optrule(pure::Bool, commutative::Bool,
            hasleftidentity::Bool, hasrightidentity::Bool, identity_element::T) where {T}

    return OptimizationRule(pure, commutative, hasleftidentity, hasrightidentity, identity_element)
end

ispure(rule::OptimizationRule) = rule.pure
iscommutative(rule::OptimizationRule) = rule.commutative
hasleftidentity(rule::OptimizationRule) = rule.hasleftidentity
hasrightidentity(rule::OptimizationRule) = rule.hasrightidentity
hasidentity(rule::OptimizationRule) = hasrightidentity(rule) || hasleftidentity(rule)

function get_identity_element(rule::OptimizationRule)
    @assert hasidentity(rule)
    return rule.identity_element
end
