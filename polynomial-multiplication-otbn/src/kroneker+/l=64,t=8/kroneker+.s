/*
  l=64, t=8

  To make the code consistent and easier to follow, the following calling conventions and constants will be used:

  w31 = 0
  w30 parameter to functions that function will not change

  x28 - x31 parameters to functions that function will not change
  x25 - x27 parameters to functions that can be changed by these functions
  x22 - x24 step constants that are set only once per step
  x15 - x21 step temps that function will not change

  functions: utils that are used by multiple steps
  step: the _step
*/

.section .text

utils:
  optimized_mult:
    /*
      Multiplies the number stored in w0 .. w8 with 1 + w31 << (256 * 7) and applies modulo reduction. Stores the result in w0 .. w8

      The input numbers are supposed to be already modulo reduction in order to save steps.

      Assumes:
      w30.3 = contains the 64-bit number to multiply with
    */

    bn.xor w16, w16, w16

    bn.mulqacc.so.z w16.U, w30.3, w0.0, 64 /* add this one */

    /* subtract these ones */

    bn.mulqacc           w30.3, w0.1, 0
    bn.mulqacc.so w17.L, w30.3, w0.2, 64
    bn.mulqacc           w30.3, w0.3, 0
    bn.mulqacc.so w17.U, w30.3, w1.0, 64
    bn.mulqacc           w30.3, w1.1, 0
    bn.mulqacc.so w18.L, w30.3, w1.2, 64
    bn.mulqacc           w30.3, w1.3, 0
    bn.mulqacc.so w18.U, w30.3, w2.0, 64
    bn.mulqacc           w30.3, w2.1, 0
    bn.mulqacc.so w19.L, w30.3, w2.2, 64
    bn.mulqacc           w30.3, w2.3, 0
    bn.mulqacc.so w19.U, w30.3, w3.0, 64
    bn.mulqacc           w30.3, w3.1, 0
    bn.mulqacc.so w20.L, w30.3, w3.2, 64
    bn.mulqacc           w30.3, w3.3, 0
    bn.mulqacc.so w20.U, w30.3, w4.0, 64
    bn.mulqacc           w30.3, w4.1, 0
    bn.mulqacc.so w21.L, w30.3, w4.2, 64
    bn.mulqacc           w30.3, w4.3, 0
    bn.mulqacc.so w21.U, w30.3, w5.0, 64
    bn.mulqacc           w30.3, w5.1, 0
    bn.mulqacc.so w22.L, w30.3, w5.2, 64
    bn.mulqacc           w30.3, w5.3, 0
    bn.mulqacc.so w22.U, w30.3, w6.0, 64
    bn.mulqacc           w30.3, w6.1, 0
    bn.mulqacc.so w23.L, w30.3, w6.2, 64
    bn.mulqacc           w30.3, w6.3, 0
    bn.mulqacc.so w23.U, w30.3, w7.0, 64
    bn.mulqacc           w30.3, w7.1, 0
    bn.mulqacc.so w24.L, w30.3, w7.2, 64
    bn.mulqacc           w30.3, w7.3, 0
    bn.mulqacc.so w24.U, w30.3, w8.0, 64

    bn.sub  w0, w0, w17
    bn.subb w1, w1, w18
    bn.subb w2, w2, w19
    bn.subb w3, w3, w20
    bn.subb w4, w4, w21
    bn.subb w5, w5, w22
    bn.subb w6, w6, w23
    bn.subb w7, w7, w24

    bn.addc w0, w0, w31
    bn.addc w1, w1, w31
    bn.addc w2, w2, w31
    bn.addc w3, w3, w31
    bn.addc w4, w4, w31
    bn.addc w5, w5, w31
    bn.addc w6, w6, w31
    bn.addc w7, w7, w16
    bn.addc w8, w8, w31

    /* as assumed, the numbers are supposed to be inputed in modulo reduced form so w8 is at most 1 => adding a 1 will not overflow the first 64 bits */
    
    ret

  load_number:
    loopi 9, 2
      bn.lid x27++, 0(x26)
      addi x26, x26, 32
    ret 

  load_apply_operation_save:
    addi x8, x26, 0
    li x27, 0
    jal x1, load_number

    jalr x1, x28, 0

    li x27, 0
    addi x26, x8, 0
    jal x1, save_number

    ret

  save_number:
    loopi 9, 2
      bn.sid x27++, 0(x26)
      addi x26, x26, 32
    ret 

  butterfly:

    butterfly_inverse_jloop:
      add x22, x20, x20 /* butterfly jloop step: m * 9 * 256 / 8  */
      jal x1, butterfly_jloop
      ret

    butterfly_jloop:
      loop x21, 16 /* j = jFirst ... jLast */
        
        li  x27, 0        /* starting WDR first number */
        addi x26, x19, 0
        jal x1, load_number

        add x26, x19, x20 /* position of second number */
        jalr x1, x18, 0 /* load second number with appropriate shift and modulo reduce it */

        jal x1, butterfly_addition

        li  x27, 9        /* starting WDR of the result */
        addi x26, x19, 0    /* position to save the result */
        jal x1, save_number

        /* reload second number since it has been changed by the shift and writtten over by the addition */

        add x26, x19, x20 /* position of second number */
        jalr x1, x18, 0 /* load second number with appropriate shift and modulo reduce it */

        jal x1, butterfly_subtraction

        li  x27, 9        /* starting WDR of the result */
        add x26, x19, x20    /* position to save the result */
        jal x1, save_number

        add x19, x19, x22

      ret

    butterfly_second_number_no_shift:
      li  x27, 9
      jal x1, load_number
      ret

    butterfly_subtraction:
      /* 
        Subtracts the number stored in words w9 ... w17 from w0 ... w8 and applies modulo reduction.
        Assumes w31 = 0.
      */

      bn.sub   w9, w0,  w9
      bn.subb w10, w1, w10
      bn.subb w11, w2, w11
      bn.subb w12, w3, w12
      bn.subb w13, w4, w13
      bn.subb w14, w5, w14
      bn.subb w15, w6, w15
      bn.subb w16, w7, w16

      bn.addc  w9,  w9, w17
      bn.addc w10, w10, w31
      bn.addc w11, w11, w31
      bn.addc w12, w12, w31
      bn.addc w13, w13, w31
      bn.addc w14, w14, w31
      bn.addc w15, w15, w31
      bn.addc w16, w16, w31

      jal x1, butterfly_subtract_w8

      ret

    butterfly_addition:
      /* 
        Adds numbers stored in words w9 ... w17 and w0 ... w8 and applies modulo reduction.
        Assumes w31 = 0.
      */

      bn.sub   w9,  w9, w17
      bn.subb w10, w10, w31
      bn.subb w11, w11, w31
      bn.subb w12, w12, w31
      bn.subb w13, w13, w31
      bn.subb w14, w14, w31
      bn.subb w15, w15, w31
      bn.subb w16, w16, w31

      bn.addc  w9,  w9, w0
      bn.addc w10, w10, w1
      bn.addc w11, w11, w2
      bn.addc w12, w12, w3
      bn.addc w13, w13, w4
      bn.addc w14, w14, w5
      bn.addc w15, w15, w6
      bn.addc w16, w16, w7

      jal x1, butterfly_subtract_w8

      ret

    butterfly_subtract_w8:
      /*
        Subtracts w8 as a standalone number from w9 ... w17
      */

      bn.subb  w9,  w9,  w8
      bn.subb w10, w10, w31
      bn.subb w11, w11, w31
      bn.subb w12, w12, w31
      bn.subb w13, w13, w31
      bn.subb w14, w14, w31
      bn.subb w15, w15, w31
      bn.subb w16, w16, w31

      bn.addc  w9,  w9, w31
      bn.addc w10, w10, w31
      bn.addc w11, w11, w31
      bn.addc w12, w12, w31
      bn.addc w13, w13, w31
      bn.addc w14, w14, w31
      bn.addc w15, w15, w31
      bn.addc w16, w16, w31
      bn.addc w17, w31, w31

      ret

    
step1: /* reorder coefficients and snort */
  la     x15, input_polynomial1
  la     x16, intermediate_polynomial1
  jal    x1, _step1
  
  la     x15, input_polynomial2
  la     x16, intermediate_polynomial2
  jal    x1, _step1

  ret

  _step1:
  
    loopi 32, 7 /* for each of the 32 groups of 8 coefficients */
      addi x21, x16, 0 

      loopi 8, 4
        lw x20, 0(x15)
        sw x20, 0(x21)

        addi x15, x15, 4
        addi x21, x21, 288 /* 9 words * 256 bits / 8 to represent in bytes = 288 bytes */

      addi x16, x16, 8 /* 4 bytes for the last added numbers and leave 4 bytes empty to have a coefficient stored on l=64 bits */
    
    ret


step2: /* multiply each polynomial i by X^i */

  /* X = 2^(l/t) = 2^(64 / 8) = 2^8 */

  la     x26, intermediate_polynomial1
  jal    x1, _step2

  la     x26, intermediate_polynomial2
  jal    x1, _step2

  ret

  _step2:

    /* first number is multiplied with by (2^8)^0 = 1 so it doesn't change */
    
    addi x26, x26, 288
    la x28, step2_shift_8
    jal x1, load_apply_operation_save

    la x28, step2_shift_16
    jal x1, load_apply_operation_save

    la x28, step2_shift_24
    jal x1, load_apply_operation_save

    la x28, step2_shift_32
    jal x1, load_apply_operation_save

    la x28, step2_shift_40
    jal x1, load_apply_operation_save

    la x28, step2_shift_48
    jal x1, load_apply_operation_save

    la x28, step2_shift_56
    jal x1, load_apply_operation_save

    ret

  step2_shift_8:

    bn.rshi w8, w8, w7 >> 248
    bn.rshi w7, w7, w6 >> 248
    bn.rshi w6, w6, w5 >> 248
    bn.rshi w5, w5, w4 >> 248
    bn.rshi w4, w4, w3 >> 248
    bn.rshi w3, w3, w2 >> 248
    bn.rshi w2, w2, w1 >> 248
    bn.rshi w1, w1, w0 >> 248
    bn.rshi w0, w0, w31 >> 248

    ret

  
  step2_shift_16:

    bn.rshi w8, w8, w7 >> 240
    bn.rshi w7, w7, w6 >> 240
    bn.rshi w6, w6, w5 >> 240
    bn.rshi w5, w5, w4 >> 240
    bn.rshi w4, w4, w3 >> 240
    bn.rshi w3, w3, w2 >> 240
    bn.rshi w2, w2, w1 >> 240
    bn.rshi w1, w1, w0 >> 240
    bn.rshi w0, w0, w31 >> 240

    ret

  step2_shift_24:

    bn.rshi w8, w8, w7 >> 232
    bn.rshi w7, w7, w6 >> 232
    bn.rshi w6, w6, w5 >> 232
    bn.rshi w5, w5, w4 >> 232
    bn.rshi w4, w4, w3 >> 232
    bn.rshi w3, w3, w2 >> 232
    bn.rshi w2, w2, w1 >> 232
    bn.rshi w1, w1, w0 >> 232
    bn.rshi w0, w0, w31 >> 232

    ret

  step2_shift_32:

    bn.rshi w8, w8, w7 >> 224
    bn.rshi w7, w7, w6 >> 224
    bn.rshi w6, w6, w5 >> 224
    bn.rshi w5, w5, w4 >> 224
    bn.rshi w4, w4, w3 >> 224
    bn.rshi w3, w3, w2 >> 224
    bn.rshi w2, w2, w1 >> 224
    bn.rshi w1, w1, w0 >> 224
    bn.rshi w0, w0, w31 >> 224

    ret

  step2_shift_40:

    bn.rshi w8, w8, w7 >> 216
    bn.rshi w7, w7, w6 >> 216
    bn.rshi w6, w6, w5 >> 216
    bn.rshi w5, w5, w4 >> 216
    bn.rshi w4, w4, w3 >> 216
    bn.rshi w3, w3, w2 >> 216
    bn.rshi w2, w2, w1 >> 216
    bn.rshi w1, w1, w0 >> 216
    bn.rshi w0, w0, w31 >> 216

    ret

  step2_shift_48:

    bn.rshi w8, w8, w7 >> 208
    bn.rshi w7, w7, w6 >> 208
    bn.rshi w6, w6, w5 >> 208
    bn.rshi w5, w5, w4 >> 208
    bn.rshi w4, w4, w3 >> 208
    bn.rshi w3, w3, w2 >> 208
    bn.rshi w2, w2, w1 >> 208
    bn.rshi w1, w1, w0 >> 208
    bn.rshi w0, w0, w31 >> 208

    ret

  step2_shift_56:

    bn.rshi w8, w8, w7 >> 200
    bn.rshi w7, w7, w6 >> 200
    bn.rshi w6, w6, w5 >> 200
    bn.rshi w5, w5, w4 >> 200
    bn.rshi w4, w4, w3 >> 200
    bn.rshi w3, w3, w2 >> 200
    bn.rshi w2, w2, w1 >> 200
    bn.rshi w1, w1, w0 >> 200
    bn.rshi w0, w0, w31 >> 200

    ret


