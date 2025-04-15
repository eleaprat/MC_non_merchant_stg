############################################# Ideal Market Clearing #############################################

function perfect(∆t, E, E_0, η_C, η_D, P_C, P_D, E_final, G_df, L_df)

    # Sets
    nb_MC = maximum(G_df.MC) # Number of market clearings
    nb_t = maximum(G_df.t) # Number of time periods per market clearing
    T = [1:nb_t;] # Time periods for one market clearing
    nb_t_tot = nb_MC * nb_t 
    T_all = [1:nb_t_tot;] # Time periods for the whole test period
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
    df_MCP = DataFrame([ name =>[] for name in entries])

    # Convert data to arrays
    C, P, U, D = data_all(G_df, G, L_df, L, T, [1:nb_MC;])

    # Market clearing 
    SW, λ, d, p, p_C, p_D, e, surplus_gen, surplus_load, surplus_stg = market_clearing_all(T_all, L, G, U, D, C, P, E, E_0, η_C, η_D, P_C, P_D, E_final, 0, nb_t, ∆t)

    # Calculate total surplus over the test period for each generator and for each load
    surplus_gen_tot = zeros(length(G))
    surplus_load_tot = zeros(length(L))
    for mc in 1:nb_MC
        surplus_gen_tot = surplus_gen_tot .+ surplus_gen[:,mc]
        surplus_load_tot = surplus_load_tot .+ surplus_load[:,mc]
    end

    SW_tot = sum(SW) # Total social welfare over the test period
    surplus_stg_tot = sum(surplus_stg) # Total surplus for the storage over the test period

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

    # Save in dataframe 
    for t in T_all
        row_data = [t, round(λ[t],digits=6)]
        for g in G
            append!(row_data, [C[g,t], round(p[g,t],digits=6), P[g,t]])
        end
        for l in L
            append!(row_data, [U[l,t], round(d[l,t],digits=6), D[l,t]])
        end
        append!(row_data, [round(p_C[t],digits=6), round(p_D[t],digits=6), round(e[t],digits=6)])
        push!(df_MCP, row_data)
    end

    return df_MCP
end
