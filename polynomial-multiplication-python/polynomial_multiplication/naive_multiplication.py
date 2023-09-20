def naive_multiplication(polynomial1, polynomial2, n, q):
    '''
    Performs multiplication modulo X^n + 1
    Expects polynomial1 and polynomial2 to have degree n.
    '''

    res = [0] * n

    for i in range(n):
        for j in range(0, n-i):
            res[i+j] += (polynomial1[i] * polynomial2[j])

    for j in range(1, n):
        for i in range(n-j, n):
            res[i+j-n] -= (polynomial1[i] * polynomial2[j])

    for i in range(n):
        res[i] = res[i] % q
    
    return res