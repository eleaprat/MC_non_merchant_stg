function data_all(G_df, G, L_df, L, T, MCs)
    
    C = zeros(length(G), length(MCs)*length(T)) # Generation costs
    P = zeros(length(G), length(MCs)*length(T)) # Generation
    U = zeros(length(L), length(MCs)*length(T)) # Loads utility
    D = zeros(length(L), length(MCs)*length(T)) # Demand

    g_df = groupby(G_df, [:MC, :t, :ID]); # Group by time and generator

    for g in G
        i = 1
        for mc in MCs
            for t in T
                C[g,i] = g_df[(mc,t,g)][1,"cost"]
                P[g,i] = g_df[(mc,t,g)][1,"max"]
                i += 1
            end
        end
    end
    
    l_df = groupby(L_df, [:MC, :t, :ID]); # Group by time and load

    for l in L
        i = 1
        for mc in MCs
            for t in T
                U[l,i] = l_df[(mc,t,l)][1,"utility"]
                D[l,i] = l_df[(mc,t,l)][1,"max"]
                i += 1
            end
        end
    end
    return C, P, U, D
end