.section .text

.section .text.start

  /*
    Modulo reduction of a 64 bit number via reciprocal multiplication
    Following: https://homepage.divms.uiowa.edu/%7Ejones/bcd/divide.html
    
    Compute n - q * ((n * (1/q << 86)) >> 86)

    In fixed-point representation:
    1/q = 
    1.1932580443192743e-07 =
    .0000000000000000000000100000000010000000000111000000011000000001010010000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 (256 bits)

    1/q << (64 + 22 = 86) =
    1000000000100000000001110000000110000000010100100001000000000000 (64 bits)
  */

  /* w0 = 1/q << 86 */
  la x2, one_over_q
  bn.lid x0, 0(x2)

  /* w1 = n */
  la x2, n
  li x3, 1
  bn.lid x3, 0(x2)

  /* w5 = (n * (1/q << 86)) >> 86 */
  bn.mulqacc.so.z w2.L, w0.0, w1.0, 0
  bn.rshi w5, w31, w2 >> 86

  /* w3 = q = 2 ^ 23 - 2 ^ 13 + 1 */
  bn.addi w3, w3, 1023 /* 1111111111 */
  bn.rshi w3, w3, w31 >> 243 /* 0...0 11111111110000000000000 */
  bn.addi w3, w3, 1 /* q = 11111111110000000000001 */

  /* only the lowest 64 bits of w2 can be different than 0 */

  /* w4 = n - q * w2 */
  bn.mulqacc.so.z w4.L, w5.0, w3.0, 0
  bn.sub w4, w1, w4

  ecall


.section .data

one_over_q:
  .quad 0x8020070180521000
  .quad 0x0
  .quad 0x0
  .quad 0x0

n:
  .quad 0x00000002ea02f00c
  .quad 0x0
  .quad 0x0
  .quad 0x0