step3: /* forward butterfly */

  li x23, 7
  li x31, 31

  la     x24, intermediate_polynomial1
  jal    x1, _step3

  la     x24, intermediate_polynomial2
  jal    x1, _step3
  
  ret

  _step3: 

    /* w_t = 2^512 = 2 words */

    li x22, 288 /* butterfly jloop step */

    /* m = 2 */

    li x21, 4 /* d = t / m = 4 */
    li x20, 1152 /* d * 9 * 256 / 8 */

      /* i = 0 */

      addi x19, x24, 0 /* starting of the i'th group: x24 + i * 2 * d * 9 * 256 / 8 */
      la  x18, butterfly_second_number_no_shift /* multiply with w_2^i = 1 */
      jal x1, butterfly_jloop

    /* m = 4 */

    li x21, 2 /* d = t / m = 2 */
    li x20, 576

      /* i = 0 */

      addi x19, x24, 0 
      la  x18, butterfly_second_number_no_shift
      jal x1, butterfly_jloop

      /* i = 1 */
    
      addi x19, x24, 1152
      la  x18, step3_second_number_shift_4
      jal x1, butterfly_jloop
      
    
    /* m = 8 */

    li x21, 1 /* d = t/m = 1 */
    li x20, 288

      /* i = 0 */

      addi x19, x24, 0
      la  x18, butterfly_second_number_no_shift
      jal x1, butterfly_jloop

      /* i = 1 */
    
      addi x19, x24, 576
      la  x18, step3_second_number_shift_4
      jal x1, butterfly_jloop

      /* i = 2 */

      addi x19, x24, 1152
      la  x18, step3_second_number_shift_2
      jal x1, butterfly_jloop

      /* i = 3 */
    
      addi x19, x24, 1728
      la  x18, step3_second_number_shift_6
      jal x1, butterfly_jloop

    ret

  
  step3_second_number_shift_2:

    li x27, 11
    jal x1, load_number

    /* modulo reduce */

    bn.sub  w9,  w31, w17
    bn.subb w10, w31, w18
    bn.subb w11, w11, w19
    bn.subb w12, w12, w31
    bn.subb w13, w13, w31
    bn.subb w14, w14, w31
    bn.subb w15, w15, w31
    bn.subb w16, w16, w31

    bn.addc w9,   w9, w31
    bn.addc w10, w10, w31
    bn.addc w11, w11, w31
    bn.addc w12, w12, w31
    bn.addc w13, w13, w31
    bn.addc w14, w14, w31
    bn.addc w15, w15, w31
    bn.addc w16, w16, w31
    bn.addc w17, w31, w31

    ret

  step3_second_number_shift_4:

    li x27, 13
    jal x1, load_number

    /* modulo reduce */

    bn.sub  w9,  w31, w17
    bn.subb w10, w31, w18
    bn.subb w11, w31, w19
    bn.subb w12, w31, w20
    bn.subb w13, w13, w21
    bn.subb w14, w14, w31
    bn.subb w15, w15, w31
    bn.subb w16, w16, w31

    bn.addc w9,   w9, w31
    bn.addc w10, w10, w31
    bn.addc w11, w11, w31
    bn.addc w12, w12, w31
    bn.addc w13, w13, w31
    bn.addc w14, w14, w31
    bn.addc w15, w15, w31
    bn.addc w16, w16, w31
    bn.addc w17, w31, w31

    ret

  
  step3_second_number_shift_6:

    li x27, 15
    jal x1, load_number

    /* modulo reduce */

    bn.sub  w9,  w31, w17
    bn.subb w10, w31, w18
    bn.subb w11, w31, w19
    bn.subb w12, w31, w20
    bn.subb w13, w31, w21
    bn.subb w14, w31, w22
    bn.subb w15, w15, w23
    bn.subb w16, w16, w31

    bn.addc w9,   w9, w31
    bn.addc w10, w10, w31
    bn.addc w11, w11, w31
    bn.addc w12, w12, w31
    bn.addc w13, w13, w31
    bn.addc w14, w14, w31
    bn.addc w15, w15, w31
    bn.addc w16, w16, w31
    bn.addc w17, w31, w31

    ret


