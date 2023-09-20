from .util import _modinv, bit_reverse

def forward(poly, n, l, t, mod):
    root_t = int((2**(2*l*n//(t**2))) % mod)
    
    f = [poly[i] for i in range(t)]
    
    m = 2
    while m <= t:
        d = t // m
        root_m = (root_t ** d) % mod 
        w = bit_reverse([root_m ** i % mod for i in range(m // 2)])

        for i in range(m // 2):
            for k in range(0, d):
                p = i * (2 * d) + k
                u = f[p]
                v = w[i] * f[p + d] % mod

                f[p] = (u + v) % mod
                f[p + d] = (u - v) % mod
        m *= 2

    return f


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