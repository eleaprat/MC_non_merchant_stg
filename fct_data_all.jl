function data_all(G_df, G, L_df, L, T, MIs)
    
    C = zeros(length(G), length(MIs)*length(T)) # Generation costs
    P = zeros(length(G), length(MIs)*length(T)) # Generation
    U = zeros(length(L), length(MIs)*length(T)) # Loads utility
    D = zeros(length(L), length(MIs)*length(T)) # Demand

    g_df = groupby(G_df, [:MI, :t, :ID]); # Group by time and generator

    for g in G
        i = 1
        for mi in MIs
            for t in T
                C[g,i] = g_df[(mi,t,g)][1,"cost"]
                P[g,i] = g_df[(mi,t,g)][1,"max"]
                i += 1
            end
        end
    end
    
    l_df = groupby(L_df, [:MI, :t, :ID]); # Group by time and loqd

    for l in L
        i = 1
        for mi in MIs
            for t in T
                U[l,i] = l_df[(mi,t,l)][1,"utility"]
                D[l,i] = l_df[(mi,t,l)][1,"max"]
                i += 1
            end
        end
    end
    return C, P, U, D
end