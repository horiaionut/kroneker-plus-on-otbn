from .ntt import _modinv

def print_numbers_in_hex(numbers, mod, number_of_digits=None):
    for number in numbers:
        if number_of_digits != None:
            print(f"{number:#0{number_of_digits}x}")
        else:
            print(hex(number % mod))

def kroneker_plus(a_poly, b_poly, l, t, q, forward_ntt, backward_ntt):
    n = len(a_poly)
    r = int(n//t)
    mod = int((2**(l*n//t)) + 1)
    # print("mod: ", mod)
    a_nussmatrix = [[0 for _ in range(r)] for _ in range(t)]
    b_nussmatrix = [[0 for _ in range(r)] for _ in range(t)]

    # put polynomials in the nussbaumer form
    for i in range(t):
        for j in range(r):
            a_nussmatrix[i][j] = a_poly[t*j+i]
            b_nussmatrix[i][j] = b_poly[t*j+i]
    # print("Nussbaumer Form:")
    # print(a_nussmatrix)
    # print(b_nussmatrix)

    # pack nussbaumer polynomials into Kronecker from with Y=2^l
    a_nusskron = [0 for _ in range(t)]
    b_nusskron = [0 for _ in range(t)]
    for i in range(t):
        for j in range(r):
            a_nusskron[i] += ((a_nussmatrix[i][j] * pow(2, int(l*j), mod)) % mod)
            b_nusskron[i] += ((b_nussmatrix[i][j] * pow(2, int(l*j), mod)) % mod)

        a_nusskron[i] %= mod
        b_nusskron[i] %= mod

    # # print("evaluated nussbaumer polynomials")
    # print_numbers_in_hex(a_nusskron, mod)
    print('a_nusskron', a_nusskron)
    # print('b_nusskron', b_nusskron)

    # apply weight factors
    weight = int((2**(l//t)) % mod)
    for i in range(t):
        a_nusskron[i] = (a_nusskron[i] * weight**(i)) % mod
        b_nusskron[i] = (b_nusskron[i] * weight**(i)) % mod

    # print('a_nusskron', a_nusskron)
    # print('b_nusskron', b_nusskron)

    a_kplus = forward_ntt(a_nusskron, n, l, t, mod)
    b_kplus = forward_ntt(b_nusskron, n, l, t, mod)

    # print("a_kplus:")
    print('polynomial 1 ntt:', a_kplus)
    # print("b_kplus:")
    print('polynomial 2 ntt:', b_kplus)

    # pointwise multiplication
    res_kplus = [0 for _ in range(t)]
    
    for i in range(t):
        res_kplus[i] = (a_kplus[i] * b_kplus[i]) % mod

    # print("pointwise result")
    # print(res_kplus)

    res_nusskron = backward_ntt(res_kplus, n, l, t, mod)

    # print('resultant polynomial inv_ntt:', res_nusskron)

    # undo weight factors
    invweight = _modinv(weight, mod)
    for i in range(t):
        res_nusskron[i] = (res_nusskron[i] * pow(int(invweight), int(i), int(mod))) % mod

    print("backtransformed: ", res_nusskron)

    res_nussmatrix = [[0 for _ in range(r)] for _ in range(t)]

    # unpack nussbaumer polynomials from kronecker form
    for i in range(t):
        packed = res_nusskron[i]
        for j in range(r):
            unpacked = packed % (2**l)
            packed = (packed - unpacked) // (2**l)
            if unpacked > (2**(l-1)):
                unpacked -= (2**l)
                packed += 1
            res_nussmatrix[i][j] = unpacked

        #res_nussmatrix[i][r-1] -= packed
        res_nussmatrix[i][0] -= packed
        # res_nussmatrix[i][0] %= q

    # print(res_nussmatrix)

    # reorder result from nussbaumer form to polynomial
    res = [0 for _ in range(n)]
    for i in range(t):
        for j in range(r):
            res[int(i+t*j)] = res_nussmatrix[i][j] % q

    # print("res:")
    # print(res)

    return res
    # return Poly(n, poly=res, poly_reduce=a_poly.get_poly_reduction(), mod=a_poly.get_modulus())