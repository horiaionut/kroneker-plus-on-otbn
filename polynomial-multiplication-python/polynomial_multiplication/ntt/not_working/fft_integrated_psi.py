from .util import bit_reverse, _modinv

def _forward(poly, t, roots_bit_reversed, kron_mod):
    m = 1
    k = t >> 1
    w = [poly[i] for i in range(t)]

    while m < t:
        for i in range(m):
            j1 = 2 * i * k
            j2 = j1 + k - 1
            psi = roots_bit_reversed[i + m]

            for j in range(j1, j2+1, 1):
                u = w[j]
                v = w[j + k] * psi % kron_mod
                w[j] = (u + v) % kron_mod
                w[j + k] = (u - v) % kron_mod

        m = 2 * m
        k = k >> 1

    return w

def _backward(poly, t, inv_roots_bit_reversed, kron_mod):
    k = 1
    m = t >> 1
    w = [poly[i] for i in range(t)]

    while m >= 1:
        for i in range(m):
            j1 = 2 * i * k
            j2 = j1 + k - 1
            psi = inv_roots_bit_reversed[i + m]

            for j in range(j1, j2 + 1, 1):
                u = w[j]
                v = w[j + k]
                w[j] = (u + v) % kron_mod
                w[j + k] = ((u - v) * psi) % kron_mod

        k = k << 1
        m = m >> 1

    inv_poly_degree = _modinv(t, kron_mod)
    for i in range(t):
        w[i] = (w[i] * inv_poly_degree) % kron_mod
    
    return w

def forward(nusskron, n, l, t, mod):

    root_2t = int((2**(l*n//(t**2))) % mod)

    bit_reversed_powers = bit_reverse([i for i in range(t)])

    roots = [root_2t ** i % mod for i in bit_reversed_powers]

    return _forward(nusskron, t, roots, mod)


def backward(kplus, n, l, t, mod):

    root_2t = int((2**(l*n//(t**2))) % mod)
    root_2t_inv = _modinv(root_2t, mod)

    bit_reversed_powers = bit_reverse([i for i in range(t)])

    # roots_inv = [root ** (2*t - i) % mod for i in bit_reversed_powers]
    roots_inv = [root_2t_inv ** i % mod for i in bit_reversed_powers]

    return _backward(kplus, t, roots_inv, mod)