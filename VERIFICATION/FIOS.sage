import math
import random

def FIOS(n, a, b, w = 17, WIDTH = 256):

	# WIDTH is taken to be the width of n and the operands plus 2
	# in order for intermediate results to be contained without
	# having to perform the final subtraction of the Montgomery Multiplication
	WIDTH = WIDTH + 2
	
	# s is the number of blocks of width w required to slice operands
	s = (WIDTH-1)//w + 1
	
	W = 2**w
	
	R = 2**(s*w)
	R_inv = inverse_mod(R, n)
	
	n_prime_0 = inverse_mod(-n, R) % W
	
	a_arr = [(a >> (i*w)) % W for i in range(s)]
	b_arr = [(b >> (i*w)) % W for i in range(s)]
	n_arr = [(n >> (i*w)) % W for i in range(s)]
	
	res_arr = s*[0]
	
	for i in range(s):
		
		# The outer loop scans the a operand.
		# the least significant block of the result is processed
		# and reduced at the beginning of each iterations
		
		res_arr[0] += a_arr[i]*b_arr[0]
		
		m = res_arr[0]*n_prime_0 % W
		
		res_arr[0] += m*n_arr[0]
		res_arr[0] = res_arr[0] >> w
		
		for j in range(1, s):
		
			# The inner loop scans the b operand.
			# The remaining blocks are processed in this loop.
		
			res_arr[j-1] += a_arr[i]*b_arr[j] + m*n_arr[j] + res_arr[j]
			
			res_arr[j] = res_arr[j-1] >> w
			res_arr[j-1] = res_arr[j-1] % W
			
	
	return res_arr, n_prime_0
	
	
if __name__ == "__main__":

	# Running this file will test one random set of inputs fed to the FIOS function

	n = random_prime(2**256, False, 2**255)
	
	print("WIDTH : 256")
	
	a = random.randrange(2**255, n)
	b = random.randrange(2**255, n)
	

	WIDTH = 512 + 2

	w = 17
	
	s = (WIDTH-1)//w + 1
	
#	n = 0x8cba21028152e595b8b01793ee84472585f0a543fa7de85a68c0c1b8db9fe639
#	a = 0x861316b423dc404e760dbb19bfd42a1828552113f567ee2c01a9b18a91d25da3
#	b = 0x8517a54436cc17d87f7adeee5b301c8e7d1a62df1c648a6fcee73d9fec912be8

#	n = 0xeee1ed40a843211b8b0a65ef4ae90150f3c56dc69928ce09be3cd7623563ac29
#	a = 0xc0b4849d498ac5c15685e0633c0d9936c255a02cb1264c97459d68e5ad64fdab
#	b = 0x8579e8fa6c923c4d3c132c133ccad0d4ec1efb675366fa827af8b5a1e5290fef	

	n = 0xcc32472162d40712025af5ba22d1c1f9436188d0eba6a9f42c3efd510c738446becff2f9472e6238ed9aca5a561a28b5cb90c18fdaad800319b22ec3b15aa0e7
	a = 0xa385d2c24c2d9025202261f1205c24e2263e2d51301efc7015b879696eba7c9e48ee5e63d9d1c0dde4db6074a7aa652bccc6341e1985666654512c72150b9281
	b = 0xaa33f1c947d83fdce7e52eac032612ff6d45aa442ae743cb98d0fbbc3defe0d82d6a2c58ca18f9f220c5064117f6b8c85bd6373bf530bfd1f4c40d6999087847

	R = 2**(s*w)
	R_inv = inverse_mod(R, n)
	

	verif = a*b*R_inv % n

	res_arr = FIOS(n, a, b, w, WIDTH = 512)[0]

	res = 0
	for i in range(len(res_arr)):
	
		res += res_arr[i] << (i*w)
		
	print("n : ", hex(n), "\na : ", hex(a), "\nb : ", hex(b))
	
	print("\ntest  : ", hex(res), "\nverif : ", hex(verif), "\nmatch : ", res == verif)
