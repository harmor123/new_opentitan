/* Copyright 2026 Hybrid KEM Project Authors. All rights reserved. */

/* Extendable-output function (XOF / SHAKE) and SHA3 hardware interface driver.
   Supports SHA3-256, SHA3-512, SHAKE128, SHAKE256 via OTBN ISPR interface. */

.globl sha3_256_init
.globl sha3_512_init
.globl xof_shake128_init
.globl xof_shake256_init
.globl xof_absorb
.globl xof_process
.globl xof_squeeze24
.globl xof_squeeze32
.globl xof_finish

/*
 * Reserved registers (x28-x30) — do not touch between init and finish:
 *   x28: Remaining 64-bit chunks in the KMAC rate buffer.
 *   x29: Total size of the rate buffer (64-bit chunks).
 *   x30: Timeout counter for polling routines.
 */

.set KMAC_POLL_MAX_ITERS, 1024

.set KMAC_SHA3_256_RATE, 17
.set KMAC_SHA3_512_RATE, 9
.set KMAC_SHAKE128_RATE, 21
.set KMAC_SHAKE256_RATE, 17

/* KMAC_CTRL commands */
.set KMAC_CTRL_START,   0x1
.set KMAC_CTRL_SEND,    0x2
.set KMAC_CTRL_PROCESS, 0x4
.set KMAC_CTRL_DONE,    0x8
.set KMAC_CTRL_CLOSE,   0x10

/* KMAC_STATUS masks */
.set KMAC_STATUS_READY_MASK,       0x1
.set KMAC_STATUS_RSP_VALID_MASK,   0x2
.set KMAC_STATUS_ERROR_MASK,       0x1c

.text

/**
 * Initialize the KMAC interface for SHA3-256.
 * EN_XOF=0, STRENGTH=L256(3'b010), MODE=AppSha3(2'b00).
 * KMAC_CFG = 0x003B0004
 */
sha3_256_init:
  li   x24, 0x3b0004
  addi x28, x0, KMAC_SHA3_256_RATE
  addi x29, x0, KMAC_SHA3_256_RATE
  jal  x0, _xof_shake_init

/**
 * Initialize the KMAC interface for SHA3-512.
 * EN_XOF=0, STRENGTH=L512(3'b100), MODE=AppSha3(2'b00).
 * KMAC_CFG = 0x00370008
 */
sha3_512_init:
  li   x24, 0x370008
  addi x28, x0, KMAC_SHA3_512_RATE
  addi x29, x0, KMAC_SHA3_512_RATE
  jal  x0, _xof_shake_init

/**
 * Initialize the KMAC interface for SHAKE128.
 * EN_XOF=1, STRENGTH=L128(3'b000), MODE=AppShake(2'b01).
 * KMAC_CFG = 0x002E0011
 */
xof_shake128_init:
  li   x24, 0x2e0011
  addi x28, x0, KMAC_SHAKE128_RATE
  addi x29, x0, KMAC_SHAKE128_RATE
  jal  x0, _xof_shake_init

/**
 * Initialize the KMAC interface for SHAKE256.
 * EN_XOF=1, STRENGTH=L256(3'b010), MODE=AppShake(2'b01).
 * KMAC_CFG = 0x002A0015
 */
xof_shake256_init:
  li   x24, 0x2a0015
  addi x28, x0, KMAC_SHAKE256_RATE
  addi x29, x0, KMAC_SHAKE256_RATE

_xof_shake_init:
  bn.xor w31, w31, w31
  addi x30, x0, KMAC_POLL_MAX_ITERS
  jal  x1, _xof_ready_poll
  csrrw x0, KMAC_CFG, x24
  addi x24, x0, KMAC_CTRL_START
  csrrs x0, KMAC_CTRL, x24
  ret

/**
 * Polling routines for the KMAC_STATUS register.
 */

_xof_ready_poll:
  bne  x30, x0, _xof_ready_poll_time_remaining
  unimp

_xof_ready_poll_time_remaining:
  addi x30, x30, -1
  csrrs x25, KMAC_STATUS, x0
  andi x25, x25, KMAC_STATUS_READY_MASK
  beq  x25, x0, _xof_ready_poll
  addi x30, x0, KMAC_POLL_MAX_ITERS
  ret

_xof_rsp_valid_poll:
  bne  x30, x0, _xof_rsp_valid_poll_time_remaining
  unimp

_xof_rsp_valid_poll_time_remaining:
  addi x30, x30, -1
  csrrs x25, KMAC_STATUS, x0
  andi x25, x25, KMAC_STATUS_RSP_VALID_MASK
  beq  x25, x0, _xof_rsp_valid_poll
  addi x30, x0, KMAC_POLL_MAX_ITERS
  ret

/**
 * Finish the KMAC session and release the hardware.
 * Must be called after xof_process.
 */
