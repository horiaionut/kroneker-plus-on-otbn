from .util import _modinv

def forward(poly, n, l, t, mod):
    root_t = int((2**(2*l*n//(t**2))) % mod)
    
    m = 1
    k = t >> 1
    p = [poly[i] for i in range(t)]

    while m < t:
        root_2m = (root_t ** ((t // m) // 2)) % mod 
        w = 1

        for i in range(m):
            j1 = 2 * i * k
            j2 = j1 + k - 1

            for j in range(j1, j2+1, 1):
                u        = p[j]
                v        = p[j + k] * w % mod
                p[j]     = (u + v) % mod
                p[j + k] = (u - v) % mod

                print('m, i, j, w:', m, i, j, w)
                print('p1, p2', j, j + k)
                print(p)

            w = w * root_2m % mod

        m = 2 * m
        k = k >> 1

    return p


def backward(poly, n, l, t, mod):
    root_t = int((2**(2*l*n//(t**2))) % mod)
    inv_root_t = _modinv(root_t, mod)

    k = 1
    m = t >> 1
    p = [poly[i] for i in range(t)]

    while m >= 1:
        w = 1
        
        for i in range(m):
            j1 = 2 * i * k
            j2 = j1 + k - 1

            for j in range(j1, j2 + 1, 1):
                u = p[j]
                v = p[j + k]
                p[j] = (u + v) % mod
                p[j + k] = (u - v) * w % mod

            w = w * inv_root_t % mod

        k = k << 1
        m = m >> 1

    inv_poly_degree = _modinv(t, mod)
    for i in range(t):
        p[i] = (p[i] * inv_poly_degree) % mod
    
    return p


    # k = 1
    # m = t >> 1
    # p = [poly[i] for i in range(t)]

    # while m >= 1:
    #     inv_root_t_over_m = (inv_root_t ** m) % mod
    #     root = 1

    #     for i in range(m):
    #         j1  = 2 * i * k
    #         j2  = j1 + k - 1

    #         for j in range(j1, j2 + 1, 1):
    #             u = p[j]
    #             v = p[j + k]
    #             p[j] = (u + v) % mod
    #             p[j + k] = ((u - v) * root) % mod

    #         root = root * inv_root_t_over_m % mod

    #     k = k << 1
    #     m = m >> 1