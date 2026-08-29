/* Plain P-256 ECDH shared-key OTBN executable entry. */

.section .text.start

.globl _start

_start:
  jal x1, p256_shared_key_sw
  ecall
