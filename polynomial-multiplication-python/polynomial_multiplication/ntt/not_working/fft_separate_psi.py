from .util import _modinv, bit_reverse
from .fft_recursive import forward as _forward, backward as _backward

def forward(v, n, l, t, mod):
    root_2t = int((2**(l*n//(t**2))) % mod)
    
    return _forward([(v[i] * pow(root_2t, i, mod)) % mod for i in range(t)], n ,l, t, mod)


def backward(v, n, l, t, mod):

    root_2t = int((2**(l*n//(t**2))) % mod)
    root_2t_inv = _modinv(root_2t, mod)

    tmp = _backward(v, n ,l, t, mod)

    return [(tmp[i] * pow(root_2t_inv, i, mod)) % mod for i in range(t)]