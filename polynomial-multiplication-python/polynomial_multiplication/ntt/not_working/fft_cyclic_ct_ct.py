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

            w = w * root_2m % mod

        m = 2 * m
        k = k >> 1

    return p


def backward(poly, n, l, t, mod):
    root_t = int((2**(2*l*n//(t**2))) % mod)
    inv_root_t = _modinv(root_t, mod)

    p = [poly[i] for i in range(t)]

    m = 2
    while m <= t:
        inv_root_m = (inv_root_t ** (t // m)) % mod 
        w = 1

        for j in range(0, m//2):
            for k in range(0, t, m):
                u = p[k + j]
                v = p[k + j + m // 2] * w % mod
                p[k + j] = (u + v) % mod
                p[k + j + (m // 2)] = (u - v) % mod

            w = w * inv_root_m % mod
        m *= 2

    inv_poly_degree = _modinv(t, mod)
    for i in range(t):
        p[i] = (p[i] * inv_poly_degree) % mod
    
    return p