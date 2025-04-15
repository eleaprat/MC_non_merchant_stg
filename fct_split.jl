############################################# Market clearing split #############################################

function split(∆t, E, E_0, η_C, η_D, P_C, P_D, G_df, L_df, E_end, S_end)

    # Sets
    nb_MC = maximum(G_df.MC) # Number of market intervals
    nb_t = maximum(G_df.t) # Number of time periods per interval
    T = [1:nb_t;] # Time periods for one market interval
    nb_g = maximum(G_df.ID) # Number of generators
    G=[1:nb_g;] # Generators
    nb_l = maximum(L_df.ID) # Number of loads
    L=[1:nb_l;] # Loads

    # DataFrame for the results
    # Preparing the dataframe for the results by naming the columns
    entries = ["Time","Market_Price"]
    for g in G
        push!(entries,"C$g")
        push!(entries,"p$g")
        push!(entries,"P$g")
    end
    for l in L
        push!(entries,"U$l")
        push!(entries,"d$l")
        push!(entries,"D$l")
    end
    push!(entries,"p_C")
    push!(entries,"p_D")
    push!(entries,"e")
    # Create the empty dataframe
    df_MCS = DataFrame([ name =>[] for name in entries])

    # Initialize
    E_start = E_0 # Storage level
    SW_tot = 0 # Social welfare
    surplus_gen_tot = zeros(length(G)) # Surplus generators
    surplus_load_tot = zeros(length(L)) # Surplus loads
    surplus_stg_tot = 0 # Surplus storage
    i = 1

    for mc in 1:nb_MC # For each market clearing
        # Data as arrays
        C, P, U, D = data_all(G_df, G, L_df, L, T, mc)

        # Market clearing
        SW, λ, d, p, p_C, p_D, e, surplus_gen, surplus_load, surplus_stg = market_clearing_all(T, L, G, U, D, C, P, E, E_start, η_C, η_D, P_C, P_D, E_end[mc], S_end[mc], nb_t, ∆t)
        
        # Results
        SW_tot += SW[1]
        surplus_gen_tot = surplus_gen_tot .+ surplus_gen[:,1]
        surplus_load_tot = surplus_load_tot .+ surplus_load[:,1]
        surplus_stg_tot += surplus_stg[1]

        # Save in dataframe 
        for t in 1:nb_t
            row_data = [i, round(λ[t],digits=6)]
            for g in G
                append!(row_data, [C[g,t], round(p[g,t],digits=6), P[g,t]])
            end
            for l in L
                append!(row_data, [U[l,t], round(d[l,t],digits=6), D[l,t]])
            end
            append!(row_data, [round(p_C[t],digits=6), round(p_D[t],digits=6), round(e[t],digits=6)])
            push!(df_MCS, row_data)
            i+=1
        end

        E_start = E_end[mc]
    end

    SW_tot_print = round(SW_tot,digits=5)
    println("SW_tot: $SW_tot_print")
    surplus_gen_tot_print = round.(surplus_gen_tot,digits=5)
    println("surplus_gen_tot: $surplus_gen_tot_print")
    surplus_gen_tot_sum = sum(surplus_gen_tot_print)
    println("surplus_gen_sum_tot: $surplus_gen_tot_sum")
    surplus_load_tot_print = round.(surplus_load_tot,digits=5)
    println("surplus_load_tot: $surplus_load_tot_print")
    surplus_stg_tot_print = round(surplus_stg_tot,digits=5)
    println("surplus_stg_tot: $surplus_stg_tot_print")

    return df_MCS
end