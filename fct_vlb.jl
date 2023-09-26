############################################# Market clearing VLB #############################################

function VLB_no_bin(∆t, E, G_df, L_df, E_end, discount)
    
    # Sets
    nb_MI = maximum(G_df.MI) # Number of market intervals
    nb_t = maximum(G_df.t) # Number of time periods per interval
    T = [1:nb_t;] # Time periods for one market interval
    nb_g = maximum(G_df.ID) # Number of generators
    G=[1:nb_g;] # Generators
    nb_l = maximum(L_df.ID) # Number of loads
    L=[1:nb_l;] # Loads

    E_init = [0.0] # Initial level of storage for each value
    S = [0.0] # Value of stored energy
    V = [1:length(S);] # Storage values /!\ Cannot be empty. If empty, set S=[0.0], E_init=[0.0]

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
    push!(entries,"p_C_intra")
    push!(entries,"e_intra")
    push!(entries,"p_D_inter")
    push!(entries,"e_inter")
    # Create the empty dataframe
    df_VLB = DataFrame([ name =>[] for name in entries])

    # Initialize
    SW_tot = 0
    surplus_gen_tot = zeros(length(G))
    surplus_load_tot = zeros(length(L))
    surplus_stg_tot = 0
    i = 1

    for mi in 1:nb_MI
        # Data as arrays
        C, P, U, D = data_all(G_df, G, L_df, L, T, mi)

        # Market clearing
        SW, λ, d, p, p_C_intra, e_intra, p_D_inter, e_inter, surplus_gen, surplus_load, surplus_stg = mc_VLB(∆t, T, L, G, V, U, D, C, P, S, E, E_init, E_end[mi])

        # Results
        SW_tot += SW
        surplus_gen_tot = surplus_gen_tot .+ surplus_gen
        surplus_load_tot = surplus_load_tot .+ surplus_load
        surplus_stg_tot += surplus_stg

        # Save in dataframe 
        for t in 1:nb_t
            row_data = [i, round(λ[t],digits=6)]
            for g in G
                append!(row_data, [C[g,t], round(p[g,t],digits=6), P[g,t]])
            end
            for l in L
                append!(row_data, [U[l,t], round(d[l,t],digits=6), D[l,t]])
            end
            append!(row_data, [round(p_C_intra[t],digits=6), round(e_intra[t],digits=6), round(sum(p_D_inter[v,t] for v in V),digits=6), round(sum(e_inter[v,t] for v in V),digits=6)])
            push!(df_VLB, row_data)
            i+=1
        end

        # Update value of storage
        V, S, E_init = stor_update_new(λ, p_C_intra, p_D_inter, T, V, S, E_init, discount)
    end

    SW_tot_print = round(SW_tot,digits=2)
    println("SW_tot: $SW_tot_print")
    surplus_gen_tot_print = round.(surplus_gen_tot,digits=2)
    println("surplus_gen_tot: $surplus_gen_tot_print")
    surplus_gen_tot_sum = sum(surplus_gen_tot_print)
    println("surplus_gen_sum_tot: $surplus_gen_tot_sum")
    surplus_load_tot_print = round.(surplus_load_tot,digits=2)
    println("surplus_load_tot: $surplus_load_tot_print")
    surplus_stg_tot_print = round(surplus_stg_tot,digits=2)
    println("surplus_stg_tot: $surplus_stg_tot_print")

    println("\nIn the inter-storage at the end of the test period: ")
    println("S: $S")
    println("E_init: $E_init")

    return df_VLB
end