step4: /* 8 multiplications of 2 numbers of 2048-bits */
  la     x24, intermediate_polynomial1
  la     x23, intermediate_polynomial2

  bn.xor  w31, w31, w31

  loopi 8, 10
    li  x27, 0
    ori x26, x24, 0
    jal x1, load_number

    ori x26, x23, 0
    jal x1, load_number

    jal x1, step4_multiplication

    ori x26, x24, 0
    jal x1, save_number /* w18 .. w26 */

    addi x24, x24, 288
    addi x23, x23, 288

  ret

  step4_multiplication:

    bn.mulqacc.z         w0.0, w9.0, 0

    bn.mulqacc           w0.0, w9.1, 64
    bn.mulqacc.so w18.L, w0.1, w9.0, 64

    bn.mulqacc           w0.0, w9.2, 0
    bn.mulqacc           w0.1, w9.1, 0
    bn.mulqacc           w0.2, w9.0, 0

    bn.mulqacc           w0.0, w9.3, 64
    bn.mulqacc           w0.1, w9.2, 64
    bn.mulqacc           w0.2, w9.1, 64
    bn.mulqacc.so w18.U, w0.3, w9.0, 64

    bn.mulqacc           w0.0, w10.0, 0
    bn.mulqacc           w0.1, w9.3, 0
    bn.mulqacc           w0.2, w9.2, 0
    bn.mulqacc           w0.3, w9.1, 0
    bn.mulqacc           w1.0, w9.0, 0

    bn.mulqacc           w0.0, w10.1, 64
    bn.mulqacc           w0.1, w10.0, 64
    bn.mulqacc           w0.2, w9.3, 64
    bn.mulqacc           w0.3, w9.2, 64
    bn.mulqacc           w1.0, w9.1, 64
    bn.mulqacc.so w19.L, w1.1, w9.0, 64

    bn.mulqacc           w0.0, w10.2, 0
    bn.mulqacc           w0.1, w10.1, 0
    bn.mulqacc           w0.2, w10.0, 0
    bn.mulqacc           w0.3, w9.3, 0
    bn.mulqacc           w1.0, w9.2, 0
    bn.mulqacc           w1.1, w9.1, 0
    bn.mulqacc           w1.2, w9.0, 0

    bn.mulqacc           w0.0, w10.3, 64
    bn.mulqacc           w0.1, w10.2, 64
    bn.mulqacc           w0.2, w10.1, 64
    bn.mulqacc           w0.3, w10.0, 64
    bn.mulqacc           w1.0, w9.3, 64
    bn.mulqacc           w1.1, w9.2, 64
    bn.mulqacc           w1.2, w9.1, 64
    bn.mulqacc.so w19.U, w1.3, w9.0, 64

    bn.mulqacc           w0.0, w11.0, 0
    bn.mulqacc           w0.1, w10.3, 0
    bn.mulqacc           w0.2, w10.2, 0
    bn.mulqacc           w0.3, w10.1, 0
    bn.mulqacc           w1.0, w10.0, 0
    bn.mulqacc           w1.1, w9.3, 0
    bn.mulqacc           w1.2, w9.2, 0
    bn.mulqacc           w1.3, w9.1, 0
    bn.mulqacc           w2.0, w9.0, 0

    bn.mulqacc           w0.0, w11.1, 64
    bn.mulqacc           w0.1, w11.0, 64
    bn.mulqacc           w0.2, w10.3, 64
    bn.mulqacc           w0.3, w10.2, 64
    bn.mulqacc           w1.0, w10.1, 64
    bn.mulqacc           w1.1, w10.0, 64
    bn.mulqacc           w1.2, w9.3, 64
    bn.mulqacc           w1.3, w9.2, 64
    bn.mulqacc           w2.0, w9.1, 64
    bn.mulqacc.so w20.L, w2.1, w9.0, 64

    bn.mulqacc           w0.0, w11.2, 0
    bn.mulqacc           w0.1, w11.1, 0
    bn.mulqacc           w0.2, w11.0, 0
    bn.mulqacc           w0.3, w10.3, 0
    bn.mulqacc           w1.0, w10.2, 0
    bn.mulqacc           w1.1, w10.1, 0
    bn.mulqacc           w1.2, w10.0, 0
    bn.mulqacc           w1.3, w9.3, 0
    bn.mulqacc           w2.0, w9.2, 0
    bn.mulqacc           w2.1, w9.1, 0
    bn.mulqacc           w2.2, w9.0, 0

    bn.mulqacc           w0.0, w11.3, 64
    bn.mulqacc           w0.1, w11.2, 64
    bn.mulqacc           w0.2, w11.1, 64
    bn.mulqacc           w0.3, w11.0, 64
    bn.mulqacc           w1.0, w10.3, 64
    bn.mulqacc           w1.1, w10.2, 64
    bn.mulqacc           w1.2, w10.1, 64
    bn.mulqacc           w1.3, w10.0, 64
    bn.mulqacc           w2.0, w9.3, 64
    bn.mulqacc           w2.1, w9.2, 64
    bn.mulqacc           w2.2, w9.1, 64
    bn.mulqacc.so w20.U, w2.3, w9.0, 64

    bn.mulqacc           w0.0, w12.0, 0
    bn.mulqacc           w0.1, w11.3, 0
    bn.mulqacc           w0.2, w11.2, 0
    bn.mulqacc           w0.3, w11.1, 0
    bn.mulqacc           w1.0, w11.0, 0
    bn.mulqacc           w1.1, w10.3, 0
    bn.mulqacc           w1.2, w10.2, 0
    bn.mulqacc           w1.3, w10.1, 0
    bn.mulqacc           w2.0, w10.0, 0
    bn.mulqacc           w2.1, w9.3, 0
    bn.mulqacc           w2.2, w9.2, 0
    bn.mulqacc           w2.3, w9.1, 0
    bn.mulqacc           w3.0, w9.0, 0

    bn.mulqacc           w0.0, w12.1, 64
    bn.mulqacc           w0.1, w12.0, 64
    bn.mulqacc           w0.2, w11.3, 64
    bn.mulqacc           w0.3, w11.2, 64
    bn.mulqacc           w1.0, w11.1, 64
    bn.mulqacc           w1.1, w11.0, 64
    bn.mulqacc           w1.2, w10.3, 64
    bn.mulqacc           w1.3, w10.2, 64
    bn.mulqacc           w2.0, w10.1, 64
    bn.mulqacc           w2.1, w10.0, 64
    bn.mulqacc           w2.2, w9.3, 64
    bn.mulqacc           w2.3, w9.2, 64
    bn.mulqacc           w3.0, w9.1, 64
    bn.mulqacc.so w21.L, w3.1, w9.0, 64

    bn.mulqacc           w0.0, w12.2, 0
    bn.mulqacc           w0.1, w12.1, 0
    bn.mulqacc           w0.2, w12.0, 0
    bn.mulqacc           w0.3, w11.3, 0
    bn.mulqacc           w1.0, w11.2, 0
    bn.mulqacc           w1.1, w11.1, 0
    bn.mulqacc           w1.2, w11.0, 0
    bn.mulqacc           w1.3, w10.3, 0
    bn.mulqacc           w2.0, w10.2, 0
    bn.mulqacc           w2.1, w10.1, 0
    bn.mulqacc           w2.2, w10.0, 0
    bn.mulqacc           w2.3, w9.3, 0
    bn.mulqacc           w3.0, w9.2, 0
    bn.mulqacc           w3.1, w9.1, 0
    bn.mulqacc           w3.2, w9.0, 0

    bn.mulqacc           w0.0, w12.3, 64
    bn.mulqacc           w0.1, w12.2, 64
    bn.mulqacc           w0.2, w12.1, 64
    bn.mulqacc           w0.3, w12.0, 64
    bn.mulqacc           w1.0, w11.3, 64
    bn.mulqacc           w1.1, w11.2, 64
    bn.mulqacc           w1.2, w11.1, 64
    bn.mulqacc           w1.3, w11.0, 64
    bn.mulqacc           w2.0, w10.3, 64
    bn.mulqacc           w2.1, w10.2, 64
    bn.mulqacc           w2.2, w10.1, 64
    bn.mulqacc           w2.3, w10.0, 64
    bn.mulqacc           w3.0, w9.3, 64
    bn.mulqacc           w3.1, w9.2, 64
    bn.mulqacc           w3.2, w9.1, 64
    bn.mulqacc.so w21.U, w3.3, w9.0, 64

    bn.mulqacc           w0.0, w13.0, 0
    bn.mulqacc           w0.1, w12.3, 0
    bn.mulqacc           w0.2, w12.2, 0
    bn.mulqacc           w0.3, w12.1, 0
    bn.mulqacc           w1.0, w12.0, 0
    bn.mulqacc           w1.1, w11.3, 0
    bn.mulqacc           w1.2, w11.2, 0
    bn.mulqacc           w1.3, w11.1, 0
    bn.mulqacc           w2.0, w11.0, 0
    bn.mulqacc           w2.1, w10.3, 0
    bn.mulqacc           w2.2, w10.2, 0
    bn.mulqacc           w2.3, w10.1, 0
    bn.mulqacc           w3.0, w10.0, 0
    bn.mulqacc           w3.1, w9.3, 0
    bn.mulqacc           w3.2, w9.2, 0
    bn.mulqacc           w3.3, w9.1, 0
    bn.mulqacc           w4.0, w9.0, 0

    bn.mulqacc           w0.0, w13.1, 64
    bn.mulqacc           w0.1, w13.0, 64
    bn.mulqacc           w0.2, w12.3, 64
    bn.mulqacc           w0.3, w12.2, 64
    bn.mulqacc           w1.0, w12.1, 64
    bn.mulqacc           w1.1, w12.0, 64
    bn.mulqacc           w1.2, w11.3, 64
    bn.mulqacc           w1.3, w11.2, 64
    bn.mulqacc           w2.0, w11.1, 64
    bn.mulqacc           w2.1, w11.0, 64
    bn.mulqacc           w2.2, w10.3, 64
    bn.mulqacc           w2.3, w10.2, 64
    bn.mulqacc           w3.0, w10.1, 64
    bn.mulqacc           w3.1, w10.0, 64
    bn.mulqacc           w3.2, w9.3, 64
    bn.mulqacc           w3.3, w9.2, 64
    bn.mulqacc           w4.0, w9.1, 64
    bn.mulqacc.so w22.L, w4.1, w9.0, 64

    bn.mulqacc           w0.0, w13.2, 0
    bn.mulqacc           w0.1, w13.1, 0
    bn.mulqacc           w0.2, w13.0, 0
    bn.mulqacc           w0.3, w12.3, 0
    bn.mulqacc           w1.0, w12.2, 0
    bn.mulqacc           w1.1, w12.1, 0
    bn.mulqacc           w1.2, w12.0, 0
    bn.mulqacc           w1.3, w11.3, 0
    bn.mulqacc           w2.0, w11.2, 0
    bn.mulqacc           w2.1, w11.1, 0
    bn.mulqacc           w2.2, w11.0, 0
    bn.mulqacc           w2.3, w10.3, 0
    bn.mulqacc           w3.0, w10.2, 0
    bn.mulqacc           w3.1, w10.1, 0
    bn.mulqacc           w3.2, w10.0, 0
    bn.mulqacc           w3.3, w9.3, 0
    bn.mulqacc           w4.0, w9.2, 0
    bn.mulqacc           w4.1, w9.1, 0
    bn.mulqacc           w4.2, w9.0, 0

    bn.mulqacc           w0.0, w13.3, 64
    bn.mulqacc           w0.1, w13.2, 64
    bn.mulqacc           w0.2, w13.1, 64
    bn.mulqacc           w0.3, w13.0, 64
    bn.mulqacc           w1.0, w12.3, 64
    bn.mulqacc           w1.1, w12.2, 64
    bn.mulqacc           w1.2, w12.1, 64
    bn.mulqacc           w1.3, w12.0, 64
    bn.mulqacc           w2.0, w11.3, 64
    bn.mulqacc           w2.1, w11.2, 64
    bn.mulqacc           w2.2, w11.1, 64
    bn.mulqacc           w2.3, w11.0, 64
    bn.mulqacc           w3.0, w10.3, 64
    bn.mulqacc           w3.1, w10.2, 64
    bn.mulqacc           w3.2, w10.1, 64
    bn.mulqacc           w3.3, w10.0, 64
    bn.mulqacc           w4.0, w9.3, 64
    bn.mulqacc           w4.1, w9.2, 64
    bn.mulqacc           w4.2, w9.1, 64
    bn.mulqacc.so w22.U, w4.3, w9.0, 64

    bn.mulqacc           w0.0, w14.0, 0
    bn.mulqacc           w0.1, w13.3, 0
    bn.mulqacc           w0.2, w13.2, 0
    bn.mulqacc           w0.3, w13.1, 0
    bn.mulqacc           w1.0, w13.0, 0
    bn.mulqacc           w1.1, w12.3, 0
    bn.mulqacc           w1.2, w12.2, 0
    bn.mulqacc           w1.3, w12.1, 0
    bn.mulqacc           w2.0, w12.0, 0
    bn.mulqacc           w2.1, w11.3, 0
    bn.mulqacc           w2.2, w11.2, 0
    bn.mulqacc           w2.3, w11.1, 0
    bn.mulqacc           w3.0, w11.0, 0
    bn.mulqacc           w3.1, w10.3, 0
    bn.mulqacc           w3.2, w10.2, 0
    bn.mulqacc           w3.3, w10.1, 0
    bn.mulqacc           w4.0, w10.0, 0
    bn.mulqacc           w4.1, w9.3, 0
    bn.mulqacc           w4.2, w9.2, 0
    bn.mulqacc           w4.3, w9.1, 0
    bn.mulqacc           w5.0, w9.0, 0

    bn.mulqacc           w0.0, w14.1, 64
    bn.mulqacc           w0.1, w14.0, 64
    bn.mulqacc           w0.2, w13.3, 64
    bn.mulqacc           w0.3, w13.2, 64
    bn.mulqacc           w1.0, w13.1, 64
    bn.mulqacc           w1.1, w13.0, 64
    bn.mulqacc           w1.2, w12.3, 64
    bn.mulqacc           w1.3, w12.2, 64
    bn.mulqacc           w2.0, w12.1, 64
    bn.mulqacc           w2.1, w12.0, 64
    bn.mulqacc           w2.2, w11.3, 64
    bn.mulqacc           w2.3, w11.2, 64
    bn.mulqacc           w3.0, w11.1, 64
    bn.mulqacc           w3.1, w11.0, 64
    bn.mulqacc           w3.2, w10.3, 64
    bn.mulqacc           w3.3, w10.2, 64
    bn.mulqacc           w4.0, w10.1, 64
    bn.mulqacc           w4.1, w10.0, 64
    bn.mulqacc           w4.2, w9.3, 64
    bn.mulqacc           w4.3, w9.2, 64
    bn.mulqacc           w5.0, w9.1, 64
    bn.mulqacc.so w23.L, w5.1, w9.0, 64

    bn.mulqacc           w0.0, w14.2, 0
    bn.mulqacc           w0.1, w14.1, 0
    bn.mulqacc           w0.2, w14.0, 0
    bn.mulqacc           w0.3, w13.3, 0
    bn.mulqacc           w1.0, w13.2, 0
    bn.mulqacc           w1.1, w13.1, 0
    bn.mulqacc           w1.2, w13.0, 0
    bn.mulqacc           w1.3, w12.3, 0
    bn.mulqacc           w2.0, w12.2, 0
    bn.mulqacc           w2.1, w12.1, 0
    bn.mulqacc           w2.2, w12.0, 0
    bn.mulqacc           w2.3, w11.3, 0
    bn.mulqacc           w3.0, w11.2, 0
    bn.mulqacc           w3.1, w11.1, 0
    bn.mulqacc           w3.2, w11.0, 0
    bn.mulqacc           w3.3, w10.3, 0
    bn.mulqacc           w4.0, w10.2, 0
    bn.mulqacc           w4.1, w10.1, 0
    bn.mulqacc           w4.2, w10.0, 0
    bn.mulqacc           w4.3, w9.3, 0
    bn.mulqacc           w5.0, w9.2, 0
    bn.mulqacc           w5.1, w9.1, 0
    bn.mulqacc           w5.2, w9.0, 0

    bn.mulqacc           w0.0, w14.3, 64
    bn.mulqacc           w0.1, w14.2, 64
    bn.mulqacc           w0.2, w14.1, 64
    bn.mulqacc           w0.3, w14.0, 64
    bn.mulqacc           w1.0, w13.3, 64
    bn.mulqacc           w1.1, w13.2, 64
    bn.mulqacc           w1.2, w13.1, 64
    bn.mulqacc           w1.3, w13.0, 64
    bn.mulqacc           w2.0, w12.3, 64
    bn.mulqacc           w2.1, w12.2, 64
    bn.mulqacc           w2.2, w12.1, 64
    bn.mulqacc           w2.3, w12.0, 64
    bn.mulqacc           w3.0, w11.3, 64
    bn.mulqacc           w3.1, w11.2, 64
    bn.mulqacc           w3.2, w11.1, 64
    bn.mulqacc           w3.3, w11.0, 64
    bn.mulqacc           w4.0, w10.3, 64
    bn.mulqacc           w4.1, w10.2, 64
    bn.mulqacc           w4.2, w10.1, 64
    bn.mulqacc           w4.3, w10.0, 64
    bn.mulqacc           w5.0, w9.3, 64
    bn.mulqacc           w5.1, w9.2, 64
    bn.mulqacc           w5.2, w9.1, 64
    bn.mulqacc.so w23.U, w5.3, w9.0, 64

    bn.mulqacc           w0.0, w15.0, 0
    bn.mulqacc           w0.1, w14.3, 0
    bn.mulqacc           w0.2, w14.2, 0
    bn.mulqacc           w0.3, w14.1, 0
    bn.mulqacc           w1.0, w14.0, 0
    bn.mulqacc           w1.1, w13.3, 0
    bn.mulqacc           w1.2, w13.2, 0
    bn.mulqacc           w1.3, w13.1, 0
    bn.mulqacc           w2.0, w13.0, 0
    bn.mulqacc           w2.1, w12.3, 0
    bn.mulqacc           w2.2, w12.2, 0
    bn.mulqacc           w2.3, w12.1, 0
    bn.mulqacc           w3.0, w12.0, 0
    bn.mulqacc           w3.1, w11.3, 0
    bn.mulqacc           w3.2, w11.2, 0
    bn.mulqacc           w3.3, w11.1, 0
    bn.mulqacc           w4.0, w11.0, 0
    bn.mulqacc           w4.1, w10.3, 0
    bn.mulqacc           w4.2, w10.2, 0
    bn.mulqacc           w4.3, w10.1, 0
    bn.mulqacc           w5.0, w10.0, 0
    bn.mulqacc           w5.1, w9.3, 0
    bn.mulqacc           w5.2, w9.2, 0
    bn.mulqacc           w5.3, w9.1, 0
    bn.mulqacc           w6.0, w9.0, 0

    bn.mulqacc           w0.0, w15.1, 64
    bn.mulqacc           w0.1, w15.0, 64
    bn.mulqacc           w0.2, w14.3, 64
    bn.mulqacc           w0.3, w14.2, 64
    bn.mulqacc           w1.0, w14.1, 64
    bn.mulqacc           w1.1, w14.0, 64
    bn.mulqacc           w1.2, w13.3, 64
    bn.mulqacc           w1.3, w13.2, 64
    bn.mulqacc           w2.0, w13.1, 64
    bn.mulqacc           w2.1, w13.0, 64
    bn.mulqacc           w2.2, w12.3, 64
    bn.mulqacc           w2.3, w12.2, 64
    bn.mulqacc           w3.0, w12.1, 64
    bn.mulqacc           w3.1, w12.0, 64
    bn.mulqacc           w3.2, w11.3, 64
    bn.mulqacc           w3.3, w11.2, 64
    bn.mulqacc           w4.0, w11.1, 64
    bn.mulqacc           w4.1, w11.0, 64
    bn.mulqacc           w4.2, w10.3, 64
    bn.mulqacc           w4.3, w10.2, 64
    bn.mulqacc           w5.0, w10.1, 64
    bn.mulqacc           w5.1, w10.0, 64
    bn.mulqacc           w5.2, w9.3, 64
    bn.mulqacc           w5.3, w9.2, 64
    bn.mulqacc           w6.0, w9.1, 64
    bn.mulqacc.so w24.L, w6.1, w9.0, 64

    bn.mulqacc           w0.0, w15.2, 0
    bn.mulqacc           w0.1, w15.1, 0
    bn.mulqacc           w0.2, w15.0, 0
    bn.mulqacc           w0.3, w14.3, 0
    bn.mulqacc           w1.0, w14.2, 0
    bn.mulqacc           w1.1, w14.1, 0
    bn.mulqacc           w1.2, w14.0, 0
    bn.mulqacc           w1.3, w13.3, 0
    bn.mulqacc           w2.0, w13.2, 0
    bn.mulqacc           w2.1, w13.1, 0
    bn.mulqacc           w2.2, w13.0, 0
    bn.mulqacc           w2.3, w12.3, 0
    bn.mulqacc           w3.0, w12.2, 0
    bn.mulqacc           w3.1, w12.1, 0
    bn.mulqacc           w3.2, w12.0, 0
    bn.mulqacc           w3.3, w11.3, 0
    bn.mulqacc           w4.0, w11.2, 0
    bn.mulqacc           w4.1, w11.1, 0
    bn.mulqacc           w4.2, w11.0, 0
    bn.mulqacc           w4.3, w10.3, 0
    bn.mulqacc           w5.0, w10.2, 0
    bn.mulqacc           w5.1, w10.1, 0
    bn.mulqacc           w5.2, w10.0, 0
    bn.mulqacc           w5.3, w9.3, 0
    bn.mulqacc           w6.0, w9.2, 0
    bn.mulqacc           w6.1, w9.1, 0
    bn.mulqacc           w6.2, w9.0, 0

    bn.mulqacc           w0.0, w15.3, 64
    bn.mulqacc           w0.1, w15.2, 64
    bn.mulqacc           w0.2, w15.1, 64
    bn.mulqacc           w0.3, w15.0, 64
    bn.mulqacc           w1.0, w14.3, 64
    bn.mulqacc           w1.1, w14.2, 64
    bn.mulqacc           w1.2, w14.1, 64
    bn.mulqacc           w1.3, w14.0, 64
    bn.mulqacc           w2.0, w13.3, 64
    bn.mulqacc           w2.1, w13.2, 64
    bn.mulqacc           w2.2, w13.1, 64
    bn.mulqacc           w2.3, w13.0, 64
    bn.mulqacc           w3.0, w12.3, 64
    bn.mulqacc           w3.1, w12.2, 64
    bn.mulqacc           w3.2, w12.1, 64
    bn.mulqacc           w3.3, w12.0, 64
    bn.mulqacc           w4.0, w11.3, 64
    bn.mulqacc           w4.1, w11.2, 64
    bn.mulqacc           w4.2, w11.1, 64
    bn.mulqacc           w4.3, w11.0, 64
    bn.mulqacc           w5.0, w10.3, 64
    bn.mulqacc           w5.1, w10.2, 64
    bn.mulqacc           w5.2, w10.1, 64
    bn.mulqacc           w5.3, w10.0, 64
    bn.mulqacc           w6.0, w9.3, 64
    bn.mulqacc           w6.1, w9.2, 64
    bn.mulqacc           w6.2, w9.1, 64
    bn.mulqacc.so w24.U, w6.3, w9.0, 64

    bn.mulqacc           w0.0, w16.0, 0
    bn.mulqacc           w0.1, w15.3, 0
    bn.mulqacc           w0.2, w15.2, 0
    bn.mulqacc           w0.3, w15.1, 0
    bn.mulqacc           w1.0, w15.0, 0
    bn.mulqacc           w1.1, w14.3, 0
    bn.mulqacc           w1.2, w14.2, 0
    bn.mulqacc           w1.3, w14.1, 0
    bn.mulqacc           w2.0, w14.0, 0
    bn.mulqacc           w2.1, w13.3, 0
    bn.mulqacc           w2.2, w13.2, 0
    bn.mulqacc           w2.3, w13.1, 0
    bn.mulqacc           w3.0, w13.0, 0
    bn.mulqacc           w3.1, w12.3, 0
    bn.mulqacc           w3.2, w12.2, 0
    bn.mulqacc           w3.3, w12.1, 0
    bn.mulqacc           w4.0, w12.0, 0
    bn.mulqacc           w4.1, w11.3, 0
    bn.mulqacc           w4.2, w11.2, 0
    bn.mulqacc           w4.3, w11.1, 0
    bn.mulqacc           w5.0, w11.0, 0
    bn.mulqacc           w5.1, w10.3, 0
    bn.mulqacc           w5.2, w10.2, 0
    bn.mulqacc           w5.3, w10.1, 0
    bn.mulqacc           w6.0, w10.0, 0
    bn.mulqacc           w6.1, w9.3, 0
    bn.mulqacc           w6.2, w9.2, 0
    bn.mulqacc           w6.3, w9.1, 0
    bn.mulqacc           w7.0, w9.0, 0

    bn.mulqacc           w0.0, w16.1, 64
    bn.mulqacc           w0.1, w16.0, 64
    bn.mulqacc           w0.2, w15.3, 64
    bn.mulqacc           w0.3, w15.2, 64
    bn.mulqacc           w1.0, w15.1, 64
    bn.mulqacc           w1.1, w15.0, 64
    bn.mulqacc           w1.2, w14.3, 64
    bn.mulqacc           w1.3, w14.2, 64
    bn.mulqacc           w2.0, w14.1, 64
    bn.mulqacc           w2.1, w14.0, 64
    bn.mulqacc           w2.2, w13.3, 64
    bn.mulqacc           w2.3, w13.2, 64
    bn.mulqacc           w3.0, w13.1, 64
    bn.mulqacc           w3.1, w13.0, 64
    bn.mulqacc           w3.2, w12.3, 64
    bn.mulqacc           w3.3, w12.2, 64
    bn.mulqacc           w4.0, w12.1, 64
    bn.mulqacc           w4.1, w12.0, 64
    bn.mulqacc           w4.2, w11.3, 64
    bn.mulqacc           w4.3, w11.2, 64
    bn.mulqacc           w5.0, w11.1, 64
    bn.mulqacc           w5.1, w11.0, 64
    bn.mulqacc           w5.2, w10.3, 64
    bn.mulqacc           w5.3, w10.2, 64
    bn.mulqacc           w6.0, w10.1, 64
    bn.mulqacc           w6.1, w10.0, 64
    bn.mulqacc           w6.2, w9.3, 64
    bn.mulqacc           w6.3, w9.2, 64
    bn.mulqacc           w7.0, w9.1, 64
    bn.mulqacc.so w25.L, w7.1, w9.0, 64

    bn.mulqacc           w0.0, w16.2, 0
    bn.mulqacc           w0.1, w16.1, 0
    bn.mulqacc           w0.2, w16.0, 0
    bn.mulqacc           w0.3, w15.3, 0
    bn.mulqacc           w1.0, w15.2, 0
    bn.mulqacc           w1.1, w15.1, 0
    bn.mulqacc           w1.2, w15.0, 0
    bn.mulqacc           w1.3, w14.3, 0
    bn.mulqacc           w2.0, w14.2, 0
    bn.mulqacc           w2.1, w14.1, 0
    bn.mulqacc           w2.2, w14.0, 0
    bn.mulqacc           w2.3, w13.3, 0
    bn.mulqacc           w3.0, w13.2, 0
    bn.mulqacc           w3.1, w13.1, 0
    bn.mulqacc           w3.2, w13.0, 0
    bn.mulqacc           w3.3, w12.3, 0
    bn.mulqacc           w4.0, w12.2, 0
    bn.mulqacc           w4.1, w12.1, 0
    bn.mulqacc           w4.2, w12.0, 0
    bn.mulqacc           w4.3, w11.3, 0
    bn.mulqacc           w5.0, w11.2, 0
    bn.mulqacc           w5.1, w11.1, 0
    bn.mulqacc           w5.2, w11.0, 0
    bn.mulqacc           w5.3, w10.3, 0
    bn.mulqacc           w6.0, w10.2, 0
    bn.mulqacc           w6.1, w10.1, 0
    bn.mulqacc           w6.2, w10.0, 0
    bn.mulqacc           w6.3, w9.3, 0
    bn.mulqacc           w7.0, w9.2, 0
    bn.mulqacc           w7.1, w9.1, 0
    bn.mulqacc           w7.2, w9.0, 0

    bn.mulqacc           w0.0, w16.3, 64
    bn.mulqacc           w0.1, w16.2, 64
    bn.mulqacc           w0.2, w16.1, 64
    bn.mulqacc           w0.3, w16.0, 64
    bn.mulqacc           w1.0, w15.3, 64
    bn.mulqacc           w1.1, w15.2, 64
    bn.mulqacc           w1.2, w15.1, 64
    bn.mulqacc           w1.3, w15.0, 64
    bn.mulqacc           w2.0, w14.3, 64
    bn.mulqacc           w2.1, w14.2, 64
    bn.mulqacc           w2.2, w14.1, 64
    bn.mulqacc           w2.3, w14.0, 64
    bn.mulqacc           w3.0, w13.3, 64
    bn.mulqacc           w3.1, w13.2, 64
    bn.mulqacc           w3.2, w13.1, 64
    bn.mulqacc           w3.3, w13.0, 64
    bn.mulqacc           w4.0, w12.3, 64
    bn.mulqacc           w4.1, w12.2, 64
    bn.mulqacc           w4.2, w12.1, 64
    bn.mulqacc           w4.3, w12.0, 64
    bn.mulqacc           w5.0, w11.3, 64
    bn.mulqacc           w5.1, w11.2, 64
    bn.mulqacc           w5.2, w11.1, 64
    bn.mulqacc           w5.3, w11.0, 64
    bn.mulqacc           w6.0, w10.3, 64
    bn.mulqacc           w6.1, w10.2, 64
    bn.mulqacc           w6.2, w10.1, 64
    bn.mulqacc           w6.3, w10.0, 64
    bn.mulqacc           w7.0, w9.3, 64
    bn.mulqacc           w7.1, w9.2, 64
    bn.mulqacc           w7.2, w9.1, 64
    bn.mulqacc.so w25.U, w7.3, w9.0, 64

    bn.mulqacc           w0.0, w17.0, 0
    bn.mulqacc           w0.1, w16.3, 0
    bn.mulqacc           w0.2, w16.2, 0
    bn.mulqacc           w0.3, w16.1, 0
    bn.mulqacc           w1.0, w16.0, 0
    bn.mulqacc           w1.1, w15.3, 0
    bn.mulqacc           w1.2, w15.2, 0
    bn.mulqacc           w1.3, w15.1, 0
    bn.mulqacc           w2.0, w15.0, 0
    bn.mulqacc           w2.1, w14.3, 0
    bn.mulqacc           w2.2, w14.2, 0
    bn.mulqacc           w2.3, w14.1, 0
    bn.mulqacc           w3.0, w14.0, 0
    bn.mulqacc           w3.1, w13.3, 0
    bn.mulqacc           w3.2, w13.2, 0
    bn.mulqacc           w3.3, w13.1, 0
    bn.mulqacc           w4.0, w13.0, 0
    bn.mulqacc           w4.1, w12.3, 0
    bn.mulqacc           w4.2, w12.2, 0
    bn.mulqacc           w4.3, w12.1, 0
    bn.mulqacc           w5.0, w12.0, 0
    bn.mulqacc           w5.1, w11.3, 0
    bn.mulqacc           w5.2, w11.2, 0
    bn.mulqacc           w5.3, w11.1, 0
    bn.mulqacc           w6.0, w11.0, 0
    bn.mulqacc           w6.1, w10.3, 0
    bn.mulqacc           w6.2, w10.2, 0
    bn.mulqacc           w6.3, w10.1, 0
    bn.mulqacc           w7.0, w10.0, 0
    bn.mulqacc           w7.1, w9.3, 0
    bn.mulqacc           w7.2, w9.2, 0
    bn.mulqacc           w7.3, w9.1, 0
    bn.mulqacc           w8.0, w9.0, 0

    bn.mulqacc           w0.1, w17.0, 64
    bn.mulqacc           w0.2, w16.3, 64
    bn.mulqacc           w0.3, w16.2, 64
    bn.mulqacc           w1.0, w16.1, 64
    bn.mulqacc           w1.1, w16.0, 64
    bn.mulqacc           w1.2, w15.3, 64
    bn.mulqacc           w1.3, w15.2, 64
    bn.mulqacc           w2.0, w15.1, 64
    bn.mulqacc           w2.1, w15.0, 64
    bn.mulqacc           w2.2, w14.3, 64
    bn.mulqacc           w2.3, w14.2, 64
    bn.mulqacc           w3.0, w14.1, 64
    bn.mulqacc           w3.1, w14.0, 64
    bn.mulqacc           w3.2, w13.3, 64
    bn.mulqacc           w3.3, w13.2, 64
    bn.mulqacc           w4.0, w13.1, 64
    bn.mulqacc           w4.1, w13.0, 64
    bn.mulqacc           w4.2, w12.3, 64
    bn.mulqacc           w4.3, w12.2, 64
    bn.mulqacc           w5.0, w12.1, 64
    bn.mulqacc           w5.1, w12.0, 64
    bn.mulqacc           w5.2, w11.3, 64
    bn.mulqacc           w5.3, w11.2, 64
    bn.mulqacc           w6.0, w11.1, 64
    bn.mulqacc           w6.1, w11.0, 64
    bn.mulqacc           w6.2, w10.3, 64
    bn.mulqacc           w6.3, w10.2, 64
    bn.mulqacc           w7.0, w10.1, 64
    bn.mulqacc           w7.1, w10.0, 64
    bn.mulqacc           w7.2, w9.3, 64
    bn.mulqacc           w7.3, w9.2, 64
    bn.mulqacc.so w29.L, w8.0, w9.1, 64

    bn.mulqacc           w0.2, w17.0, 0
    bn.mulqacc           w0.3, w16.3, 0
    bn.mulqacc           w1.0, w16.2, 0
    bn.mulqacc           w1.1, w16.1, 0
    bn.mulqacc           w1.2, w16.0, 0
    bn.mulqacc           w1.3, w15.3, 0
    bn.mulqacc           w2.0, w15.2, 0
    bn.mulqacc           w2.1, w15.1, 0
    bn.mulqacc           w2.2, w15.0, 0
    bn.mulqacc           w2.3, w14.3, 0
    bn.mulqacc           w3.0, w14.2, 0
    bn.mulqacc           w3.1, w14.1, 0
    bn.mulqacc           w3.2, w14.0, 0
    bn.mulqacc           w3.3, w13.3, 0
    bn.mulqacc           w4.0, w13.2, 0
    bn.mulqacc           w4.1, w13.1, 0
    bn.mulqacc           w4.2, w13.0, 0
    bn.mulqacc           w4.3, w12.3, 0
    bn.mulqacc           w5.0, w12.2, 0
    bn.mulqacc           w5.1, w12.1, 0
    bn.mulqacc           w5.2, w12.0, 0
    bn.mulqacc           w5.3, w11.3, 0
    bn.mulqacc           w6.0, w11.2, 0
    bn.mulqacc           w6.1, w11.1, 0
    bn.mulqacc           w6.2, w11.0, 0
    bn.mulqacc           w6.3, w10.3, 0
    bn.mulqacc           w7.0, w10.2, 0
    bn.mulqacc           w7.1, w10.1, 0
    bn.mulqacc           w7.2, w10.0, 0
    bn.mulqacc           w7.3, w9.3, 0
    bn.mulqacc           w8.0, w9.2, 0

    bn.mulqacc           w0.3, w17.0, 64
    bn.mulqacc           w1.0, w16.3, 64
    bn.mulqacc           w1.1, w16.2, 64
    bn.mulqacc           w1.2, w16.1, 64
    bn.mulqacc           w1.3, w16.0, 64
    bn.mulqacc           w2.0, w15.3, 64
    bn.mulqacc           w2.1, w15.2, 64
    bn.mulqacc           w2.2, w15.1, 64
    bn.mulqacc           w2.3, w15.0, 64
    bn.mulqacc           w3.0, w14.3, 64
    bn.mulqacc           w3.1, w14.2, 64
    bn.mulqacc           w3.2, w14.1, 64
    bn.mulqacc           w3.3, w14.0, 64
    bn.mulqacc           w4.0, w13.3, 64
    bn.mulqacc           w4.1, w13.2, 64
    bn.mulqacc           w4.2, w13.1, 64
    bn.mulqacc           w4.3, w13.0, 64
    bn.mulqacc           w5.0, w12.3, 64
    bn.mulqacc           w5.1, w12.2, 64
    bn.mulqacc           w5.2, w12.1, 64
    bn.mulqacc           w5.3, w12.0, 64
    bn.mulqacc           w6.0, w11.3, 64
    bn.mulqacc           w6.1, w11.2, 64
    bn.mulqacc           w6.2, w11.1, 64
    bn.mulqacc           w6.3, w11.0, 64
    bn.mulqacc           w7.0, w10.3, 64
    bn.mulqacc           w7.1, w10.2, 64
    bn.mulqacc           w7.2, w10.1, 64
    bn.mulqacc           w7.3, w10.0, 64
    bn.mulqacc.so w29.U, w8.0, w9.3, 64

    bn.sub w18, w18, w29

    bn.mulqacc           w1.0, w17.0, 0
    bn.mulqacc           w1.1, w16.3, 0
    bn.mulqacc           w1.2, w16.2, 0
    bn.mulqacc           w1.3, w16.1, 0
    bn.mulqacc           w2.0, w16.0, 0
    bn.mulqacc           w2.1, w15.3, 0
    bn.mulqacc           w2.2, w15.2, 0
    bn.mulqacc           w2.3, w15.1, 0
    bn.mulqacc           w3.0, w15.0, 0
    bn.mulqacc           w3.1, w14.3, 0
    bn.mulqacc           w3.2, w14.2, 0
    bn.mulqacc           w3.3, w14.1, 0
    bn.mulqacc           w4.0, w14.0, 0
    bn.mulqacc           w4.1, w13.3, 0
    bn.mulqacc           w4.2, w13.2, 0
    bn.mulqacc           w4.3, w13.1, 0
    bn.mulqacc           w5.0, w13.0, 0
    bn.mulqacc           w5.1, w12.3, 0
    bn.mulqacc           w5.2, w12.2, 0
    bn.mulqacc           w5.3, w12.1, 0
    bn.mulqacc           w6.0, w12.0, 0
    bn.mulqacc           w6.1, w11.3, 0
    bn.mulqacc           w6.2, w11.2, 0
    bn.mulqacc           w6.3, w11.1, 0
    bn.mulqacc           w7.0, w11.0, 0
    bn.mulqacc           w7.1, w10.3, 0
    bn.mulqacc           w7.2, w10.2, 0
    bn.mulqacc           w7.3, w10.1, 0
    bn.mulqacc           w8.0, w10.0, 0

    bn.mulqacc           w1.1, w17.0, 64
    bn.mulqacc           w1.2, w16.3, 64
    bn.mulqacc           w1.3, w16.2, 64
    bn.mulqacc           w2.0, w16.1, 64
    bn.mulqacc           w2.1, w16.0, 64
    bn.mulqacc           w2.2, w15.3, 64
    bn.mulqacc           w2.3, w15.2, 64
    bn.mulqacc           w3.0, w15.1, 64
    bn.mulqacc           w3.1, w15.0, 64
    bn.mulqacc           w3.2, w14.3, 64
    bn.mulqacc           w3.3, w14.2, 64
    bn.mulqacc           w4.0, w14.1, 64
    bn.mulqacc           w4.1, w14.0, 64
    bn.mulqacc           w4.2, w13.3, 64
    bn.mulqacc           w4.3, w13.2, 64
    bn.mulqacc           w5.0, w13.1, 64
    bn.mulqacc           w5.1, w13.0, 64
    bn.mulqacc           w5.2, w12.3, 64
    bn.mulqacc           w5.3, w12.2, 64
    bn.mulqacc           w6.0, w12.1, 64
    bn.mulqacc           w6.1, w12.0, 64
    bn.mulqacc           w6.2, w11.3, 64
    bn.mulqacc           w6.3, w11.2, 64
    bn.mulqacc           w7.0, w11.1, 64
    bn.mulqacc           w7.1, w11.0, 64
    bn.mulqacc           w7.2, w10.3, 64
    bn.mulqacc           w7.3, w10.2, 64
    bn.mulqacc.so w29.L, w8.0, w10.1, 64

    bn.mulqacc           w1.2, w17.0, 0
    bn.mulqacc           w1.3, w16.3, 0
    bn.mulqacc           w2.0, w16.2, 0
    bn.mulqacc           w2.1, w16.1, 0
    bn.mulqacc           w2.2, w16.0, 0
    bn.mulqacc           w2.3, w15.3, 0
    bn.mulqacc           w3.0, w15.2, 0
    bn.mulqacc           w3.1, w15.1, 0
    bn.mulqacc           w3.2, w15.0, 0
    bn.mulqacc           w3.3, w14.3, 0
    bn.mulqacc           w4.0, w14.2, 0
    bn.mulqacc           w4.1, w14.1, 0
    bn.mulqacc           w4.2, w14.0, 0
    bn.mulqacc           w4.3, w13.3, 0
    bn.mulqacc           w5.0, w13.2, 0
    bn.mulqacc           w5.1, w13.1, 0
    bn.mulqacc           w5.2, w13.0, 0
    bn.mulqacc           w5.3, w12.3, 0
    bn.mulqacc           w6.0, w12.2, 0
    bn.mulqacc           w6.1, w12.1, 0
    bn.mulqacc           w6.2, w12.0, 0
    bn.mulqacc           w6.3, w11.3, 0
    bn.mulqacc           w7.0, w11.2, 0
    bn.mulqacc           w7.1, w11.1, 0
    bn.mulqacc           w7.2, w11.0, 0
    bn.mulqacc           w7.3, w10.3, 0
    bn.mulqacc           w8.0, w10.2, 0

    bn.mulqacc           w1.3, w17.0, 64
    bn.mulqacc           w2.0, w16.3, 64
    bn.mulqacc           w2.1, w16.2, 64
    bn.mulqacc           w2.2, w16.1, 64
    bn.mulqacc           w2.3, w16.0, 64
    bn.mulqacc           w3.0, w15.3, 64
    bn.mulqacc           w3.1, w15.2, 64
    bn.mulqacc           w3.2, w15.1, 64
    bn.mulqacc           w3.3, w15.0, 64
    bn.mulqacc           w4.0, w14.3, 64
    bn.mulqacc           w4.1, w14.2, 64
    bn.mulqacc           w4.2, w14.1, 64
    bn.mulqacc           w4.3, w14.0, 64
    bn.mulqacc           w5.0, w13.3, 64
    bn.mulqacc           w5.1, w13.2, 64
    bn.mulqacc           w5.2, w13.1, 64
    bn.mulqacc           w5.3, w13.0, 64
    bn.mulqacc           w6.0, w12.3, 64
    bn.mulqacc           w6.1, w12.2, 64
    bn.mulqacc           w6.2, w12.1, 64
    bn.mulqacc           w6.3, w12.0, 64
    bn.mulqacc           w7.0, w11.3, 64
    bn.mulqacc           w7.1, w11.2, 64
    bn.mulqacc           w7.2, w11.1, 64
    bn.mulqacc           w7.3, w11.0, 64
    bn.mulqacc.so w29.U, w8.0, w10.3, 64

    bn.subb w19, w19, w29

    bn.mulqacc           w2.0, w17.0, 0
    bn.mulqacc           w2.1, w16.3, 0
    bn.mulqacc           w2.2, w16.2, 0
    bn.mulqacc           w2.3, w16.1, 0
    bn.mulqacc           w3.0, w16.0, 0
    bn.mulqacc           w3.1, w15.3, 0
    bn.mulqacc           w3.2, w15.2, 0
    bn.mulqacc           w3.3, w15.1, 0
    bn.mulqacc           w4.0, w15.0, 0
    bn.mulqacc           w4.1, w14.3, 0
    bn.mulqacc           w4.2, w14.2, 0
    bn.mulqacc           w4.3, w14.1, 0
    bn.mulqacc           w5.0, w14.0, 0
    bn.mulqacc           w5.1, w13.3, 0
    bn.mulqacc           w5.2, w13.2, 0
    bn.mulqacc           w5.3, w13.1, 0
    bn.mulqacc           w6.0, w13.0, 0
    bn.mulqacc           w6.1, w12.3, 0
    bn.mulqacc           w6.2, w12.2, 0
    bn.mulqacc           w6.3, w12.1, 0
    bn.mulqacc           w7.0, w12.0, 0
    bn.mulqacc           w7.1, w11.3, 0
    bn.mulqacc           w7.2, w11.2, 0
    bn.mulqacc           w7.3, w11.1, 0
    bn.mulqacc           w8.0, w11.0, 0

    bn.mulqacc           w2.1, w17.0, 64
    bn.mulqacc           w2.2, w16.3, 64
    bn.mulqacc           w2.3, w16.2, 64
    bn.mulqacc           w3.0, w16.1, 64
    bn.mulqacc           w3.1, w16.0, 64
    bn.mulqacc           w3.2, w15.3, 64
    bn.mulqacc           w3.3, w15.2, 64
    bn.mulqacc           w4.0, w15.1, 64
    bn.mulqacc           w4.1, w15.0, 64
    bn.mulqacc           w4.2, w14.3, 64
    bn.mulqacc           w4.3, w14.2, 64
    bn.mulqacc           w5.0, w14.1, 64
    bn.mulqacc           w5.1, w14.0, 64
    bn.mulqacc           w5.2, w13.3, 64
    bn.mulqacc           w5.3, w13.2, 64
    bn.mulqacc           w6.0, w13.1, 64
    bn.mulqacc           w6.1, w13.0, 64
    bn.mulqacc           w6.2, w12.3, 64
    bn.mulqacc           w6.3, w12.2, 64
    bn.mulqacc           w7.0, w12.1, 64
    bn.mulqacc           w7.1, w12.0, 64
    bn.mulqacc           w7.2, w11.3, 64
    bn.mulqacc           w7.3, w11.2, 64
    bn.mulqacc.so w29.L, w8.0, w11.1, 64

    bn.mulqacc           w2.2, w17.0, 0
    bn.mulqacc           w2.3, w16.3, 0
    bn.mulqacc           w3.0, w16.2, 0
    bn.mulqacc           w3.1, w16.1, 0
    bn.mulqacc           w3.2, w16.0, 0
    bn.mulqacc           w3.3, w15.3, 0
    bn.mulqacc           w4.0, w15.2, 0
    bn.mulqacc           w4.1, w15.1, 0
    bn.mulqacc           w4.2, w15.0, 0
    bn.mulqacc           w4.3, w14.3, 0
    bn.mulqacc           w5.0, w14.2, 0
    bn.mulqacc           w5.1, w14.1, 0
    bn.mulqacc           w5.2, w14.0, 0
    bn.mulqacc           w5.3, w13.3, 0
    bn.mulqacc           w6.0, w13.2, 0
    bn.mulqacc           w6.1, w13.1, 0
    bn.mulqacc           w6.2, w13.0, 0
    bn.mulqacc           w6.3, w12.3, 0
    bn.mulqacc           w7.0, w12.2, 0
    bn.mulqacc           w7.1, w12.1, 0
    bn.mulqacc           w7.2, w12.0, 0
    bn.mulqacc           w7.3, w11.3, 0
    bn.mulqacc           w8.0, w11.2, 0

    bn.mulqacc           w2.3, w17.0, 64
    bn.mulqacc           w3.0, w16.3, 64
    bn.mulqacc           w3.1, w16.2, 64
    bn.mulqacc           w3.2, w16.1, 64
    bn.mulqacc           w3.3, w16.0, 64
    bn.mulqacc           w4.0, w15.3, 64
    bn.mulqacc           w4.1, w15.2, 64
    bn.mulqacc           w4.2, w15.1, 64
    bn.mulqacc           w4.3, w15.0, 64
    bn.mulqacc           w5.0, w14.3, 64
    bn.mulqacc           w5.1, w14.2, 64
    bn.mulqacc           w5.2, w14.1, 64
    bn.mulqacc           w5.3, w14.0, 64
    bn.mulqacc           w6.0, w13.3, 64
    bn.mulqacc           w6.1, w13.2, 64
    bn.mulqacc           w6.2, w13.1, 64
    bn.mulqacc           w6.3, w13.0, 64
    bn.mulqacc           w7.0, w12.3, 64
    bn.mulqacc           w7.1, w12.2, 64
    bn.mulqacc           w7.2, w12.1, 64
    bn.mulqacc           w7.3, w12.0, 64
    bn.mulqacc.so w29.U, w8.0, w11.3, 64

    bn.subb w20, w20, w29

    bn.mulqacc           w3.0, w17.0, 0
    bn.mulqacc           w3.1, w16.3, 0
    bn.mulqacc           w3.2, w16.2, 0
    bn.mulqacc           w3.3, w16.1, 0
    bn.mulqacc           w4.0, w16.0, 0
    bn.mulqacc           w4.1, w15.3, 0
    bn.mulqacc           w4.2, w15.2, 0
    bn.mulqacc           w4.3, w15.1, 0
    bn.mulqacc           w5.0, w15.0, 0
    bn.mulqacc           w5.1, w14.3, 0
    bn.mulqacc           w5.2, w14.2, 0
    bn.mulqacc           w5.3, w14.1, 0
    bn.mulqacc           w6.0, w14.0, 0
    bn.mulqacc           w6.1, w13.3, 0
    bn.mulqacc           w6.2, w13.2, 0
    bn.mulqacc           w6.3, w13.1, 0
    bn.mulqacc           w7.0, w13.0, 0
    bn.mulqacc           w7.1, w12.3, 0
    bn.mulqacc           w7.2, w12.2, 0
    bn.mulqacc           w7.3, w12.1, 0
    bn.mulqacc           w8.0, w12.0, 0

    bn.mulqacc           w3.1, w17.0, 64
    bn.mulqacc           w3.2, w16.3, 64
    bn.mulqacc           w3.3, w16.2, 64
    bn.mulqacc           w4.0, w16.1, 64
    bn.mulqacc           w4.1, w16.0, 64
    bn.mulqacc           w4.2, w15.3, 64
    bn.mulqacc           w4.3, w15.2, 64
    bn.mulqacc           w5.0, w15.1, 64
    bn.mulqacc           w5.1, w15.0, 64
    bn.mulqacc           w5.2, w14.3, 64
    bn.mulqacc           w5.3, w14.2, 64
    bn.mulqacc           w6.0, w14.1, 64
    bn.mulqacc           w6.1, w14.0, 64
    bn.mulqacc           w6.2, w13.3, 64
    bn.mulqacc           w6.3, w13.2, 64
    bn.mulqacc           w7.0, w13.1, 64
    bn.mulqacc           w7.1, w13.0, 64
    bn.mulqacc           w7.2, w12.3, 64
    bn.mulqacc           w7.3, w12.2, 64
    bn.mulqacc.so w29.L, w8.0, w12.1, 64

    bn.mulqacc           w3.2, w17.0, 0
    bn.mulqacc           w3.3, w16.3, 0
    bn.mulqacc           w4.0, w16.2, 0
    bn.mulqacc           w4.1, w16.1, 0
    bn.mulqacc           w4.2, w16.0, 0
    bn.mulqacc           w4.3, w15.3, 0
    bn.mulqacc           w5.0, w15.2, 0
    bn.mulqacc           w5.1, w15.1, 0
    bn.mulqacc           w5.2, w15.0, 0
    bn.mulqacc           w5.3, w14.3, 0
    bn.mulqacc           w6.0, w14.2, 0
    bn.mulqacc           w6.1, w14.1, 0
    bn.mulqacc           w6.2, w14.0, 0
    bn.mulqacc           w6.3, w13.3, 0
    bn.mulqacc           w7.0, w13.2, 0
    bn.mulqacc           w7.1, w13.1, 0
    bn.mulqacc           w7.2, w13.0, 0
    bn.mulqacc           w7.3, w12.3, 0
    bn.mulqacc           w8.0, w12.2, 0

    bn.mulqacc           w3.3, w17.0, 64
    bn.mulqacc           w4.0, w16.3, 64
    bn.mulqacc           w4.1, w16.2, 64
    bn.mulqacc           w4.2, w16.1, 64
    bn.mulqacc           w4.3, w16.0, 64
    bn.mulqacc           w5.0, w15.3, 64
    bn.mulqacc           w5.1, w15.2, 64
    bn.mulqacc           w5.2, w15.1, 64
    bn.mulqacc           w5.3, w15.0, 64
    bn.mulqacc           w6.0, w14.3, 64
    bn.mulqacc           w6.1, w14.2, 64
    bn.mulqacc           w6.2, w14.1, 64
    bn.mulqacc           w6.3, w14.0, 64
    bn.mulqacc           w7.0, w13.3, 64
    bn.mulqacc           w7.1, w13.2, 64
    bn.mulqacc           w7.2, w13.1, 64
    bn.mulqacc           w7.3, w13.0, 64
    bn.mulqacc.so w29.U, w8.0, w12.3, 64

    bn.subb w21, w21, w29

    bn.mulqacc           w4.0, w17.0, 0
    bn.mulqacc           w4.1, w16.3, 0
    bn.mulqacc           w4.2, w16.2, 0
    bn.mulqacc           w4.3, w16.1, 0
    bn.mulqacc           w5.0, w16.0, 0
    bn.mulqacc           w5.1, w15.3, 0
    bn.mulqacc           w5.2, w15.2, 0
    bn.mulqacc           w5.3, w15.1, 0
    bn.mulqacc           w6.0, w15.0, 0
    bn.mulqacc           w6.1, w14.3, 0
    bn.mulqacc           w6.2, w14.2, 0
    bn.mulqacc           w6.3, w14.1, 0
    bn.mulqacc           w7.0, w14.0, 0
    bn.mulqacc           w7.1, w13.3, 0
    bn.mulqacc           w7.2, w13.2, 0
    bn.mulqacc           w7.3, w13.1, 0
    bn.mulqacc           w8.0, w13.0, 0

    bn.mulqacc           w4.1, w17.0, 64
    bn.mulqacc           w4.2, w16.3, 64
    bn.mulqacc           w4.3, w16.2, 64
    bn.mulqacc           w5.0, w16.1, 64
    bn.mulqacc           w5.1, w16.0, 64
    bn.mulqacc           w5.2, w15.3, 64
    bn.mulqacc           w5.3, w15.2, 64
    bn.mulqacc           w6.0, w15.1, 64
    bn.mulqacc           w6.1, w15.0, 64
    bn.mulqacc           w6.2, w14.3, 64
    bn.mulqacc           w6.3, w14.2, 64
    bn.mulqacc           w7.0, w14.1, 64
    bn.mulqacc           w7.1, w14.0, 64
    bn.mulqacc           w7.2, w13.3, 64
    bn.mulqacc           w7.3, w13.2, 64
    bn.mulqacc.so w29.L, w8.0, w13.1, 64

    bn.mulqacc           w4.2, w17.0, 0
    bn.mulqacc           w4.3, w16.3, 0
    bn.mulqacc           w5.0, w16.2, 0
    bn.mulqacc           w5.1, w16.1, 0
    bn.mulqacc           w5.2, w16.0, 0
    bn.mulqacc           w5.3, w15.3, 0
    bn.mulqacc           w6.0, w15.2, 0
    bn.mulqacc           w6.1, w15.1, 0
    bn.mulqacc           w6.2, w15.0, 0
    bn.mulqacc           w6.3, w14.3, 0
    bn.mulqacc           w7.0, w14.2, 0
    bn.mulqacc           w7.1, w14.1, 0
    bn.mulqacc           w7.2, w14.0, 0
    bn.mulqacc           w7.3, w13.3, 0
    bn.mulqacc           w8.0, w13.2, 0

    bn.mulqacc           w4.3, w17.0, 64
    bn.mulqacc           w5.0, w16.3, 64
    bn.mulqacc           w5.1, w16.2, 64
    bn.mulqacc           w5.2, w16.1, 64
    bn.mulqacc           w5.3, w16.0, 64
    bn.mulqacc           w6.0, w15.3, 64
    bn.mulqacc           w6.1, w15.2, 64
    bn.mulqacc           w6.2, w15.1, 64
    bn.mulqacc           w6.3, w15.0, 64
    bn.mulqacc           w7.0, w14.3, 64
    bn.mulqacc           w7.1, w14.2, 64
    bn.mulqacc           w7.2, w14.1, 64
    bn.mulqacc           w7.3, w14.0, 64
    bn.mulqacc.so w29.U, w8.0, w13.3, 64

    bn.subb w22, w22, w29

    bn.mulqacc           w5.0, w17.0, 0
    bn.mulqacc           w5.1, w16.3, 0
    bn.mulqacc           w5.2, w16.2, 0
    bn.mulqacc           w5.3, w16.1, 0
    bn.mulqacc           w6.0, w16.0, 0
    bn.mulqacc           w6.1, w15.3, 0
    bn.mulqacc           w6.2, w15.2, 0
    bn.mulqacc           w6.3, w15.1, 0
    bn.mulqacc           w7.0, w15.0, 0
    bn.mulqacc           w7.1, w14.3, 0
    bn.mulqacc           w7.2, w14.2, 0
    bn.mulqacc           w7.3, w14.1, 0
    bn.mulqacc           w8.0, w14.0, 0

    bn.mulqacc           w5.1, w17.0, 64
    bn.mulqacc           w5.2, w16.3, 64
    bn.mulqacc           w5.3, w16.2, 64
    bn.mulqacc           w6.0, w16.1, 64
    bn.mulqacc           w6.1, w16.0, 64
    bn.mulqacc           w6.2, w15.3, 64
    bn.mulqacc           w6.3, w15.2, 64
    bn.mulqacc           w7.0, w15.1, 64
    bn.mulqacc           w7.1, w15.0, 64
    bn.mulqacc           w7.2, w14.3, 64
    bn.mulqacc           w7.3, w14.2, 64
    bn.mulqacc.so w29.L, w8.0, w14.1, 64

    bn.mulqacc           w5.2, w17.0, 0
    bn.mulqacc           w5.3, w16.3, 0
    bn.mulqacc           w6.0, w16.2, 0
    bn.mulqacc           w6.1, w16.1, 0
    bn.mulqacc           w6.2, w16.0, 0
    bn.mulqacc           w6.3, w15.3, 0
    bn.mulqacc           w7.0, w15.2, 0
    bn.mulqacc           w7.1, w15.1, 0
    bn.mulqacc           w7.2, w15.0, 0
    bn.mulqacc           w7.3, w14.3, 0
    bn.mulqacc           w8.0, w14.2, 0

    bn.mulqacc           w5.3, w17.0, 64
    bn.mulqacc           w6.0, w16.3, 64
    bn.mulqacc           w6.1, w16.2, 64
    bn.mulqacc           w6.2, w16.1, 64
    bn.mulqacc           w6.3, w16.0, 64
    bn.mulqacc           w7.0, w15.3, 64
    bn.mulqacc           w7.1, w15.2, 64
    bn.mulqacc           w7.2, w15.1, 64
    bn.mulqacc           w7.3, w15.0, 64
    bn.mulqacc.so w29.U, w8.0, w14.3, 64

    bn.subb w23, w23, w29

    bn.mulqacc           w6.0, w17.0, 0
    bn.mulqacc           w6.1, w16.3, 0
    bn.mulqacc           w6.2, w16.2, 0
    bn.mulqacc           w6.3, w16.1, 0
    bn.mulqacc           w7.0, w16.0, 0
    bn.mulqacc           w7.1, w15.3, 0
    bn.mulqacc           w7.2, w15.2, 0
    bn.mulqacc           w7.3, w15.1, 0
    bn.mulqacc           w8.0, w15.0, 0

    bn.mulqacc           w6.1, w17.0, 64
    bn.mulqacc           w6.2, w16.3, 64
    bn.mulqacc           w6.3, w16.2, 64
    bn.mulqacc           w7.0, w16.1, 64
    bn.mulqacc           w7.1, w16.0, 64
    bn.mulqacc           w7.2, w15.3, 64
    bn.mulqacc           w7.3, w15.2, 64
    bn.mulqacc.so w29.L, w8.0, w15.1, 64

    bn.mulqacc           w6.2, w17.0, 0
    bn.mulqacc           w6.3, w16.3, 0
    bn.mulqacc           w7.0, w16.2, 0
    bn.mulqacc           w7.1, w16.1, 0
    bn.mulqacc           w7.2, w16.0, 0
    bn.mulqacc           w7.3, w15.3, 0
    bn.mulqacc           w8.0, w15.2, 0

    bn.mulqacc           w6.3, w17.0, 64
    bn.mulqacc           w7.0, w16.3, 64
    bn.mulqacc           w7.1, w16.2, 64
    bn.mulqacc           w7.2, w16.1, 64
    bn.mulqacc           w7.3, w16.0, 64
    bn.mulqacc.so w29.U, w8.0, w15.3, 64

    bn.subb w24, w24, w29

    bn.mulqacc           w7.0, w17.0, 0
    bn.mulqacc           w7.1, w16.3, 0
    bn.mulqacc           w7.2, w16.2, 0
    bn.mulqacc           w7.3, w16.1, 0
    bn.mulqacc           w8.0, w16.0, 0

    bn.mulqacc           w7.1, w17.0, 64
    bn.mulqacc           w7.2, w16.3, 64
    bn.mulqacc           w7.3, w16.2, 64
    bn.mulqacc.so w29.L, w8.0, w16.1, 64

    bn.mulqacc           w7.2, w17.0, 0
    bn.mulqacc           w7.3, w16.3, 0
    bn.mulqacc           w8.0, w16.2, 0

    bn.mulqacc           w7.3, w17.0, 64
    bn.mulqacc.so w29.U, w8.0, w16.3, 64

    bn.subb w25, w25, w29

    bn.xor  w29, w29, w29

    bn.mulqacc.so w29.L, w8.0, w17.0, 0

    bn.addc w18, w18, w29

    /* propagate carry */

    bn.addc w19, w19, w31
    bn.addc w20, w20, w31
    bn.addc w21, w21, w31
    bn.addc w22, w22, w31
    bn.addc w23, w23, w31
    bn.addc w24, w24, w31
    bn.addc w25, w25, w31
    bn.addc w26, w31, w31

    ret
    

