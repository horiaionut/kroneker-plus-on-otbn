import math

def _egcd(a, b):
    if a == 0:
        return (b, 0, 1)
    else:
        g, y, x = _egcd(b % a, a)
        return (g, x - (b // a) * y, y)

def _modinv(a, m):
    g, x, y = _egcd(a, m)
    if g != 1:
        raise Exception('modular inverse does not exist')
    else:
        return x % m

def bit_reverse(v):
    w = int(math.log2(len(v)))
    
    for i in range(len(v)):
         b = '{:0{width}b}'.format(i, width=w)
         j = int(b[::-1], 2)

         if i < j:
               v[i], v[j] = v[j], v[i]

    return v