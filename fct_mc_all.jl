function market_clearing_all(T, L, G, U, D, C, P, E, E_init, E_end, S_end, nb_t, ∆t)

    # Model
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    t1 = T[1]
    t_end = last(T)
    nb_MI = Int(t_end/nb_t)

    ### Variables
    @variable(model, 0 <= d[L, T])           # Demand of load
    @variable(model, 0 <= p[G, T])           # Production of generator
    @variable(model, p_C[T] )                # Power charged or discharged for storage
    @variable(model, 0 <= e[T] <= E)         # State of energy of storage at the end of the time period, including bounds (1e)

    ####### Market Clearing Formulation
    @objective(model, Max, ∆t * sum(sum(U[l,t]*d[l,t] for l in L) - sum(C[g,t]*p[g,t] for g in G) for t in T) - S_end * e[t_end]) # Objective function (1a) / (4)
    ### Subject to
    @constraint(model, energy_bal[t in T], sum(d[l,t] for l in L) + p_C[t] - sum(p[g,t] for g in G) == 0) # Energy balance (1b)
    @constraint(model, gen_bound[g in G, t in T], p[g,t] <= P[g,t]) # Generator maximum output (1c)                                    
    @constraint(model, load_bound[l in L, t in T], d[l,t] <= D[l,t]) # Load maximum consumption (1d)  
    @constraint(model, stor_bal[t in T;t!=t1], e[t] == e[t-1] + ∆t * p_C[t]) # Storage update (1f) 
    @constraint(model, stor_bal_1, e[t1] == E_init + ∆t * p_C[t1]) # Initial storage update (1g)
    @constraint(model, stor_end, e[t_end] == E_end) # Final level (3)

    # Solve
    optimize!(model)

    #************************************************************************
    if termination_status(model) == MOI.OPTIMAL # If an optimal solution was found
        
        λ = Vector(-dual.(energy_bal)) # Price as the dual variable of the energy balance
        # Value of the primal variables
        d_val = Array(value.(d))
        p_val = Array(value.(p))
        p_C_val = Vector(value.(p_C))
        e_val = Vector(value.(e))

        # Calculate social welfare (SW) and the surplus of the participants
        SW = []
        surplus_gen = zeros(length(G), nb_MI)
        surplus_load = zeros(length(L), nb_MI)
        surplus_stg = []

        t_mi_start = 1
        for mi in 1:nb_MI
            t_mi_end = t_mi_start + nb_t - 1
            append!(SW, sum(sum(U[l,t]*d_val[l,t] for l in L) - sum(C[g,t]*p_val[g,t] for g in G) for t in t_mi_start:t_mi_end))
            # We use the market price received to calculate the surpluses
            for g in G
                surplus_gen[g,mi] = sum(p_val[g,t]*(λ[t]-C[g,t]) for t in t_mi_start:t_mi_end)
            end
            for l in L
                surplus_load[l,mi] = sum(d_val[l,t]*(U[l,t]-λ[t]) for t in t_mi_start:t_mi_end)
            end
            append!(surplus_stg, sum(-p_C_val[t]*λ[t] for t in t_mi_start:t_mi_end))
            t_mi_start = (t_mi_end + 1)
        end
    else
        println("No optimal solution available")
    end
    return SW, λ, d_val, p_val, p_C_val, e_val, surplus_gen, surplus_load, surplus_stg
end