step5: /* backward butterfly without multiplication with t^-1 */
  la x24, intermediate_polynomial1
  
  li x31, 31
  li x23, 8

    /* m = 2 */

    li x21, 4 /* t // m */
    li x20, 288 /* m/2 * 9 * 256 / 8 */

      /* i = 0 */

      addi x19, x24, 0 /* i * 9 * 256 / 8 */
      la  x18, butterfly_second_number_no_shift
      jal x1, butterfly_inverse_jloop

      
    /* m = 4 */

    li x21, 2 
    li x20, 576

      /* i = 0 */

      addi x19, x24, 0 
      la x18, butterfly_second_number_no_shift
      jal x1, butterfly_inverse_jloop

      /* i = 1 */
    
      addi x19, x24, 288
      la  x18, step5_second_number_shift_12 /* w_m^-1 = w_t^-2 = w_t^6 =  */
      jal x1, butterfly_inverse_jloop
      

    /* m = 8 */

    li x21, 1
    li x20, 1152

      /* i = 0 */

      addi x19, x24, 0 
      la  x18, butterfly_second_number_no_shift
      jal x1, butterfly_inverse_jloop

      /* i = 1 */

      addi x19, x24, 288
      la  x18, step5_second_number_shift_14
      jal x1, butterfly_inverse_jloop

      /* i = 2 */

      addi x19, x24, 576
      la  x18, step5_second_number_shift_12
      jal x1, butterfly_inverse_jloop

      /* i = 3 */

      addi x19, x24, 864
      la  x18, step5_second_number_shift_10
      jal x1, butterfly_inverse_jloop


  ret

  step5_second_number_shift_12:

    li x27, 17
    jal x1, load_number

    /* modulo reduce */

    bn.sub  w13, w31, w17
    bn.subb w14, w31, w18
    bn.subb w15, w31, w19
    bn.subb w16, w31, w20
    bn.addc w9,  w31, w21
    bn.addc w10, w31, w22
    bn.addc w11, w31, w23
    bn.addc w12, w31, w24
    bn.addc w13, w13, w25
    bn.addc w14, w14, w31
    bn.addc w15, w15, w31
    bn.addc w16, w16, w31
    bn.addc w17, w31, w31

    ret


  step5_second_number_shift_10:

    li x27, 17
    jal x1, load_number

    /* modulo reduce */

    bn.sub  w11, w31, w17
    bn.subb w12, w31, w18
    bn.subb w13, w31, w19
    bn.subb w14, w31, w20
    bn.subb w15, w31, w21
    bn.subb w16, w31, w22
    bn.addc w9,  w31, w23
    bn.addc w10, w31, w24
    bn.addc w11, w11, w25
    bn.addc w12, w12, w31
    bn.addc w13, w13, w31
    bn.addc w14, w14, w31
    bn.addc w15, w15, w31
    bn.addc w16, w16, w31
    bn.addc w17, w31, w31

    ret

  
  step5_second_number_shift_14:

    /* w17 ... w20 */

    li x27, 17
    jal x1, load_number

    /* modulo reduce */

    bn.sub  w15, w31, w17
    bn.subb  w16, w31, w18
    bn.addc w9,  w31, w19
    bn.addc w10, w31, w20
    bn.addc w11, w31, w21
    bn.addc w12, w31, w22
    bn.addc w13, w31, w23
    bn.addc w14, w31, w24
    bn.addc w15, w15, w25
    bn.addc w16, w16, w31
    bn.addc w17, w31, w31

    ret


