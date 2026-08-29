/* Plain P-256 KeyGen OTBN executable entry. */

.section .text.start

.globl _start

_start:
  jal x1, p256_keygen_sw
  ecall
