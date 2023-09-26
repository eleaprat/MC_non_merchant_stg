function mc_VLB(∆t, T, L, G, V, U, D, C, P, S, E, E_init, E_end)

    # Model
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    t1 = T[1]
    t_end = last(T)

    ### Variables
    @variable(model, 0 <= d[L, T])           # Demand of load
    @variable(model, 0 <= p[G, T])           # Production of generator
    @variable(model, p_C_intra[T] )          # Power charged or discharged for the intra-storage
    @variable(model, e_intra[T])             # State of energy of the intra-storage at the end of the hour
    @variable(model, 0 <= p_D_inter[V,T])    # Quantity discharged from the inter-storage
    @variable(model, 0 <= e_inter[V,T])      # State of energy of the inter-storage at the end of the hour

    ####### Market Clearing Formulation
    @objective(model, Max, ∆t * sum(sum(U[l,t]*d[l,t] for l in L) - sum(C[g,t]*p[g,t] for g in G) - sum(S[v]*p_D_inter[v,t] for v in V) for t in T)) # Objective function (5a)
    ### Subject to
    @constraint(model, energy_bal[t in T], sum(d[l,t] for l in L) + p_C_intra[t] - sum(p[g,t] for g in G) - sum(p_D_inter[v,t] for v in V) == 0) # Energy balance (5b)
    @constraint(model, gen_bound[g in G, t in T], p[g,t] <= P[g,t]) # Generator minimum and maximum output (1c)                                   
    @constraint(model, load_bound[l in L, t in T], d[l,t] <= D[l,t]) # Load minimum and maximum consumption (1d) 
    @constraint(model, stor_intra_bal[t in T;t!=t1], e_intra[t] == e_intra[t-1] + ∆t * p_C_intra[t]) # Intra-storage update (5c)
    @constraint(model, stor_intra_bal_1, e_intra[t1] == ∆t * p_C_intra[t1]) # Initial intra-storage update (5d)
    @constraint(model, final_pos, e_intra[t_end] >= 0) # Final level intra-storage (5e)
    @constraint(model, stor_inter_bal[v in V, t in T;t!=t1], e_inter[v,t] == e_inter[v,t-1] - ∆t * p_D_inter[v,t]) # Inter-storage update (5f)
    @constraint(model, stor_inter_bal_1[v in V], e_inter[v,t1] == E_init[v] - ∆t * p_D_inter[v,t1]) # Initial inter-storage update (5g)
    @constraint(model, stor_bound_low_all[t in T], e_intra[t] + sum(e_inter[v,t] for v in V) >= 0) # Storage minimum level (5h)
    @constraint(model, stor_bound_all[t in T], e_intra[t] + sum(e_inter[v,t] for v in V) <= E) # Storage maximum level (5h)
    @constraint(model, stor_end, e_intra[t_end] + sum(e_inter[v,t_end] for v in V) >= E_end) # Storage final level (5j)

    # Solve
    optimize!(model)
    #************************************************************************
    if termination_status(model) == MOI.OPTIMAL # If an optimal solution was found
        
        SW = objective_value(model) + sum(sum(value.(p_D_inter)[v,t]*S[v] for v in V) for t in T) # Social welfare as the sum of surpluses, substracting the virtual bids from the value of the objective function
        λ = Vector(-dual.(energy_bal)) # Price as the dual variable of the energy balance
        d_val = Array(value.(d))
        p_val = Array(value.(p))
        p_C_intra_val = Vector(value.(p_C_intra))
        e_intra_val = Vector(value.(e_intra))
        p_D_inter_val = Array(value.(p_D_inter))
        e_inter_val = Array(value.(e_inter))

        # Surpluses of the participants
        surplus_gen = []
        for g in G
            append!(surplus_gen,sum(p_val[g,t]*(λ[t]-C[g,t]) for t in T))
        end
        surplus_load = []
        for l in L
            append!(surplus_load,sum(d_val[l,t]*(U[l,t]-λ[t]) for t in T))
        end
        surplus_stg = sum(-p_C_intra_val[t]*λ[t] + sum(p_D_inter_val[v,t]*λ[t] for v in V) for t in T)
    else
        println("No optimal solution available")
    end
    return SW, λ, d_val, p_val, p_C_intra_val, e_intra_val, p_D_inter_val, e_inter_val, surplus_gen, surplus_load, surplus_stg
end

