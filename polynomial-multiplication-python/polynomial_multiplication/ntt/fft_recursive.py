from .util import _modinv


def _forward(v, root_t, mod, idxs):
    t = len(v)

    if t == 1:
        return v
    
    w = 1
    v_even = _forward(v[::2], root_t ** 2 % mod, mod, idxs[::2])
    v_odd  = _forward(v[1::2], root_t ** 2 % mod, mod, idxs[1::2])
    
    # print(t)
    # print(idxs)

    res = [0] * t
    for k in range(t // 2):
        tmp = v_odd[k] * w
        res[k] = (v_even[k] + tmp) % mod
        res[k + (t // 2)] = (v_even[k] - tmp) % mod

        # print('p1, p2, w', k, k + (t // 2), w)
        # print(res)

        w = w * root_t % mod

    # print('before')
    # print(v_even)
    # print(v_odd)
    # print('after', res)
    # print()

    return res


def _backward(v, inv_root_t, mod):
    t = len(v)

    if t == 1:
        return v
    
    w = 1
    v_even = _backward(v[::2], inv_root_t ** 2 % mod, mod)
    v_odd  = _backward(v[1::2], inv_root_t ** 2 % mod, mod)
    
    res = [0] * t
    for k in range(t // 2):
        tmp = v_odd[k] * w % mod
        res[k] = (v_even[k] + tmp) % mod
        res[k + t // 2] = (v_even[k] - tmp) % mod
        w = w * inv_root_t % mod

    return res


def forward(v, n, l, t, mod):
    root_t = int((2**(2*l*n//(t**2))) % mod)
    return _forward(v, root_t, mod, list(range(t)))

def backward(v, n, l, t, mod):
    root_t = int((2**(2*l*n//(t**2))) % mod)
    inv_root_t = _modinv(root_t, mod)

    res = _backward(v, inv_root_t, mod)
    inv_t = _modinv(t, mod)
    
    return [(k * inv_t) % mod for k in res]