xof_finish:
  jal  x1, _xof_ready_poll
  addi x24, x0, KMAC_CTRL_DONE
  csrrs x0, KMAC_CTRL, x24
  jal  x1, _xof_rsp_valid_poll
  csrrs x24, KMAC_STATUS, x0
  andi x24, x24, KMAC_STATUS_ERROR_MASK
  addi x25, x0, KMAC_CTRL_CLOSE
  csrrs x0, KMAC_CTRL, x25
  beq  x24, x0, _xof_finish_success
  unimp

_xof_finish_success:
  ret

/**
 * Absorb a message of size n bytes.
 *
 * Supports both masked (two shares at DMEM[x21], DMEM[x22]) and unmasked
 * (message at DMEM[x21] and x22 = 0) input.
 *
 * @param[in] x20: n, size of the input message.
 * @param[in] x21: DMEM address of the 1st message share.
 * @param[in] x22: DMEM address of the 2nd message share (0 if unmasked)
 */
xof_absorb:
  beq  x20, x0, _xof_absorb_end
  jal  x1, _xof_ready_poll

  addi  x24, x20, -32
  srai  x25, x24, 31
  and   x25, x24, x25
  sub   x20, x24, x25
  sub   x24, x0, x25
  addi  x25, x0, -1
  srl   x24, x25, x24
  csrrw x0, KMAC_STRB, x24

  bne  x22, x0, _xof_absorb_masked_begin

  /* Unmasked path: S1 = 0 (w31) */
  addi x24, x0, 26
  bn.lid x24, 0(x21++)
  bn.wsrw KMAC_DATA_S0, w26
  bn.wsrw KMAC_DATA_S1, w31
  jal  x0, _xof_absorb_masked_end

_xof_absorb_masked_begin:
  addi x24, x0, 26
  bn.lid x24, 0(x21++)
  bn.wsrw KMAC_DATA_S0, w26
  addi x24, x0, 27
  bn.lid x24, 0(x22++)
  bn.wsrw KMAC_DATA_S1, w27

_xof_absorb_masked_end:
  addi x24, x0, KMAC_CTRL_SEND
  csrrw x0, KMAC_CTRL, x24
  jal  x0, xof_absorb

_xof_absorb_end:
  ret

/**
 * Send the PROCESS command and wait for the first digest response.
 * Checks the response for errors.
 */
xof_process:
  jal  x1, _xof_ready_poll
  addi x24, x0, KMAC_CTRL_PROCESS
  csrrs x0, KMAC_CTRL, x24
  jal  x1, _xof_rsp_valid_poll
  csrrs x24, KMAC_STATUS, x0
  andi x24, x24, KMAC_STATUS_ERROR_MASK
  bne  x24, x0, xof_finish
  ret

/**
 * Squeeze 32 masked bytes into w29 and w30.
 * Rate-buffer tracking with auto-RUN on exhaustion.
 *   @param[out] w29: S0 share (4 x 64-bit beats merged).
 *   @param[out] w30: S1 share (4 x 64-bit beats merged).
 *   Unmask: bn.xor w29, w29, w30
 */
xof_squeeze32:
  bn.xor w29, w29, w29
  bn.xor w30, w30, w30
  loopi 4, 8
    bne  x28, x0, _xof_squeeze32_recharge
    jal  x1, _xof_rsp_valid_poll
    addi x28, x29, 0

_xof_squeeze32_recharge:
    bn.wsrr w27, KMAC_DATA_S0
    bn.rshi w29, w27, w29 >> 64
    addi x28, x28, -1
    bn.wsrr w28, KMAC_DATA_S1
    bn.rshi w30, w28, w30 >> 64
  ret

/**
 * Squeeze 24 masked bytes into w29 and w30.
 * CAUTION: SHAKE128 only. Rate = 21 beats; 24B = 3 beats never crosses boundary.
 *   @param[out] w29: S0 share (3 x 64-bit beats merged).
 *   @param[out] w30: S1 share (3 x 64-bit beats merged).
 */
xof_squeeze24:
  bn.xor w29, w29, w29
  bn.xor w30, w30, w30
  bne  x28, x0, _xof_squeeze24_recharge
  jal  x1, _xof_rsp_valid_poll
  addi x28, x29, 0

_xof_squeeze24_recharge:
  loopi 3, 5
    bn.wsrr w27, KMAC_DATA_S0
    bn.rshi w29, w27, w29 >> 64
    addi x28, x28, -1
    bn.wsrr w28, KMAC_DATA_S1
    bn.rshi w30, w28, w30 >> 64

  bn.rshi w29, w27, w29 >> 64
  bn.xor w31, w31, w31 /* dummy */
  bn.rshi w30, w28, w30 >> 64
  ret
