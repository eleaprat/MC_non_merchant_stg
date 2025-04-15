function stor_val_update_opt(∆t, λ, p_C_intra, p_D_intra, η_C, η_D, T)

    p_C_intra_num = round.(p_C_intra, digits=6)
    p_D_intra_num = round.(p_D_intra, digits=6)

    # Model
    model = Model(HiGHS.Optimizer)
    set_silent(model)

    ### Variables
    @variable(model, p_C_intra_local[T]>=0)
    @variable(model, p_C_intra_moved[T]>=0)

    ####### Objective
    @objective(model, Min, ∆t * sum(λ[t] * (p_D_intra_num[t] - p_C_intra_local[t]) for t in T))
    ### Subject to
    @constraint(model, total_zero, sum((η_C * p_C_intra_local[t]- (1/η_D) * p_D_intra_num[t]) for t in T) == 0)
    @constraint(model, positive_revenue, ∆t * sum(λ[t] * (p_D_intra_num[t] - p_C_intra_local[t]) for t in T) >= 0)
    @constraint(model, sum_local_moved[t in T], p_C_intra_num[t] == p_C_intra_local[t] + p_C_intra_moved[t])

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

function stor_update(∆t, λ_num, p_C_intra, p_D_intra, e_inter, e_intra, T, V, S, E_init, η_C, η_D, discount)
    λ = round.(λ_num, digits=6)

    # Update value of storage with the changes from the market clearing
    v_remove = []
    for v in V
        if e_inter[v,T[end]] >= 1e-6
            E_init[v] == e_inter[v,T[end]]
        else
            append!(v_remove, v)
        end
    end
    # Remove element from the value vectors when it is used completely
    splice!(E_init,v_remove)
    splice!(S,v_remove)
    # Check if value vectors are empty, and if so add zeros
    if isempty(E_init)
        E_init=[0.0]
        S=[0.0]
    end
    # Update V
    V=[1:length(S);]

    # Apply discount
    S = (1-discount).* S

    # Update incase of net charge
    if e_intra[end] >= 1e-6
        p_C_intra_moved_val = stor_val_update_opt(∆t, λ, p_C_intra, p_D_intra, η_C, η_D, T)

        for t in T
            qty = p_C_intra_moved_val[t]
            if qty > 1e-6
                price = round((1/(η_C * η_D)) * λ[t],digits=6)
                position_S = indexin(price, S)[1]
                if position_S !== nothing
                    E_init[position_S] += (∆t * η_C * qty)
                else
                    if E_init ==[0.0] # Check if "empty" value vectors to replace the zeros
                        E_init = [(∆t * η_C * qty)]
                        S = [price]
                    else
                        append!(S,price)
                        append!(E_init,(∆t * η_C * qty))
                    end
                end
            end
        end
        V=[1:length(S);]
    end

    E_init = round.(E_init, digits=6)

    return V, S, E_init
end
