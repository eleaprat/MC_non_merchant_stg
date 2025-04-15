function market_clearing_all(T, L, G, U, D, C, P, E, E_init, η_C, η_D, P_C, P_D, E_end, S_end, nb_t, ∆t)

    # Model
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    t1 = T[1]
    t_end = last(T)
    nb_MC = Int(t_end/nb_t)

    ### Variables
    @variable(model, 0 <= d[L,T])        # Demand of load
    @variable(model, 0 <= p[G,T])        # Production of generator
    @variable(model, 0 <= p_C[T] <= P_C) # Power charged incl. maximum (1g)
    @variable(model, 0 <= p_D[T] <= P_D) # Power discharged incl. maximum (1h)
    @variable(model, 0 <= e[T] <= E)     # State of energy of storage at the end of the time period, including bounds (1i)

    ####### Market Clearing Formulation
    @objective(model, Max, ∆t * sum(sum(U[l,t]*d[l,t] for l in L) - sum(C[g,t]*p[g,t] for g in G) for t in T) - S_end * e[t_end]) # Objective function (1a) / (3)
    ### Subject to
    @constraint(model, energy_bal[t in T], sum(d[l,t] for l in L) + p_C[t] - p_D[t] - sum(p[g,t] for g in G) == 0) # Energy balance (1b)   
    @constraint(model, stor_bal[t in T;t!=t1], e[t] == e[t-1] + ∆t * η_C * p_C[t] - ∆t * (1/η_D) * p_D[t]) # Storage update (1c) 
    @constraint(model, stor_bal_1, e[t1] == E_init + ∆t * η_C * p_C[t1] - ∆t * (1/η_D) * p_D[t1]) # Initial storage update (1d)
    @constraint(model, load_max[l in L, t in T], d[l,t] <= D[l,t]) # Maximum consumption (1e)
    @constraint(model, prod_max[g in G, t in T], p[g,t] <= P[g,t]) # Maximum production (1f)
    if E_end != false
        @constraint(model, stor_end, e[t_end] == E_end) # Final level (2)
    end

    # Solve
    optimize!(model)

    #************************************************************************
    if termination_status(model) == MOI.OPTIMAL # If an optimal solution was found
        
        λ = Vector(-dual.(energy_bal)) # Price as the dual variable of the energy balance
        # Value of the primal variables
        d_val = Array(value.(d))
        p_val = Array(value.(p))
        p_C_val = Vector(value.(p_C))
        p_D_val = Vector(value.(p_D))
        e_val = Vector(value.(e))

        # Calculate social welfare (SW) and the surplus of the participants
        SW = []
        surplus_gen = zeros(length(G), nb_MC)
        surplus_load = zeros(length(L), nb_MC)
        surplus_stg = []

        t_mc_start = 1
        for mc in 1:nb_MC
            t_mc_end = t_mc_start + nb_t - 1
            append!(SW, ∆t * sum(sum(U[l,t]*d_val[l,t] for l in L) - sum(C[g,t]*p_val[g,t] for g in G) for t in t_mc_start:t_mc_end))
            # We use the market price received to calculate the surpluses
            for g in G
                surplus_gen[g,mc] = ∆t * sum(p_val[g,t]*(λ[t]-C[g,t]) for t in t_mc_start:t_mc_end)
            end
            for l in L
                surplus_load[l,mc] = ∆t * sum(d_val[l,t]*(U[l,t]-λ[t]) for t in t_mc_start:t_mc_end)
            end
            append!(surplus_stg, ∆t * sum((p_D_val[t]-p_C_val[t])*λ[t] for t in t_mc_start:t_mc_end))
            t_mc_start = (t_mc_end + 1)
        end
    else
        println("No optimal solution available")
    end
    return SW, λ, d_val, p_val, p_C_val, p_D_val, e_val, surplus_gen, surplus_load, surplus_stg
end