step6: /* multiply by t^-1 and X^-i and modulo reduction */
  
  /* 
    Multiplication by t^-1 mod 2**2048 + 1 

    Stores the top most 256 bits of 8^-1 modulo 2^2048 + 1 = 
    1 * 2**2047 + 1 * 2**2046 + 1 * 2**2045 + 1 into w30 such that an optimized fast multiplication of this number with another long number can be performed. 

    Multiplication by X^-i (mod 2 ** 2048 + 1):

    X^-0 = 1
    X^-1 = (2^8)^-1 = 11111111 << 2040 + 1
    X^-2 = (2^8)^-2 = 11111111 11111111 << 2032 + 1
    ...

    8 * 7 = 56 so the 1's fit in the top 64 bits of the 8 * 256-bit numbers they stand for => use the optimized multiplication
  */

  la   x26, intermediate_polynomial1

  /*
    Multiply first number only by t^-1 since (X^-1)^0 = 1.
  */

  bn.addi w29, w31, 7
  bn.rshi w29, w29, w31 >> 3
  bn.mov w30, w29

  la x28, optimized_mult
  jal x1, load_apply_operation_save

  /*
    Multiply the rest
  */

  la x28, step6_multiplication

  bn.xor  w27, w27, w27
  bn.addi w28, w31, 255 /* 11111111 = 255 */

  loopi 7, 2
    jal x1, load_apply_operation_save
    nop

  ret

  step6_multiplication:

    bn.mov w30, w29

    jal x1, optimized_mult

    bn.rshi w27, w28, w27 >> 8
    bn.mov w30, w27

    jal x1, optimized_mult

    bn.sub  w0, w0,  w8
    bn.subb w1, w1, w31
    bn.subb w2, w2, w31
    bn.subb w3, w3, w31
    bn.subb w4, w4, w31
    bn.subb w5, w5, w31
    bn.subb w6, w6, w31
    bn.subb w7, w7, w31

    bn.addc w0, w0, w31
    bn.addc w1, w1, w31
    bn.addc w2, w2, w31
    bn.addc w3, w3, w31
    bn.addc w4, w4, w31
    bn.addc w5, w5, w31
    bn.addc w6, w6, w31
    bn.addc w7, w7, w31
    bn.addc w8, w31, w31

    ret


