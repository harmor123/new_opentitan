.section .text.start
.globl _start

_start:
  /* ------------------------------------------------------------
   * Initialize OTBN software environment.
   * ------------------------------------------------------------ */

  la   x2, stack
  addi x2, x2, 128

  bn.xor w31, w31, w31

  /* ------------------------------------------------------------
   * HMAC-SHA3-256 standalone profiling
   *
   * key     = hmac_key_hashed (32 B)
   * message = ikm_buf         (65 B)
   * output  = output_okm
   *
   * This corresponds to the HMAC invocation inside HKDF-Expand.
   * Message contents do not affect the control flow; only the
   * fixed message length (65 B) matters for this profiling run.
   * ------------------------------------------------------------ */

  la   x10, hmac_key_hashed
  li   x11, 32

  la   x12, ikm_buf
  li   x13, 65

  la   x14, output_okm

  jal  x1, hmac_sha3_256

  ecall

/* ================================================================
 * DMEM（ibex和otbn共享的DMEM）
 * ================================================================ */
.section .data
/* -------------------- HKDF external inputs ---------------------- */
.balign 32
.globl input_salt
input_salt:
  .zero 32

.balign 32

.globl ikm_prebuilt
ikm_prebuilt:
  .zero 64

.balign 32

.globl input_info
input_info:
  .zero 64

/* -------------------- HKDF outputs ------------------------------ */

.balign 32
.globl hmac_key_hashed
hmac_key_hashed:
  /* Used as the HKDF PRK. */
  .zero 32

.balign 32
.globl output_okm
output_okm:
  .zero 32


/* -------------------- HKDF temporary buffer --------------------- */

.balign 32
.globl ikm_buf
ikm_buf:
  /*
   * Expand message:
   *
   *   info || 0x01
   *
   * 64 + 1 bytes are logically used.
   * We allocate 96B to keep alignment/simple bounds.
   */
  .zero 96

/* -------------------- HMAC working memory ----------------------- */

.balign 32

.globl hmac_ipad
hmac_ipad:
  /*
   * SHA3-256 HMAC block size = 136B.
   * Allocate 160B for convenient alignment.
   */
  .zero 160


.balign 32

.globl hmac_opad
hmac_opad:
  .zero 160


.balign 32

.globl hmac_inner
hmac_inner:
  .zero 32


/* -------------------- SHA3 context ------------------------------ */

.balign 32

.globl context
context:
  /*
   * SHA3 logical context = 212B.
   *
   * The OpenTitan keccak implementation performs aligned WDR
   * accesses around this state, so reserve 224B.
   */
  .zero 224


/* -------------------- Keccak round constants -------------------- */

.balign 32

.globl rc
rc:

  /* Round 0 */
  .dword 0x0000000000000001
  .dword 0
  .dword 0
  .dword 0

  /* Round 1 */
  .dword 0x0000000000008082
  .dword 0
  .dword 0
  .dword 0

  /* Round 2 */
  .dword 0x800000000000808a
  .dword 0
  .dword 0
  .dword 0

  /* Round 3 */
  .dword 0x8000000080008000
  .dword 0
  .dword 0
  .dword 0

  /* Round 4 */
  .dword 0x000000000000808b
  .dword 0
  .dword 0
  .dword 0

  /* Round 5 */
  .dword 0x0000000080000001
  .dword 0
  .dword 0
  .dword 0

  /* Round 6 */
  .dword 0x8000000080008081
  .dword 0
  .dword 0
  .dword 0

  /* Round 7 */
  .dword 0x8000000000008009
  .dword 0
  .dword 0
  .dword 0

  /* Round 8 */
  .dword 0x000000000000008a
  .dword 0
  .dword 0
  .dword 0

  /* Round 9 */
  .dword 0x0000000000000088
  .dword 0
  .dword 0
  .dword 0

  /* Round 10 */
  .dword 0x0000000080008009
  .dword 0
  .dword 0
  .dword 0

  /* Round 11 */
  .dword 0x000000008000000a
  .dword 0
  .dword 0
  .dword 0

  /* Round 12 */
  .dword 0x000000008000808b
  .dword 0
  .dword 0
  .dword 0

  /* Round 13 */
  .dword 0x800000000000008b
  .dword 0
  .dword 0
  .dword 0

  /* Round 14 */
  .dword 0x8000000000008089
  .dword 0
  .dword 0
  .dword 0

  /* Round 15 */
  .dword 0x8000000000008003
  .dword 0
  .dword 0
  .dword 0

  /* Round 16 */
  .dword 0x8000000000008002
  .dword 0
  .dword 0
  .dword 0

  /* Round 17 */
  .dword 0x8000000000000080
  .dword 0
  .dword 0
  .dword 0

  /* Round 18 */
  .dword 0x000000000000800a
  .dword 0
  .dword 0
  .dword 0

  /* Round 19 */
  .dword 0x800000008000000a
  .dword 0
  .dword 0
  .dword 0

  /* Round 20 */
  .dword 0x8000000080008081
  .dword 0
  .dword 0
  .dword 0

  /* Round 21 */
  .dword 0x8000000000008080
  .dword 0
  .dword 0
  .dword 0

  /* Round 22 */
  .dword 0x0000000080000001
  .dword 0
  .dword 0
  .dword 0

  /* Round 23 */
  .dword 0x8000000080008008
  .dword 0
  .dword 0
  .dword 0


/* -------------------- Software stack ---------------------------- */

.balign 32
.globl stack
stack:
  .zero 128