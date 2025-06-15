// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import {BytesHelperLib} from "./BytesHelperLib.sol";

struct MixSwapParams {
    address fromToken;
    address toToken;
    uint256 fromTokenAmount;
    uint256 expReturnAmount;
    uint256 minReturnAmount;
    address[] mixAdapters;
    address[] mixPairs;
    address[] assetTo;
    uint256 directions;
    bytes[] moreInfo;
    bytes feeData;
    uint256 deadline;
}

struct DecodedNativeMessage {
    address targetZRC20;
    bytes sender;
    bytes receiver;
    bytes swapData;
}

struct DecodedMessage {
    address targetZRC20;
    uint32 dstChainId;
    bytes sender;
    bytes receiver; // compatible for btc/sol/evm
    bytes swapDataZ;
    bytes contractAddress; // empty for withdraw, non-empty for withdrawAndCall
    bytes swapDataB;
    bytes accounts;
}

library SwapDataHelperLib {
    function buildOutputMessage(
        bytes32 externalId,
        uint256 outputAmount,
        bytes memory receiver,
        bytes memory swapDataB
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            externalId,
            bytes32(outputAmount),
            uint16(receiver.length),
            uint16(swapDataB.length),
            receiver,
            swapDataB
        );
    }

    function decodeMessage(
        bytes calldata message
    ) internal pure returns (DecodedMessage memory, MixSwapParams memory) {
        uint32 dstChainId;
        address targetZRC20;
        uint16 senderLen;
        uint16 receiverLen;
        uint16 swapDataZLen;
        uint16 contractAddressLen;
        uint16 swapDataBLen;
        uint16 accountsLen;

        assembly {
            dstChainId := shr(224, calldataload(message.offset)) // 4 bytes
            targetZRC20 := shr(96, calldataload(add(message.offset, 4))) // 20 bytes
            senderLen := shr(240, calldataload(add(message.offset, 24))) // 2 bytes
            receiverLen := shr(240, calldataload(add(message.offset, 26))) // 2 bytes
            swapDataZLen := shr(240, calldataload(add(message.offset, 28))) // 2 bytes
            contractAddressLen := shr(240, calldataload(add(message.offset, 30))) // 2 bytes
            swapDataBLen := shr(240, calldataload(add(message.offset, 32))) // 2 bytes
            accountsLen := shr(240, calldataload(add(message.offset, 34))) // 2 bytes
        }

        uint offset = 36;
        bytes calldata sender = message[offset : offset + senderLen];
        offset += senderLen;

        bytes calldata receiver = message[offset : offset + receiverLen];
        offset += receiverLen;

        bytes calldata swapDataZ = message[offset : offset + swapDataZLen];
        offset += swapDataZLen;

        bytes calldata contractAddress = message[offset : offset + contractAddressLen];
        offset += contractAddressLen;

        bytes calldata swapDataB = message[offset : offset + swapDataBLen];
        offset += swapDataBLen;

        bytes calldata accounts = message[offset : offset + accountsLen];

        DecodedMessage memory decoded = DecodedMessage({
            dstChainId: dstChainId,
            targetZRC20: targetZRC20,
            sender: sender,
            receiver: receiver,
            contractAddress: contractAddress,
            swapDataZ: swapDataZ,
            swapDataB: swapDataB,
            accounts: accounts
        });

        MixSwapParams memory params = decodeCompressedMixSwapParams(swapDataZ);
        return (decoded, params);
    }

    function decodeNativeMessage(
        bytes calldata message
    ) internal pure returns (DecodedNativeMessage memory, MixSwapParams memory) {
        address targetZRC20 = BytesHelperLib.bytesToAddress(message, 0); // 20 bytes
        uint offset = 20;

        uint16 senderLen;
        uint16 receiverLen;

        assembly {
            senderLen := shr(240, calldataload(add(message.offset, offset)))         // offset + 0
            receiverLen := shr(240, calldataload(add(message.offset, add(offset, 2)))) // offset + 2
        }

        offset += 4; // advance past both lengths
        bytes memory sender = message[offset : offset + senderLen];
        offset += senderLen;
        bytes memory receiver = message[offset : offset + receiverLen];
        offset += receiverLen;
        bytes calldata swapData = message[offset:];

        DecodedNativeMessage memory decoded = DecodedNativeMessage({
            targetZRC20: targetZRC20,
            sender: sender,
            receiver: receiver,
            swapData: swapData
        });

        MixSwapParams memory params = decodeCompressedMixSwapParams(swapData);
        return (decoded, params);
    }

    function decodeCompressedMixSwapParams(bytes calldata data) internal pure returns (MixSwapParams memory) {
        if (data.length == 0) {
            return MixSwapParams({
                fromToken: address(0),
                toToken: address(0),
                fromTokenAmount: 0,
                expReturnAmount: 0,
                minReturnAmount: 0,
                mixAdapters: new address[](1),
                mixPairs: new address[](1),
                assetTo: new address[](1),
                directions: 0,
                moreInfo: new bytes[](1),
                feeData: new bytes(0),
                deadline: 0
            });
        }

        unchecked {
            uint offset = 0;
            address fromToken;
            address toToken;
            uint256 fromTokenAmount;
            uint256 expReturnAmount;
            uint256 minReturnAmount;
            uint256 directions;
            uint256 deadline;

            assembly {
                fromToken := shr(96, calldataload(add(data.offset, offset)))
                offset := add(offset, 20)
                toToken := shr(96, calldataload(add(data.offset, offset)))
                offset := add(offset, 20)
                fromTokenAmount := calldataload(add(data.offset, offset))
                offset := add(offset, 32)
                expReturnAmount := calldataload(add(data.offset, offset))
                offset := add(offset, 32)
                minReturnAmount := calldataload(add(data.offset, offset))
                offset := add(offset, 32)
                directions := calldataload(add(data.offset, offset))
                offset := add(offset, 32)
                deadline := calldataload(add(data.offset, offset))
                offset := add(offset, 32)
            }

            // mixAdapters
            uint8 adapterLen = uint8(data[offset]);
            offset += 1;
            address[] memory mixAdapters = new address[](adapterLen);
            for (uint i = 0; i < adapterLen; ++i) {
                address a;
                assembly {
                    a := shr(96, calldataload(add(data.offset, offset)))
                }
                mixAdapters[i] = a;
                offset += 20;
            }

            // mixPairs
            uint8 pairLen = uint8(data[offset]);
            offset += 1;
            address[] memory mixPairs = new address[](pairLen);
            for (uint i = 0; i < pairLen; ++i) {
                address p;
                assembly {
                    p := shr(96, calldataload(add(data.offset, offset)))
                }
                mixPairs[i] = p;
                offset += 20;
            }

            // assetTo
            uint8 toLen = uint8(data[offset]);
            offset += 1;
            address[] memory assetTo = new address[](toLen);
            for (uint i = 0; i < toLen; ++i) {
                address t;
                assembly {
                    t := shr(96, calldataload(add(data.offset, offset)))
                }
                assetTo[i] = t;
                offset += 20;
            }

            // moreInfo lengths
            uint8 infoCount = uint8(data[offset]);
            offset += 1;
            uint16[] memory lens = new uint16[](infoCount);
            for (uint i = 0; i < infoCount; ++i) {
                uint16 l;
                assembly {
                    l := shr(240, calldataload(add(data.offset, offset)))
                }
                lens[i] = l;
                offset += 2;
            }

            // moreInfo contents
            bytes[] memory moreInfo = new bytes[](infoCount);
            for (uint i = 0; i < infoCount; ++i) {
                moreInfo[i] = data[offset : offset + lens[i]];
                offset += lens[i];
            }

            // feeData
            uint16 feeLen;
            assembly {
                feeLen := shr(240, calldataload(add(data.offset, offset)))
            }
            offset += 2;
            bytes memory feeData = data[offset : offset + feeLen];

            return MixSwapParams({
                fromToken: fromToken,
                toToken: toToken,
                fromTokenAmount: fromTokenAmount,
                expReturnAmount: expReturnAmount,
                minReturnAmount: minReturnAmount,
                mixAdapters: mixAdapters,
                mixPairs: mixPairs,
                assetTo: assetTo,
                directions: directions,
                moreInfo: moreInfo,
                feeData: feeData,
                deadline: deadline
            });
        }
    }

}
