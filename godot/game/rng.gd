## the game's random numbers, a 16-bit linear congruential generator.
class_name Rng
extends Mod


## random integer 0..n (inclusive); n = 0 returns 0 without advancing the generator
func random(n: int) -> int:
	n &= 0xff
	if n == 0:
		return 0
	st.rng_seed = (st.rng_seed * 0x3245 + 0x1b0d) & 0xffff
	return (st.rng_seed % (n + 1)) & 0xff