step7: /* sneeze and reorder coefficients */

  /*
    w30 = q
    w29 = q << 41 ( > 2**(l - 1) and < 2**l )
    w28 = 1/q << (64 + 22 = 86) 
    w27 = 2**l
    w26 = 2**(l-1)
    w25 = output buffer
    w24 = sneeze carries
    w23 = current number to be sneezed and reduced

    w10, w12 = temporary

    w0 ... w7  = numbers WDRs
  */

  la  x24, intermediate_polynomial1
  la  x21, output_polynomial

  /* w30 = q = 2^23 - 2^13 + 1 = 8380417 = 11111111110000000000001 */
  bn.addi w30, w31, 1023 /* 1111111111 */
  bn.rshi w30, w30, w31 >> 243 /* 0...0 11111111110000000000000 */
  bn.addi w30, w30, 1 

  /* w29 = q << 41 */
  bn.rshi w29, w30, w31 >> 215 /* 23 + 192 */

  /* w28 = 1/q << (64 + 22 = 86) */
  la x2, one_over_q
  li x3, 28
  bn.lid x3, 0(x2)
  
  /* w27, w26 */
  bn.addi w27, w31, 1 
  bn.rshi w26, w27, w31 >> 193 /* w26 = 2**63 */
  bn.rshi w27, w27, w31 >> 192 /* w27 = 2**64 */

  bn.xor w24, w24, w24 /* sneeze carries */

  li x23, 23  /* current number register index (w23) */
  li x25, 25 /* output buffer index (w25) */

  loopi 8, 21 /* for every 256-bit word (8 in a number) */
    li   x2, 0 
    addi x3, x24, 0

    loopi 8, 2 /* load next 256-bit word from each of the 8 numbers */
      bn.lid x2++, 0(x3)
      addi x3, x3, 288

    loopi 4, 14 /* for every 64-bit limb in a 256-bit word */
      li x2, 0

      loopi 8, 10 /* for every number's curent 64-bit limb */

        /* move current limb to last 64 bits of w23 and remove it from the word that held it */

        bn.movr x23, x2  
        bn.mov  w10, w23
        bn.rshi w23, w31, w23 >> 64
        bn.movr x2, x23 /* remove the current 64 bit chunk */
        bn.rshi w23, w10, w31 >> 64
        bn.rshi w23, w31, w23 >> 192 /* last 64 bits of w23 contain the number */

        jal x1, step7_sneeze
        jal x1, step7_reduce_modulo_q

        bn.rshi w25, w23, w25 >> 32 /* add the result to a 256-bit buffer to be written */
        addi x2, x2, 1

      bn.sid x25, 0(x21++) /* write the buffer */
      bn.rshi w24, w31, w24 >> 248 /* the new 8 carries need to be moved from top bits to the low bits */
    
    addi x24, x24, 32 /* move to the next 256-bit word */

  /* Top most bit might be 1 and there might be carries. These values need to be subtracted from the coefficient that were first chunks in their numbers before reordering */

  li x2, 3
  la x21, output_polynomial

  bn.lid x0, 0(x21)

  loopi 8, 13
    bn.rshi w23, w0, w31 >> 32
    bn.rshi w23, w31, w23 >> 224 /* w23 = 32-bit chunk */

    bn.rshi w2, w24, w31 >> 1
    bn.rshi w2, w31, w2 >> 255 /* w2 = carry */
    bn.rshi w24, w31, w24 >> 1

    bn.lid x2++, 0(x24) /* w3 = last number (0 or 1) */
    addi x24, x24, 288  

    bn.add w2, w2, w3

    bn.cmp w23, w2 /* if w23 < w2 */
    bn.sel w3, w30, w31, c 
    bn.add w23, w23, w3 /* add q */

    bn.sub w23, w23, w2 /* subtract both carry and last number, the result will be < q and >= 0 */
    bn.rshi w0, w23, w0 >> 32

  bn.sid x0, 0(x21)

  ret

  
  step7_sneeze:

    bn.rshi w10, w24, w31 >> 1 /* get next carry from previous 64-bit chunk */
    bn.rshi w10, w31, w10 >> 255

    bn.add w23, w23, w10 /* add carry */

    /* if w23 > 2 ** (l - 1) we need to subtract 2**l from w23. If w23 < 2**l then subtracting 2**l will result in a negative number and one needs to deal with the burrow. In this case one can add a multiple of q (that won't change the result modulo q) such that w23 becomes larger than 2**l and then subtract 2**l. We want though that the result is smaller than 2**l such that it can be represented on 64 bits such that the modulo reduction works (it requires the number to be reduced to be of at most 64 bits). 
    
    Need to implement:
    
    w29 = multiple of q such that w23 becomes > 2**l but < 2**(l+1)

    if w23 > 2**(l-1)
      if w23 > 2**l
        w23 -= 2**l
      else
        w23 = w23 + w29 - 2**l

    We implement it as:

    w10 = 2**l if w23 > 2**(l-1) else w29

    if w23 < 2**l
      w23 +=  w29

    w23 -= w10

    Note that in the case that w23 < 2**(l-1) the value of w29 is still added. This wouldn't be a problem if adding it the result would stay under 2**l (64 bits), but this is not always the case. It therefore needs to be subtracted.
    */

    bn.cmp w26, w23 /* if 2**(l-1) < w23 */
    bn.sel w10, w27, w29, c /* need to subtract 2**l */
    /* else subtract w29 because you will add it and the value would be too large for 64 bits */

    bn.cmp w23, w27 /* if w23 < 2**l subtracting 2**l will result in a negative number */
    bn.sel w12, w29, w31, c 
    
    bn.add w23, w23, w12 /* add a multiple of q such that the number becomes larger than 2**l but smaller than 2**(l+1) */
    bn.sub w23, w23, w10 /* subtract 2**l or w29 from w23 */

    bn.rshi w10, w31, w10 >> 64 /* carry for the next step */
    bn.rshi w24, w10, w24 >> 1 /* remove last carry for current number and add the new one */

    ret

  step7_reduce_modulo_q:
    /*
      Modulo reduces the 64-bit number in w23 by q.

      Modulo reduction via reciprocal multiplication
      Following: https://homepage.divms.uiowa.edu/%7Ejones/bcd/divide.html
      
      Compute w23 - q * ((n * (1/q << 86)) >> 86)

      In fixed-point representation:
      1/q = 
      1.1932580443192743e-07 =
      .0000000000000000000000100000000010000000000111000000011000000001010010000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 (256 bits)

      1/q << (64 + 22 = 86) =
      1000000000100000000001110000000110000000010100100001000000000000 (64 bits)

      Assumes:
        w23.0 = number to be reduced
        w10.U = 0
        w30.0 = q
        w28.0 = 1/q << (64 + 22 = 86)
    */
    
    /* w10 = (w23 * (1/q << 86)) >> 86 */

    bn.mulqacc.so.z w10.L, w23.0, w28.0, 0
    bn.rshi w10, w31, w10 >> 86

    /* only the lowest 64 bits of w10 can be different than 0 */

    /* w10 = n - q * w10 */
    bn.mulqacc.so.z w10.L, w30.0, w10.0, 0
    bn.sub w23, w23, w10

    ret
    
    
