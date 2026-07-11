# Programa de teste SIMD (init por broadcast; v0 = [0,0,0,0])
    vaddi v1, v0, 5     # v1 = [5,5,5,5]
    vaddi v2, v0, 3     # v2 = [3,3,3,3]
    vadd  v3, v1, v2    # v3 = [8,8,8,8]
    vsub  v4, v1, v2    # v4 = [2,2,2,2]
    vslli v5, v1, 2     # v5 = [20,20,20,20]
    vsrli v6, v1, 1     # v6 = [2,2,2,2]
    vsll  v7, v1, v2    # v7 = [40,40,40,40]  (5 << 3)
    jal   x0, 0         # loop (parada observavel)
