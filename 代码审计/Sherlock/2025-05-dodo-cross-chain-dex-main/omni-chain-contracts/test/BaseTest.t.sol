// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {GatewayEVMMock} from "../contracts/mocks/GatewayEVMMock.sol";
import {GatewayZEVMMock} from "../contracts/mocks/GatewayZEVMMock.sol";
import {GatewaySend} from "../contracts/GatewaySend.sol";
import {GatewayCrossChain} from "../contracts/GatewayCrossChain.sol";
import {GatewayTransferNative} from "../contracts/GatewayTransferNative.sol";
import {ERC20Mock} from "../contracts/mocks/ERC20Mock.sol";
import {ZRC20Mock} from "../contracts/mocks/ZRC20Mock.sol";
import {DODORouteProxyMock} from "../contracts/mocks/DODORouteProxyMock.sol";
import {IUniswapV2Factory} from "../contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router01} from "../contracts/interfaces/IUniswapV2Router01.sol";


contract BaseTest is Test {
    address constant _ETH_ADDRESS_ = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant WZETA = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
    address public EddyTreasurySafe = address(0x123);
    address public user1 = address(0x111);
    address public user2 = address(0x222);
    address public bot = address(0x333);
    bytes public btcAddress = abi.encodePacked("tb1qy9pqmk2pd9sv63g27jt8r657wy0d9ueeh0nqur");
    bytes public solAddress = abi.encodePacked("DrexsvCMH9WWjgnjVbx1iFf3YZcKadupFmxnZLfSyotd");
    bytes public solGatewaySendAddress = abi.encodePacked("EwUjcjz8jvFeE99kjcZKM5Aojs3eKcyW2JHNKNDP9M4k");
    uint256 constant initialBalance = 1000 ether;
    IUniswapV2Factory factory = IUniswapV2Factory(0x9fd96203f7b22bCF72d9DCb40ff98302376cE09c);
    IUniswapV2Router01 router = IUniswapV2Router01(0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe);

    GatewayEVMMock public gatewayA; 
    GatewayEVMMock public gatewayB; 
    GatewayZEVMMock public gatewayZEVM; 
    GatewaySend public gatewaySendA;
    GatewaySend public gatewaySendB;
    GatewayCrossChain public gatewayCrossChain; // on zetachain
    GatewayTransferNative public gatewayTransferNative; // on zetachain
    ERC1967Proxy public sendProxyA; 
    ERC1967Proxy public sendProxyB;
    ERC1967Proxy public crossChainProxy;
    ERC1967Proxy public transferNativeProxy;
    ERC20Mock public token1A; 
    ERC20Mock public token2A;
    ZRC20Mock public token1Z;
    ZRC20Mock public token2Z;
    ZRC20Mock public token3Z; // for mapping A native token 
    ERC20Mock public token1B; 
    ERC20Mock public token2B;
    ERC20Mock public token3B;
    ZRC20Mock public btcZ; // BTC on zetachain
    ERC20Mock public btc; // BTC on Bitcoin
    DODORouteProxyMock public dodoRouteProxyA; // A chain
    DODORouteProxyMock public dodoRouteProxyZ; // zetachain
    DODORouteProxyMock public dodoRouteProxyB; // B chain

    function setUp() public virtual {
        gatewayA = new GatewayEVMMock();
        gatewayB = new GatewayEVMMock();
        gatewayZEVM = new GatewayZEVMMock();
        gatewaySendA = new GatewaySend();
        gatewaySendB = new GatewaySend();
        gatewayCrossChain = new GatewayCrossChain(); // zetachain
        gatewayTransferNative = new GatewayTransferNative(); // zetachain
        dodoRouteProxyA = new DODORouteProxyMock();
        dodoRouteProxyZ = new DODORouteProxyMock();
        dodoRouteProxyB = new DODORouteProxyMock();
        
        token1A = new ERC20Mock("Token1A", "TK1A", 18);
        token2A = new ERC20Mock("Token2A", "TK2A", 18);
        token1Z = new ZRC20Mock("Token1Z", "TK1Z", 18);
        token2Z = new ZRC20Mock("Token2Z", "TK2Z", 18);
        token3Z = new ZRC20Mock("NativeToken", "NT", 18);
        token1B = new ERC20Mock("Token1B", "TK1B", 18);
        token2B = new ERC20Mock("Token2B", "TK2B", 18);
        token3B = new ERC20Mock("Token3B", "TK3B", 18);
        btcZ = new ZRC20Mock("BTCZ", "BTCZ", 18);
        btc = new ERC20Mock("BTC", "BTC", 18);

        // set GatewayZEVM
        gatewayZEVM.setGatewayEVM(address(gatewayB));

        // set DODORouteProxy
        dodoRouteProxyA.setPrice(address(token1A), address(token2A), 3e18); // 1 token1A = 3 token2A
        dodoRouteProxyA.setPrice(address(token2A), _ETH_ADDRESS_, 2e18); // 1 token2A = 2 ETH
        dodoRouteProxyA.setPrice(address(token1A), _ETH_ADDRESS_, 3e18); // 1 token1A = 3 ETH
        dodoRouteProxyZ.setPrice(address(token1Z), address(token2Z), 2e18); // 1 token1Z = 2 token2Z
        dodoRouteProxyZ.setPrice(address(token1Z), address(token3Z), 3e18); // 1 token1Z = 3 token3Z
        dodoRouteProxyZ.setPrice(address(token2Z), address(token3Z), 1e18); // 1 token2Z = 1 token3Z
        dodoRouteProxyZ.setPrice(address(token1Z), address(btcZ), 1e18); // 1 token1Z = 1 btcZ
        dodoRouteProxyZ.setPrice(address(token2Z), address(btcZ), 2e18); // 1 token2Z = 2 btcZ
        dodoRouteProxyZ.setPrice(address(token1Z), WZETA, 1e18); 
        dodoRouteProxyB.setPrice(address(token1B), address(token2B), 4e18); // 1 token1B = 4 token2B
        dodoRouteProxyB.setPrice(address(token2B), _ETH_ADDRESS_, 1e18); // 1 token2B = 1 ETH
        dodoRouteProxyB.setPrice(address(token1B), _ETH_ADDRESS_, 1e18); // 1 token1B = 1 ETH

        // set GatewaySend
        bytes memory data = abi.encodeWithSignature(
            "initialize(address,address,address,uint256)",
            address(gatewayA),
            address(dodoRouteProxyA),
            address(dodoRouteProxyA), // DODOApprove
            100000
        );
        sendProxyA = new ERC1967Proxy(
            address(gatewaySendA),
            data
        );
        gatewaySendA = GatewaySend(payable(address(sendProxyA)));
        data = abi.encodeWithSignature(
            "initialize(address,address,address,uint256)",
            address(gatewayB),
            address(dodoRouteProxyB),
            address(dodoRouteProxyB), // DODOApprove
            100000
        );
        sendProxyB = new ERC1967Proxy(
            address(gatewaySendB),
            data
        );
        gatewaySendB = GatewaySend(payable(address(sendProxyB)));

        // set GatewayTransferNative
        data = abi.encodeWithSignature(
            "initialize(address,address,address,address,uint256,uint256,uint256)",
            address(gatewayZEVM),
            EddyTreasurySafe,
            address(dodoRouteProxyZ),
            address(dodoRouteProxyZ), // DODOApprove
            0,
            10,
            100000
        );
        transferNativeProxy = new ERC1967Proxy(
            address(gatewayTransferNative),
            data
        );
        gatewayTransferNative = GatewayTransferNative(payable(address(transferNativeProxy)));
        gatewayTransferNative.setBot(bot, true);

        // set GatewayCrossChain
        data = abi.encodeWithSignature(
            "initialize(address,address,address,address,uint256,uint256,uint256)",
            address(gatewayZEVM),
            EddyTreasurySafe,
            address(dodoRouteProxyZ),
            address(dodoRouteProxyZ),
            0,
            10,
            100000
        );
        crossChainProxy = new ERC1967Proxy(
            address(gatewayCrossChain),
            data
        );
        gatewayCrossChain = GatewayCrossChain(payable(address(crossChainProxy)));
        gatewayCrossChain.setBot(bot, true);

        // set GatewayEVM
        gatewayA.setGatewayZEVM(address(gatewayZEVM));
        gatewayA.setZRC20(address(token1A), address(token1Z));
        gatewayA.setZRC20(address(token2A), address(token2Z));  
        gatewayA.setZRC20(address(btc), address(btcZ));
        gatewayA.setZRC20(_ETH_ADDRESS_, address(token3Z));
        gatewayA.setDODORouteProxy(address(dodoRouteProxyA));
        gatewayB.setGatewayZEVM(address(gatewayZEVM));
        gatewayB.setZRC20(address(token1B), address(token1Z));
        gatewayB.setZRC20(address(token2B), address(token2Z));
        gatewayB.setZRC20(address(token3B), address(token3Z));
        gatewayB.setZRC20(address(btc), address(btcZ));
        gatewayB.setDODORouteProxy(address(dodoRouteProxyB));
        gatewayB.setEVMAddress(btcAddress, address(user2));
        gatewayB.setEVMAddress(solGatewaySendAddress, address(gatewaySendB));

        // set ZRC20 tokens
        token1Z.setGasFee(1e18);
        token1Z.setGasZRC20(address(token1Z));
        token2Z.setGasFee(1e18);
        token2Z.setGasZRC20(address(token1Z));
        token3Z.setGasFee(1e18);
        token3Z.setGasZRC20(address(token1Z));
        btcZ.setGasFee(1e18);
        btcZ.setGasZRC20(address(btcZ));

        // create token1Z - token2Z pool for gas fee
        token1Z.mint(address(this), initialBalance);
        token2Z.mint(address(this), initialBalance);
        token1Z.approve(address(router), initialBalance);
        token2Z.approve(address(router), initialBalance);
        router.addLiquidity(
            address(token1Z),
            address(token2Z),
            initialBalance,
            initialBalance,
            0,
            0,
            address(this),
            block.timestamp + 60
        );

        // mint tokens
        vm.deal(user1, initialBalance);
        vm.deal(address(dodoRouteProxyA), initialBalance);
        vm.deal(address(dodoRouteProxyB), initialBalance);

        token1A.mint(user1, initialBalance);
        token1A.mint(address(dodoRouteProxyA), initialBalance);
        token2A.mint(user1, initialBalance);
        token2A.mint(address(dodoRouteProxyA), initialBalance);

        token1Z.mint(user1, initialBalance);
        token1Z.mint(address(gatewayZEVM), initialBalance);
        token1Z.mint(address(dodoRouteProxyZ), initialBalance);
        token2Z.mint(user1, initialBalance);
        token2Z.mint(address(gatewayZEVM), initialBalance);
        token2Z.mint(address(dodoRouteProxyZ), initialBalance);
        token3Z.mint(address(gatewayZEVM), initialBalance);
        token3Z.mint(address(dodoRouteProxyZ), initialBalance);
        btcZ.mint(address(dodoRouteProxyZ), initialBalance);

        token1B.mint(address(gatewayB), initialBalance);
        token1B.mint(address(dodoRouteProxyB), initialBalance);
        token2B.mint(address(gatewayB), initialBalance);
        token2B.mint(address(dodoRouteProxyB), initialBalance);
        btc.mint(address(gatewayB), initialBalance);
    }

    function test_UpgradeImplementation() public {
        GatewaySend gatewaySendNew = new GatewaySend();
        gatewaySendA.upgradeToAndCall(
            address(gatewaySendNew),
            ""
        );
        gatewaySendB.upgradeToAndCall(
            address(gatewaySendNew),
            ""
        );

        GatewayCrossChain gatewayCrossChainNew = new GatewayCrossChain();
        gatewayCrossChain.upgradeToAndCall(
            address(gatewayCrossChainNew),
            ""
        );

        GatewayTransferNative gatewayTransferNativeNew = new GatewayTransferNative();
        gatewayTransferNative.upgradeToAndCall(
            address(gatewayTransferNativeNew),
            ""
        );
    }

    function encodeMessage(
        uint32 dstChainId,
        address targetZRC20,
        bytes memory sender,
        bytes memory receiver,
        bytes memory swapDataZ,
        bytes memory contractAddress,
        bytes memory swapDataB,
        bytes memory accounts
    ) public pure returns (bytes memory) {
        return abi.encodePacked(
            bytes4(dstChainId),
            bytes20(targetZRC20),
            uint16(sender.length),
            uint16(receiver.length),
            uint16(swapDataZ.length),
            uint16(contractAddress.length),
            uint16(swapDataB.length),
            uint16(accounts.length),
            sender,
            receiver,
            swapDataZ,
            contractAddress,
            swapDataB,
            accounts
        );
    }

    function encodeNativeMessage(
        address targetZRC20,
        bytes memory sender,
        bytes memory receiver,
        bytes memory swapData
    ) public pure returns (bytes memory) {
        return abi.encodePacked(
            bytes20(targetZRC20),
            uint16(sender.length),
            uint16(receiver.length),
            sender,
            receiver,
            swapData
        );
    }

    function encodeCompressedMixSwapParams(
        address fromToken,
        address toToken,
        uint256 fromTokenAmount,
        uint256 expReturnAmount,
        uint256 minReturnAmount,
        address[] memory mixAdapters,
        address[] memory mixPairs,
        address[] memory assetTo,
        uint256 directions,
        bytes[] memory moreInfo,
        bytes memory feeData,
        uint256 deadline
    ) public pure returns (bytes memory) {
        bytes memory encoded = abi.encodePacked(
            fromToken,
            toToken,
            fromTokenAmount,
            expReturnAmount,
            minReturnAmount,
            directions,
            deadline
        );

        encoded = bytes.concat(
            encoded,
            encodeAddressArray(mixAdapters),
            encodeAddressArray(mixPairs),
            encodeAddressArray(assetTo),
            encodeBytesArrayWithLens(moreInfo),
            encodeBytesWith2Len(feeData)
        );

        return encoded;
    }

    function encodeAddressArray(address[] memory arr) internal pure returns (bytes memory out) {
        require(arr.length <= 255, "Too many addresses");
        out = abi.encodePacked(uint8(arr.length));
        for (uint i = 0; i < arr.length; i++) {
            out = bytes.concat(out, abi.encodePacked(arr[i]));
        }
    }

    function encodeBytesWith2Len(bytes memory data) internal pure returns (bytes memory out) {
        require(data.length <= 65535, "Too long");
        out = abi.encodePacked(uint16(data.length), data);
    }

    function encodeBytesArrayWithLens(bytes[] memory arr) internal pure returns (bytes memory out) {
        require(arr.length <= 255, "Too many items");
        out = abi.encodePacked(uint8(arr.length));
        for (uint i = 0; i < arr.length; i++) {
            require(arr[i].length <= 65535, "Item too long");
            out = bytes.concat(out, abi.encodePacked(uint16(arr[i].length)));
        }
        for (uint i = 0; i < arr.length; i++) {
            out = bytes.concat(out, arr[i]);
        }
    }

    function compressAccounts(bytes32[] memory publicKeys, bool[] memory isWritables) public pure returns (bytes memory out) {
        uint256 len = publicKeys.length;
        require(len == isWritables.length, "Length mismatch");
        require(len < type(uint16).max, "Too many accounts");

        uint256 totalSize = 2 + len * 33;
        out = new bytes(totalSize);

        assembly {
            let ptr := add(out, 32)

            // accounts.length (uint16)
            mstore8(ptr, shr(8, len))
            mstore8(add(ptr, 1), and(len, 0xff))
            ptr := add(ptr, 2)

            for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                let pubkey := mload(add(add(publicKeys, 32), mul(i, 32)))
                let writable := mload(add(add(isWritables, 32), mul(i, 32)))

                mstore(ptr, pubkey)
                ptr := add(ptr, 32)
                mstore8(ptr, iszero(iszero(writable)))
                ptr := add(ptr, 1)
            }
        }
    }
}