run: /* run all steps */

.section .text.start

  bn.xor w31, w31, w31

  jal x1, step1
  jal x1, step2
  jal x1, step3
  jal x1, step4
  jal x1, step5
  jal x1, step6
  jal x1, step7

/* 
  li x27, 0
  la x26, output_polynomial
  
  loopi 32, 2
    bn.lid x27++, 0(x26)
    addi x26, x26, 32

  li x27, 0
  la x26, intermediate_polynomial1

  jal x1, load_number
  jal x1, load_number
  jal x1, load_number


  */


  ecall

.section .data
one_over_q:
  .quad 0x8020070180521000
  .quad 0x0
  .quad 0x0
  .quad 0x0

input_polynomial1:
  .word 0x006c1603
  .word 0x00314fb7
  .word 0x006104a6
  .word 0x0071f383
  .word 0x0035d54a
  .word 0x00052e97
  .word 0x0021242f
  .word 0x007b945a
  .word 0x00417173
  .word 0x003e32e0
  .word 0x0033d4e1
  .word 0x007588b3
  .word 0x00645383
  .word 0x006a389e
  .word 0x0026d2f3
  .word 0x007be0de
  .word 0x003d0121
  .word 0x002dd48f
  .word 0x004aac43
  .word 0x007221ef
  .word 0x00743d0b
  .word 0x001bf5ee
  .word 0x00409994
  .word 0x0011d3b8
  .word 0x00241343
  .word 0x0011e330
  .word 0x0060be31
  .word 0x000c236a
  .word 0x004f26b7
  .word 0x006652d2
  .word 0x00201097
  .word 0x007e5e82
  .word 0x00747290
  .word 0x00442b0b
  .word 0x007dcbea
  .word 0x005a4315
  .word 0x0067b532
  .word 0x004d0b20
  .word 0x00737a2c
  .word 0x0012cfa1
  .word 0x0027b2ea
  .word 0x000ca446
  .word 0x005d6b20
  .word 0x00097064
  .word 0x00730d22
  .word 0x006cdc53
  .word 0x00578cc9
  .word 0x002a43e7
  .word 0x003c6f2c
  .word 0x0047a7f9
  .word 0x000ce3c6
  .word 0x002d4908
  .word 0x003792f1
  .word 0x00287922
  .word 0x004e318b
  .word 0x0051f964
  .word 0x0074dd8b
  .word 0x001a2c53
  .word 0x007bb9c1
  .word 0x0046b918
  .word 0x003d0ea8
  .word 0x0038aa2d
  .word 0x006ec279
  .word 0x0042bbb7
  .word 0x002157cf
  .word 0x0007f8c7
  .word 0x00670b26
  .word 0x00759041
  .word 0x00463bc7
  .word 0x00753f4e
  .word 0x0001cc1e
  .word 0x000bf055
  .word 0x005c1f48
  .word 0x006b881b
  .word 0x00330ca6
  .word 0x005ae995
  .word 0x00699485
  .word 0x00647c71
  .word 0x0055860b
  .word 0x005008b5
  .word 0x00002572
  .word 0x004e52a4
  .word 0x003f2d8f
  .word 0x0069fdfa
  .word 0x006f0d9b
  .word 0x002aa42c
  .word 0x001f3878
  .word 0x005d79c4
  .word 0x0029a04b
  .word 0x005a10f5
  .word 0x006f6b99
  .word 0x00080fde
  .word 0x001874e2
  .word 0x007560e0
  .word 0x0048a431
  .word 0x001c60cb
  .word 0x001e8af7
  .word 0x0066d402
  .word 0x007bd85b
  .word 0x00123d41
  .word 0x0066ce95
  .word 0x004580b1
  .word 0x00395711
  .word 0x000bacf6
  .word 0x000a4c0c
  .word 0x007f21e2
  .word 0x0028f78c
  .word 0x007002dc
  .word 0x00410432
  .word 0x007fbd88
  .word 0x00776719
  .word 0x003ea0f3
  .word 0x000df59b
  .word 0x002695ce
  .word 0x00468fec
  .word 0x00254275
  .word 0x005a709a
  .word 0x000ff9cc
  .word 0x0046128b
  .word 0x002a9791
  .word 0x00684073
  .word 0x00760c47
  .word 0x00452803
  .word 0x001a0284
  .word 0x007b5f0f
  .word 0x006653a0
  .word 0x004d352f
  .word 0x00460ba2
  .word 0x004b3709
  .word 0x0024d1f4
  .word 0x0038f566
  .word 0x000bba99
  .word 0x004c5320
  .word 0x006622bc
  .word 0x00314470
  .word 0x002894fd
  .word 0x0049aeee
  .word 0x001efd5e
  .word 0x00252984
  .word 0x00178902
  .word 0x00183df9
  .word 0x006925d6
  .word 0x0017e6c0
  .word 0x00043870
  .word 0x004e6f59
  .word 0x007d9b3a
  .word 0x00540d6a
  .word 0x00214985
  .word 0x003cfef7
  .word 0x0008d7c9
  .word 0x000b7f5d
  .word 0x0056e06d
  .word 0x0060f92a
  .word 0x0010ab31
  .word 0x00703a02
  .word 0x00132477
  .word 0x00763159
  .word 0x0004f234
  .word 0x006bd5bc
  .word 0x000a4593
  .word 0x0072f756
  .word 0x00598368
  .word 0x00762790
  .word 0x006a287f
  .word 0x00453260
  .word 0x00577ce0
  .word 0x003215fd
  .word 0x006b3f2a
  .word 0x005a46b9
  .word 0x0043253d
  .word 0x002347fa
  .word 0x0042ca04
  .word 0x0067e373
  .word 0x001e24eb
  .word 0x006cbbf4
  .word 0x001b8bb7
  .word 0x007290a3
  .word 0x0056f904
  .word 0x004b7e9a
  .word 0x0069a23a
  .word 0x007991e5
  .word 0x0035afa9
  .word 0x004a3372
  .word 0x00233a1b
  .word 0x0039ac0d
  .word 0x003f0f54
  .word 0x005482eb
  .word 0x005212bc
  .word 0x007f8560
  .word 0x0059a0fd
  .word 0x00755e54
  .word 0x007dc143
  .word 0x00658bad
  .word 0x002dbe38
  .word 0x000a8b32
  .word 0x00298379
  .word 0x004e6fad
  .word 0x000ec3c7
  .word 0x003e43cd
  .word 0x004b2543
  .word 0x0050a8ab
  .word 0x002aea24
  .word 0x006c2b80
  .word 0x00185e55
  .word 0x001f1bca
  .word 0x00021323
  .word 0x005da170
  .word 0x0022b15f
  .word 0x000efe41
  .word 0x005a485b
  .word 0x001c380d
  .word 0x002f9fab
  .word 0x0065b4e5
  .word 0x0015d258
  .word 0x002a908b
  .word 0x00368b77
  .word 0x00686fd7
  .word 0x0007f5ec
  .word 0x000ce0b5
  .word 0x00643d3a
  .word 0x0012bbdf
  .word 0x006d7b36
  .word 0x00594d45
  .word 0x001c00c5
  .word 0x0005ca3a
  .word 0x00689765
  .word 0x00497471
  .word 0x00512dac
  .word 0x00747b67
  .word 0x0077dfe0
  .word 0x00446099
  .word 0x004d13ec
  .word 0x00571d8b
  .word 0x000978ba
  .word 0x00036acc
  .word 0x000fedc5
  .word 0x005147ad
  .word 0x00182171
  .word 0x004d9c7f
  .word 0x006a4043
  .word 0x0049b8d3
  .word 0x000f522e
  .word 0x00321326
  .word 0x000bb750
  .word 0x002f60be
  .word 0x006abb6a
  .word 0x007d8191
  .word 0x000eda99
  .word 0x0004a87e
  .word 0x004d8129
  .word 0x0002c4fc
  .word 0x0018e85b
  .word 0x007b0312
  .word 0x007c3fa1
  .word 0x0017ad29
  .word 0x005beb23

