// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {GatewayZEVM} from "@zetachain/protocol-contracts/contracts/zevm/GatewayZEVM.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/IGatewayZEVM.sol";
import {IZRC20} from "@zetachain/protocol-contracts/contracts/zevm/interfaces/IZRC20.sol";
import {UniversalContract} from "@zetachain/protocol-contracts/contracts/zevm/interfaces/UniversalContract.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import {UniswapV2Library} from "./libraries/UniswapV2Library.sol";
import {TransferHelper} from "./libraries/TransferHelper.sol";
import {BytesHelperLib} from "./libraries/BytesHelperLib.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";
import {IDODORouteProxy} from "./interfaces/IDODORouteProxy.sol";
import {Account, AccountEncoder} from "./libraries/AccountEncoder.sol";
import "./libraries/SwapDataHelperLib.sol";

contract GatewayTransferNative is UniversalContract, Initializable, OwnableUpgradeable, UUPSUpgradeable {
    address constant _ETH_ADDRESS_ = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WZETA = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
    address public constant UniswapRouter = 0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe;
    address public constant UniswapFactory = 0x9fd96203f7b22bCF72d9DCb40ff98302376cE09c;
    uint32 constant BITCOIN_EDDY = 8332; // chain Id from eddy db
    uint32 constant SOLANA_EDDY = 1399811149; // chain Id from eddy db
    uint32 constant ZETACHAIN = 7000;
    uint256 constant MAX_DEADLINE = 200;
    address private EddyTreasurySafe;
    address public DODORouteProxy;
    address public DODOApprove;
    mapping(bytes32 => RefundInfo) public refundInfos; // externalId => RefundInfo
    mapping(address => bool) public bots;
    uint256 public globalNonce;
    uint256 public feePercent;
    uint256 public slippage;
    uint256 public gasLimit;

    GatewayZEVM public gateway;

    struct RefundInfo {
        bytes32 externalId;
        address token;
        uint256 amount;
        bytes walletAddress;
    }

    error Unauthorized();
    error RouteProxyCallFailed();
    error NotEnoughToPayGasFee();
    error IdenticalAddresses();
    error ZeroAddress();

    event EddyCrossChainRevert(
        bytes32 externalId,
        address token,
        uint256 amount,
        bytes walletAddress
    );
    event EddyCrossChainSwap(
        bytes32 externalId,
        uint32 srcChainId,
        uint32 dstChainId,
        address zrc20,
        address targetZRC20,
        uint256 amount,
        uint256 outputAmount,
        bytes sender,
        bytes receiver,
        uint256 fees
    );
    event EddyCrossChainRefund(
        bytes32 externalId, 
        address indexed token, 
        uint256 amount,
        bytes walletAddress
    );
    event EddyCrossChainRefundClaimed(
        bytes32 externalId, 
        address indexed token, 
        uint256 amount,
        bytes walletAddress
    );
    event GatewayUpdated(address gateway);
    event FeePercentUpdated(uint256 feePercent);
    event DODORouteProxyUpdated(address dodoRouteProxy);
    event DODOApproveUpdated(address dodoApprove);
    event EddyTreasurySafeUpdated(address EddyTreasurySafe);

    modifier onlyGateway() {
        if (msg.sender != address(gateway)) revert Unauthorized();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @dev Initialize the contract
     * @param _gateway Gateway contract address
     * @param _EddyTreasurySafe Address of the platform fee wallets
     * @param _dodoRouteProxy Address of the DODORouteProxy
     * @param _feePercent Platform fee percentage in basis points (e.g., 10 = 1%)
     */
    function initialize(
        address payable _gateway,
        address _EddyTreasurySafe,
        address _dodoRouteProxy,
        address _dodoApprove,
        uint256 _feePercent,
        uint256 _slippage,
        uint256 _gasLimit
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        gateway = GatewayZEVM(_gateway);
        EddyTreasurySafe = _EddyTreasurySafe;
        DODORouteProxy = _dodoRouteProxy;
        DODOApprove = _dodoApprove;
        feePercent = _feePercent;
        slippage = _slippage;
        gasLimit = _gasLimit;
    }

    function setOwner(address _owner) external onlyOwner {
        transferOwnership(_owner);
    }

    function setDODORouteProxy(address _dodoRouteProxy) external onlyOwner {
        DODORouteProxy = _dodoRouteProxy;
        emit DODORouteProxyUpdated(_dodoRouteProxy);
    }

    function setDODOApprove(address _dodoApprove) external onlyOwner {
        DODOApprove = _dodoApprove;
        emit DODOApproveUpdated(_dodoApprove);
    }

    function setFeePercent(uint256 _feePercent) external onlyOwner {
        feePercent = _feePercent;
        emit FeePercentUpdated(_feePercent);
    }

    function setGasLimit(uint256 _gasLimit) external onlyOwner {
        gasLimit = _gasLimit;
    }

    function setGateway(address payable _gateway) external onlyOwner {
        gateway = GatewayZEVM(_gateway);
        emit GatewayUpdated(_gateway);
    }

    function setEddyTreasurySafe(address _EddyTreasurySafe) external onlyOwner {
        EddyTreasurySafe = _EddyTreasurySafe;
        emit EddyTreasurySafeUpdated(_EddyTreasurySafe);
    }

    function setBot(address bot, bool isAllowed) external onlyOwner {
        bots[bot] = isAllowed;
    }

    function superWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == _ETH_ADDRESS_) {
            require(amount <= address(this).balance, "INVALID_AMOUNT");
            TransferHelper.safeTransferETH(EddyTreasurySafe, amount);
        } else {
            require(amount <= IZRC20(token).balanceOf(address(this)), "INVALID_AMOUNT");
            TransferHelper.safeTransfer(token, EddyTreasurySafe, amount);
        }
    }

    function _calcExternalId(address sender) internal view returns (bytes32 externalId) {
        externalId = keccak256(abi.encodePacked(address(this), sender, globalNonce, block.timestamp));
    }

    // ============== Uniswap Helper ================ 

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(
        address tokenA,
        address tokenB
    ) internal pure returns (address token0, address token1) {
        if (tokenA == tokenB) revert IdenticalAddresses();
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        if (token0 == address(0)) revert ZeroAddress();
    }

    function uniswapv2PairFor(
        address factory,
        address tokenA,
        address tokenB
    ) public pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f" // init code hash
                        )
                    )
                )
            )
        );
    }

     function _existsPairPool(
        address uniswapV2Factory,
        address zrc20A,
        address zrc20B
    ) internal view returns (bool) {
        address uniswapPool = uniswapv2PairFor(
            uniswapV2Factory,
            zrc20A,
            zrc20B
        );
        return
            IZRC20(zrc20A).balanceOf(uniswapPool) > 0 &&
            IZRC20(zrc20B).balanceOf(uniswapPool) > 0;
    }

    function getPathForTokens(
        address zrc20,
        address targetZRC20
    ) internal view returns(address[] memory path) {
        bool existsPairPool = _existsPairPool(
            UniswapFactory,
            zrc20,
            targetZRC20
        );

        if (existsPairPool) {
            path = new address[](2);
            path[0] = zrc20;
            path[1] = targetZRC20;
        } else {
            path = new address[](3);
            path[0] = zrc20;
            path[1] = WZETA;
            path[2] = targetZRC20;
        }
    }

    function withdrawAndCall(
        bytes32 externalId,
        bytes memory contractAddress,
        address targetZRC20,
        uint256 outputAmount,
        bytes memory receiver,
        bytes memory message
    ) internal {
        gateway.withdrawAndCall(
            contractAddress,
            outputAmount,
            targetZRC20,
            message,
            CallOptions({
                isArbitraryCall: false,
                gasLimit: gasLimit
            }),
            RevertOptions({
                revertAddress: address(this),
                callOnRevert: true,
                abortAddress: address(0),
                revertMessage: bytes.concat(externalId, receiver),
                onRevertGasLimit: gasLimit
            })
        );
    }

    /**
     * @notice - Function to withdraw using gateway
     * @param sender Sender address
     * @param outputToken output token address
     * @param amount amount to withdraw
     */
    function withdraw(
        bytes32 externalId,
        bytes memory sender,
        address outputToken,
        uint256 amount
    ) public {
        gateway.withdraw(
            sender,
            amount,
            outputToken,
            RevertOptions({
                revertAddress: address(this),
                callOnRevert: true,
                abortAddress: address(0),
                revertMessage: bytes.concat(externalId, bytes20(sender)),
                onRevertGasLimit: gasLimit
            })
        );
    }

    function _swapAndSendERC20Tokens(
        address targetZRC20,
        address gasZRC20,
        uint256 gasFee,
        uint256 targetAmount
    ) internal returns(uint256 amountsOut) {
        // Get amountOut for Input gasToken
        uint[] memory amountsQuote = UniswapV2Library.getAmountsIn(
            UniswapFactory,
            gasFee,
            getPathForTokens(targetZRC20, gasZRC20) // [targetZRC, gasZRC] or [targetZRC, WZETA, gasZRC]
        );

        uint amountInMax = (amountsQuote[0]) + (slippage * amountsQuote[0]) / 1000;
        IZRC20(targetZRC20).approve(UniswapRouter, amountInMax);

        // Swap TargetZRC20 to gasZRC20
        uint[] memory amounts = IUniswapV2Router01(UniswapRouter)
            .swapTokensForExactTokens(
                gasFee, // Amount of gas token required
                amountInMax,
                getPathForTokens(targetZRC20, gasZRC20), // path[0] = targetZRC20, path[1] = gasZRC20
                address(this),
                block.timestamp + MAX_DEADLINE
        );

        require(IZRC20(gasZRC20).balanceOf(address(this)) >= gasFee, "INSUFFICIENT_GAS_FOR_WITHDRAW");
        require(targetAmount - amountInMax > 0, "INSUFFICIENT_AMOUNT_FOR_WITHDRAW"); // the same error

        IZRC20(gasZRC20).approve(address(gateway), gasFee);
        IZRC20(targetZRC20).approve(address(gateway), targetAmount - amounts[0]);

        amountsOut = targetAmount - amounts[0];
    }

    function _handleFeeTransfer(
        address zrc20,
        uint256 amount
    ) internal returns (uint256 platformFeesForTx) {
        platformFeesForTx = (amount * feePercent) / 1000; // platformFee = 5 <> 0.5%
        TransferHelper.safeTransfer(zrc20, EddyTreasurySafe, platformFeesForTx);
    }

    /**
     * @notice Function called by the gateway to execute the cross-chain swap
     * @param context Message context
     * @param zrc20 ZRC20 token address
     * @param amount Amount
     * @param message Message
     * @dev Only the gateway can call this function
     */
    function onCall(
        MessageContext calldata context,
        address zrc20,
        uint256 amount,
        bytes calldata message
    ) external override onlyGateway {
        // Decode the message
        // 32 bytes(externalId) + bytes message
        (bytes32 externalId) = abi.decode(message[0:32], (bytes32)); 
        bytes calldata _message = message[32:];
        (DecodedNativeMessage memory decoded, MixSwapParams memory params) = SwapDataHelperLib.decodeNativeMessage(_message);

        // Fee for platform
        uint256 platformFeesForTx = _handleFeeTransfer(zrc20, amount); // platformFee = 5 <> 0.5%
        address receiver = address(uint160(bytes20(decoded.receiver)));

        if (decoded.targetZRC20 == zrc20) {
            // same token
            TransferHelper.safeTransfer(
                decoded.targetZRC20,
                receiver,
                amount - platformFeesForTx
            );

            emit EddyCrossChainSwap(
                externalId,
                uint32(context.chainID),
                ZETACHAIN,
                zrc20,
                decoded.targetZRC20,
                amount,
                amount - platformFeesForTx,
                decoded.sender,
                decoded.receiver,
                platformFeesForTx
            );
        } else {
            // Swap on DODO Router
            uint256 outputAmount = _doMixSwap(decoded.swapData, amount, params);

            if (decoded.targetZRC20 == WZETA) {
                // withdraw WZETA to get Zeta in 1:1 ratio
                IWETH9(WZETA).withdraw(outputAmount);
                // transfer wzeta
                TransferHelper.safeTransferETH(receiver, outputAmount);
            } else {
                TransferHelper.safeTransfer(
                    decoded.targetZRC20,
                    receiver,
                    outputAmount
                );
                /*
                这行代码的真正含义是：

                “在 ZetaChain 上，将 outputAmount 数量的 targetZRC20 代币，从本合约（GatewayTransferNative）的地址，转移到同样在 ZetaChain 上的 receiver 地址。”

                这仅仅是一次ZetaChain 内部的本地转账。它没有实现真正的“跨链提现”。
                */
            }
// 用户的资金都留在了ZetaChain上，没有发生跨链的操作！ 转到了ZetaChain上的receiver地址上。而不是目标链的地址！！！
            emit EddyCrossChainSwap(
                externalId,
                uint32(context.chainID),
                ZETACHAIN,
                zrc20,
                decoded.targetZRC20,
                amount,
                outputAmount,
                decoded.sender,
                decoded.receiver,
                platformFeesForTx
            );
        }
    }

    function _doMixSwap(
        bytes memory swapData, 
        uint256 amount, 
        MixSwapParams memory params
    ) internal returns (uint256 outputAmount) {
        if (swapData.length == 0) {
            return amount;
        }

        IZRC20(params.fromToken).approve(DODOApprove, amount);
        return IDODORouteProxy(DODORouteProxy).mixSwap{value: msg.value}(
            params.fromToken,
            params.toToken,
            params.fromTokenAmount,
            params.expReturnAmount,
            params.minReturnAmount,
            params.mixAdapters,
            params.mixPairs,
            params.assetTo,
            params.directions,
            params.moreInfo,
            params.feeData,
            params.deadline
        );
    }

    function _handleBitcoinWithdraw(
        bytes32 externalId, 
        DecodedMessage memory decoded, 
        uint256 outputAmount,
        uint256 gasFee
    ) internal {
        if(gasFee >= outputAmount) revert NotEnoughToPayGasFee();
        IZRC20(decoded.targetZRC20).approve(address(gateway), outputAmount + gasFee);
        withdraw(
            externalId, 
            decoded.receiver, 
            decoded.targetZRC20, 
            outputAmount - gasFee
        );
    }

    function _handleEvmOrSolanaWithdraw(
        bytes32 externalId,
        DecodedMessage memory decoded,
        uint256 outputAmount,
        bytes memory receiver
    ) internal returns (uint256 amountsOutTarget) {
        (address gasZRC20, uint256 gasFee) = IZRC20(decoded.targetZRC20).withdrawGasFeeWithGasLimit(gasLimit);

        if (decoded.targetZRC20 == gasZRC20) {
            if (gasFee >= outputAmount) revert NotEnoughToPayGasFee();
            IZRC20(decoded.targetZRC20).approve(address(gateway), outputAmount + gasFee);

            bytes memory data = SwapDataHelperLib.buildOutputMessage(
                externalId, 
                outputAmount - gasFee, 
                decoded.receiver, 
                decoded.swapDataB
            );
            
            bytes memory encoded = (decoded.dstChainId == SOLANA_EDDY)
                ? AccountEncoder.encodeInput(AccountEncoder.decompressAccounts(decoded.accounts), data)
                : data;

            withdrawAndCall(
                externalId, 
                decoded.contractAddress, 
                decoded.targetZRC20, 
                outputAmount - gasFee, 
                receiver, 
                encoded
            );

            amountsOutTarget = outputAmount - gasFee;
        } else {
            amountsOutTarget = _swapAndSendERC20Tokens(
                decoded.targetZRC20, 
                gasZRC20, 
                gasFee, 
                outputAmount
            );

            bytes memory data = SwapDataHelperLib.buildOutputMessage(
                externalId, 
                amountsOutTarget, 
                decoded.receiver, 
                decoded.swapDataB
            );
            
            bytes memory encoded = (decoded.dstChainId == SOLANA_EDDY)
                ? AccountEncoder.encodeInput(AccountEncoder.decompressAccounts(decoded.accounts), data)
                : data;

            withdrawAndCall(
                externalId, 
                decoded.contractAddress, 
                decoded.targetZRC20, 
                amountsOutTarget, 
                receiver, 
                encoded
            );
        }
    }

    function withdrawToNativeChain(
        address zrc20,
        uint256 amount,
        bytes calldata message
    ) external payable {
        if(zrc20 != _ETH_ADDRESS_) {
            require(IZRC20(zrc20).transferFrom(msg.sender, address(this), amount), "INSUFFICIENT ALLOWANCE: TRANSFER FROM FAILED");
        } 

        globalNonce++;
        bytes32 externalId = _calcExternalId(msg.sender);

        // Decode message and decompress swap params
        (DecodedMessage memory decoded, MixSwapParams memory params) = SwapDataHelperLib.decodeMessage(message);
        
        // Check if the message is from Bitcoin to Solana
        // address evmWalletAddress = (decoded.dstChainId == BITCOIN_EDDY || decoded.dstChainId == SOLANA_EDDY)
        //     ? msg.sender
        //     : address(uint160(bytes20(decoded.receiver)));

        // Transfer platform fees
        uint256 platformFeesForTx = _handleFeeTransfer(zrc20, amount); // platformFee = 5 <> 0.5%
        amount -= platformFeesForTx;

        // Swap on DODO Router
        uint256 outputAmount = _doMixSwap(decoded.swapDataZ, amount, params);
        
        // Withdraw
        if (decoded.dstChainId == BITCOIN_EDDY) {
            (, uint256 gasFee) = IZRC20(decoded.targetZRC20).withdrawGasFee();
            _handleBitcoinWithdraw(
                externalId, 
                decoded, 
                outputAmount,
                gasFee
            );

            emit EddyCrossChainSwap(
                externalId, 
                ZETACHAIN,
                decoded.dstChainId, 
                zrc20, 
                decoded.targetZRC20, 
                amount, 
                outputAmount - gasFee, 
                decoded.sender,
                decoded.receiver, 
                platformFeesForTx
            );
        } else {
            uint256 amountsOutTarget = _handleEvmOrSolanaWithdraw(
                externalId, 
                decoded, 
                outputAmount, 
                decoded.receiver
            );

            emit EddyCrossChainSwap(
                externalId, 
                ZETACHAIN,
                decoded.dstChainId, 
                zrc20, 
                decoded.targetZRC20, 
                amount, 
                amountsOutTarget, 
                decoded.sender,
                decoded.receiver, 
                platformFeesForTx
            );
        }
    }

    /**
     * @notice Function called by the gateway to revert the cross-chain swap
     * @param context Revert context
     * @dev Only the gateway can call this function
     */
    function onRevert(RevertContext calldata context) external onlyGateway {
        // 52 bytes = 32 bytes externalId + 20 bytes evmWalletAddress
        bytes32 externalId = bytes32(context.revertMessage[0:32]);
        bytes memory walletAddress = context.revertMessage[32:];

        if(context.revertMessage.length == 52) {
            address receiver = address(uint160(bytes20(walletAddress)));
            TransferHelper.safeTransfer(context.asset, receiver, context.amount);

            emit EddyCrossChainRevert(
                externalId,
                context.asset,
                context.amount,
                walletAddress
            );
        } else {
            RefundInfo memory refundInfo = RefundInfo({
                externalId: externalId,
                token: context.asset,
                amount: context.amount,
                walletAddress: walletAddress
            });
            refundInfos[externalId] = refundInfo;
            
            emit EddyCrossChainRefund(
                externalId,
                context.asset,
                context.amount,
                walletAddress
            );
        }
    }

    function onAbort(AbortContext calldata abortContext) external onlyGateway {
        // 52 bytes = 32 bytes externalId + 20 bytes evmWalletAddress
        bytes32 externalId = bytes32(abortContext.revertMessage[0:32]);
        bytes memory walletAddress = abortContext.revertMessage[32:];

        RefundInfo memory refundInfo = RefundInfo({
            externalId: externalId,
            token: abortContext.asset,
            amount: abortContext.amount,
            walletAddress: walletAddress
        });
        refundInfos[externalId] = refundInfo;
        
        emit EddyCrossChainRefund(
            externalId,
            abortContext.asset,
            abortContext.amount,
            walletAddress
        );
    }

    function claimRefund(bytes32 externalId) external {
        RefundInfo storage refundInfo = refundInfos[externalId];

        address receiver = msg.sender;
        if(refundInfo.walletAddress.length == 20) {
            receiver = address(uint160(bytes20(refundInfo.walletAddress)));
        }
        require(bots[msg.sender] || msg.sender == receiver, "INVALID_CALLER"); // 可被绕过
        require(refundInfo.externalId != "", "REFUND_NOT_EXIST");
        
        TransferHelper.safeTransfer(refundInfo.token, receiver, refundInfo.amount);
        delete refundInfos[externalId];

        emit EddyCrossChainRefundClaimed(
            externalId,
            refundInfo.token,
            refundInfo.amount,
            abi.encodePacked(msg.sender)
        );
    }

    receive() external payable {}

    fallback() external payable {}
}