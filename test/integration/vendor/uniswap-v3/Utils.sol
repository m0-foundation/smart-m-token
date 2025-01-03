// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

uint256 constant PRECISION = 2 ** 96;

library Utils {
    function encodePriceSqrt(uint256 reserve1, uint256 reserve0) internal pure returns (uint160) {
        return uint160(sqrt((reserve1 * PRECISION * PRECISION) / reserve0));
    }

    function sqrt(uint256 x) internal pure returns (uint256 z) {
        assembly {
            z := 1

            let y := x

            if iszero(lt(y, 0x100000000000000000000000000000000)) {
                y := shr(128, y)
                z := shl(64, z)
            }
            if iszero(lt(y, 0x10000000000000000)) {
                y := shr(64, y)
                z := shl(32, z)
            }
            if iszero(lt(y, 0x100000000)) {
                y := shr(32, y)
                z := shl(16, z)
            }
            if iszero(lt(y, 0x10000)) {
                y := shr(16, y)
                z := shl(8, z)
            }
            if iszero(lt(y, 0x100)) {
                y := shr(8, y)
                z := shl(4, z)
            }
            if iszero(lt(y, 0x10)) {
                y := shr(4, y)
                z := shl(2, z)
            }
            if iszero(lt(y, 0x8)) {
                z := shl(1, z)
            }

            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            let zRoundDown := div(x, z)

            if lt(zRoundDown, z) {
                z := zRoundDown
            }
        }
    }
}