.balign 32
input_polynomial2:
  .word 0x000fdbcb
  .word 0x003d5787
  .word 0x001af42b
  .word 0x005d136c
  .word 0x00667edd
  .word 0x0007d1a1
  .word 0x0077ee9a
  .word 0x0056f4d9
  .word 0x0002ea8a
  .word 0x0045a981
  .word 0x00367aad
  .word 0x004f6fd1
  .word 0x000cfdf5
  .word 0x006afedb
  .word 0x0021450e
  .word 0x0008f5e6
  .word 0x001c4422
  .word 0x0009365e
  .word 0x0052ce76
  .word 0x0026892f
  .word 0x002cd66e
  .word 0x0037d118
  .word 0x001714a8
  .word 0x0007d03d
  .word 0x00407729
  .word 0x003bcaf4
  .word 0x00050a5c
  .word 0x004c599e
  .word 0x000ceafc
  .word 0x0059836b
  .word 0x007e7e7d
  .word 0x00321556
  .word 0x0019847d
  .word 0x00214c0b
  .word 0x002de523
  .word 0x0073c355
  .word 0x005da503
  .word 0x003c300b
  .word 0x006b4e48
  .word 0x00737eb4
  .word 0x007590d1
  .word 0x0048ee2c
  .word 0x0015afb4
  .word 0x00594e23
  .word 0x00561916
  .word 0x001a097e
  .word 0x007bb7df
  .word 0x00623878
  .word 0x00076e36
  .word 0x0064f26d
  .word 0x00568dc7
  .word 0x0014402e
  .word 0x006c36df
  .word 0x0014bae9
  .word 0x002bd0e5
  .word 0x0043c5cf
  .word 0x00201685
  .word 0x000f00d4
  .word 0x004c63a9
  .word 0x0075f109
  .word 0x00389dbf
  .word 0x00553292
  .word 0x0016607c
  .word 0x0001b0a9
  .word 0x003c5e38
  .word 0x00573434
  .word 0x003477c7
  .word 0x00733669
  .word 0x0048d8af
  .word 0x006ff999
  .word 0x004119cf
  .word 0x00757101
  .word 0x0027dd76
  .word 0x00531040
  .word 0x002db725
  .word 0x0031bf07
  .word 0x006b387b
  .word 0x00542cc4
  .word 0x00201e8f
  .word 0x0013a307
  .word 0x0047c1bf
  .word 0x00586ce1
  .word 0x00019783
  .word 0x003a9e3e
  .word 0x005eebe8
  .word 0x000a1f17
  .word 0x002aff50
  .word 0x005e9814
  .word 0x0005d961
  .word 0x0045ac42
  .word 0x0023f3fa
  .word 0x0011425b
  .word 0x001ebc97
  .word 0x00618ead
  .word 0x007a0024
  .word 0x003dac82
  .word 0x002d15ba
  .word 0x004e18ec
  .word 0x0024d92e
  .word 0x00563215
  .word 0x002dfa4e
  .word 0x004b8e38
  .word 0x00793435
  .word 0x00722b34
  .word 0x00511ea6
  .word 0x006d487a
  .word 0x004f7f72
  .word 0x0010f0a8
  .word 0x005b996a
  .word 0x0027b7d4
  .word 0x0031aa8c
  .word 0x005fce62
  .word 0x00350ba6
  .word 0x006a197c
  .word 0x00534e7d
  .word 0x000a5522
  .word 0x000031f2
  .word 0x004c1b18
  .word 0x00189d99
  .word 0x00596b28
  .word 0x002acdac
  .word 0x00147d7e
  .word 0x001ea52e
  .word 0x001c8e78
  .word 0x0051964d
  .word 0x00395c7f
  .word 0x0030778a
  .word 0x005aecbf
  .word 0x00700ddf
  .word 0x00563e44
  .word 0x0048b92f
  .word 0x006ff0d9
  .word 0x00350b44
  .word 0x000409ae
  .word 0x00337d7c
  .word 0x006f937a
  .word 0x0059d58d
  .word 0x0048a2ef
  .word 0x00358872
  .word 0x0062d6fb
  .word 0x0054c2d5
  .word 0x005ac0b5
  .word 0x0005fce0
  .word 0x001534d6
  .word 0x0039014c
  .word 0x00082d6d
  .word 0x00212e59
  .word 0x0059cb48
  .word 0x00142f12
  .word 0x0039227a
  .word 0x00438784
  .word 0x007145e4
  .word 0x003e5eb8
  .word 0x00743aa6
  .word 0x0047dc1d
  .word 0x004d4f21
  .word 0x0060b3b9
  .word 0x00000244
  .word 0x007122d2
  .word 0x0004fb02
  .word 0x003f4e7c
  .word 0x0029b887
  .word 0x0027f186
  .word 0x006b3af5
  .word 0x003bc31f
  .word 0x000661b6
  .word 0x00678ed0
  .word 0x00694ee2
  .word 0x00700088
  .word 0x007cb1d3
  .word 0x0067fd36
  .word 0x00352339
  .word 0x0018106d
  .word 0x00463748
  .word 0x007b44d2
  .word 0x0051090d
  .word 0x007d41d6
  .word 0x000aaf0c
  .word 0x006b3182
  .word 0x005cdef7
  .word 0x0010b4ef
  .word 0x007e502a
  .word 0x0001e2a6
  .word 0x00336ebb
  .word 0x00798ac6
  .word 0x0056d994
  .word 0x00357026
  .word 0x0028787e
  .word 0x00006f2c
  .word 0x001b54c6
  .word 0x0001d44c
  .word 0x005bd147
  .word 0x00609bc5
  .word 0x00004d40
  .word 0x007d78a8
  .word 0x00694f43
  .word 0x00567f5d
  .word 0x0043a0d7
  .word 0x004e580b
  .word 0x000c8432
  .word 0x001860fd
  .word 0x000f383e
  .word 0x004ddeba
  .word 0x00531b21
  .word 0x001968fc
  .word 0x006fd3e3
  .word 0x0026b591
  .word 0x0023d679
  .word 0x00582214
  .word 0x007d3ffc
  .word 0x00175305
  .word 0x000cd2b8
  .word 0x003ce0a3
  .word 0x006d4dd8
  .word 0x00761d51
  .word 0x0032c6f0
  .word 0x0050567a
  .word 0x000a6986
  .word 0x0002cbd5
  .word 0x002329d2
  .word 0x0074fa0e
  .word 0x0039fb30
  .word 0x006660a6
  .word 0x00656b72
  .word 0x000ed1db
  .word 0x006e410a
  .word 0x0020d49f
  .word 0x001113ec
  .word 0x0053a815
  .word 0x0042abb8
  .word 0x00689c68
  .word 0x00534cdd
  .word 0x00528d6a
  .word 0x002c6c3b
  .word 0x000ebbe7
  .word 0x006f993b
  .word 0x0013c4b1
  .word 0x0023a2ee
  .word 0x006cf56c
  .word 0x000260a4
  .word 0x00056a02
  .word 0x00053474
  .word 0x001a558c
  .word 0x00572ae6
  .word 0x00213cd8
  .word 0x00477833
  .word 0x00284885
  .word 0x007926fe
  .word 0x002ef660
  .word 0x00781ec3
  .word 0x0048a2c8
  .word 0x00747600
  .word 0x006cba60
  .word 0x00056067
  .word 0x006c5585
  .word 0x005fe3a6


intermediate_polynomial1:
  .zero 2304 /* 8 numbers * 9 WDR * 256 bits / 8 to express in bytes */
intermediate_polynomial2:
  .zero 2304 /* 8 numbers * 9 WDR * 256 bits / 8 to express in bytes */
output_polynomial:
  .zero 1024 /* 256 numbers * 32 bits / 8 to express in bytes */