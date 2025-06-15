// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

struct Account {
    bytes32 publicKey;
    bool isWritable;
}

struct Input {
    Account[] accounts;
    bytes data;
}

library AccountEncoder {
    function encodeInput(Account[] memory accounts, bytes memory data) internal pure returns (bytes memory) {
        return abi.encode(Input(accounts, data));
    }

    function decompressAccounts(bytes memory input) internal pure returns (Account[] memory accounts) {
        assembly { // 这里的decompress和上面的encodeInput不匹配啊
            let ptr := add(input, 32)

            // Read accounts length (uint16)
            let len := add(shl(8, byte(0, mload(ptr))), byte(1, mload(ptr)))
            ptr := add(ptr, 2)

            // Allocate memory for Account[] array
            accounts := mload(0x40)
            mstore(accounts, len)
            let arrData := add(accounts, 32)

            // Prepare memory for Account structs
            let freePtr := add(arrData, mul(len, 32))

            for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                let acc := freePtr
                freePtr := add(freePtr, 64)

                // Load publicKey
                mstore(acc, mload(ptr))
                ptr := add(ptr, 32)

                // Load isWritable (as bool)
                mstore(add(acc, 32), iszero(iszero(mload(ptr))))
                ptr := add(ptr, 1)

                // Store pointer to struct in the array
                mstore(add(arrData, mul(i, 32)), acc)
            }

            mstore(0x40, freePtr)
        }
    }
}