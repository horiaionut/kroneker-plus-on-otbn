from .util import _modinv

def forward(nusskron, n, l, t, mod):
    # evaluate at t-th roots of unity
    root = int((2**(2*l*n//(t**2))) % mod)
    # print("root: ", root)
    kplus = [0 for _ in range(t)]
    for i in range(t):
        for j in range(t): 
            kplus[i] = (kplus[i] + nusskron[j] * pow(int(root), int(i*j), int(mod))) % mod

    return kplus

def backward(kplus, n, l, t, mod):
    # evaluate at inverse t-th roots of unity and divide by t
    root = int((2**(2*l*n//(t**2))) % mod)
    res_nusskron = [0 for _ in range(t)]
    invroot = _modinv(root, mod)
    invt = _modinv(t, mod)

    for i in range(t):
        for j in range(t):
            res_nusskron[i] = (res_nusskron[i] + kplus[j] * pow(int(invroot), int(i*j), int(mod))) % mod
        res_nusskron[i] = (res_nusskron[i] * invt) % mod

    return res_nusskron