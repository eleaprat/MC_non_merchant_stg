using JuMP
using HiGHS

function stor_update_changes(p_D_inter, T, V, S, E_init)
    
    # Update value of storage with the changes from the market clearing
    for v in V
        for t in T
            qty = p_D_inter[v,t]
            if qty > 1e-6
                E_init[v] -= qty
            end
        end
    end
    v_remove = []
    for v in V
        if E_init[v] < 1e-6
            append!(v_remove, v)
        end
    end
    # Remove element from the value vectors when it is used completely
    splice!(E_init,v_remove)
    splice!(S,v_remove)
    # Check if empty value vectors to add zeros
    if isempty(E_init)
        E_init=[0.0]
        S=[0.0]
    end

    V=[1:length(S);]
    return E_init, S, V
end

function stor_val_update_opt(λ, p_C_intra, T)

    p_C_intra_num = round.(p_C_intra, digits=6)

    # Model
    model = Model(HiGHS.Optimizer)
    set_silent(model)

    ### Variables
    @variable(model, p_C_intra_local[T])
    @variable(model, p_C_intra_moved[T]>=0)

    ####### Objective
    @objective(model, Min, -sum(λ[t] * p_C_intra_local[t] for t in T))
    ### Subject to
    @constraint(model, total_zero, sum(p_C_intra_local[t] for t in T) == 0)
    @constraint(model, positive_revenue, -sum(λ[t] * p_C_intra_local[t] for t in T) >= 0)
    @constraint(model, sum_local_moved[t in T], p_C_intra_num[t] == p_C_intra_local[t] + p_C_intra_moved[t])
    for t in T
        if p_C_intra_num[t] > 0
            @constraint(model, p_C_intra_local[t] >= 0)
        else
            @constraint(model, p_C_intra_local[t] == p_C_intra_num[t])
        end
    end

    # Solve
    optimize!(model)
    #************************************************************************
    if termination_status(model) == MOI.OPTIMAL
        p_C_intra_local_val = Vector(value.(p_C_intra_local))
        p_C_intra_moved_val = Vector(value.(p_C_intra_moved))
    else
        println("No optimal solution available")
    end

    return p_C_intra_moved_val
   
end

function stor_update_new(λ_num, p_C_intra, p_D_inter, T, V, S, E_init, discount)
    λ = round.(λ_num, digits=6)

    # Update value of storage with the changes from the market clearing
    E_init, S, V = stor_update_changes(p_D_inter, T, V, S, E_init)

    # Update value of storage with the new values
    p_C_intra_moved_val = stor_val_update_opt(λ, p_C_intra, T)

    for t in T
        qty = p_C_intra_moved_val[t]
        if qty > 1e-6
            price = λ[t]
            position_S = indexin(price, S)[1]
            if position_S !== nothing
                E_init[position_S] += qty
            else
                if E_init ==[0.0] # Check if "empty" value vectors to replace the zeros
                    E_init = [qty]
                    S = [price]
                else
                    append!(S,price)
                    append!(E_init,qty)
                end
            end
        end
    end

    V=[1:length(S);]

    E_init = round.(E_init, digits=6)

    return V, S, E_init
end
