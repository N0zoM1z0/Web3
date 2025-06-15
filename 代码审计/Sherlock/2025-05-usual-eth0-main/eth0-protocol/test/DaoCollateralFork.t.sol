// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {Pausable} from "openzeppelin-contracts/utils/Pausable.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IRwaMock} from "src/interfaces/token/IRwaMock.sol";
import {IAggregator} from "src/interfaces/oracles/IAggregator.sol";
import {SetupTest} from "./setup.t.sol";
import {RwaMock} from "src/mock/rwaMock.sol";
import {MyERC20} from "src/mock/myERC20.sol";
import {Eth0} from "src/token/Eth0.sol";
import {IERC20Errors} from "openzeppelin-contracts/interfaces/draft-IERC6093.sol";
import {Normalize} from "src/utils/normalize.sol";

import {Math} from "openzeppelin-contracts/utils/math/Math.sol";
import {IWstETH} from "src/interfaces/IWstETH.sol";
import {DaoCollateral} from "src/daoCollateral/DaoCollateral.sol";
import {LidoProxyWstETHPriceFeed} from "src/oracles/LidoWstEthOracle.sol";

import {IERC20Permit} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Permit.sol";
import {
    MAX_REDEEM_FEE,
    SCALAR_ONE,
    BASIS_POINT_BASE,
    ONE_YEAR,
    ONE_WEEK,
    WSTETH
} from "src/constants.sol";
import {
    SameValue,
    AmountTooLow,
    AmountTooBig,
    CBRIsTooHigh,
    CBRIsNull,
    RedeemMustNotBePaused,
    RedeemMustBePaused,
    SwapMustNotBePaused,
    SwapMustBePaused,
    RedeemFeeTooBig,
    NoOrdersIdsProvided,
    InvalidSigner,
    ExpiredSignature,
    InvalidDeadline,
    ApprovalFailed,
    RedeemFeeCannotBeZero
} from "src/errors.sol";

import "@openzeppelin/contracts/mocks/ERC1271WalletMock.sol";

contract DaoCollateralForkTest is SetupTest {
    using Normalize for uint256;

    ERC1271WalletMock public erc1271Mock;

    LidoProxyWstETHPriceFeed public dataSource;

    event RedeemUnPaused();
    event CBRDeactivated();

    /*//////////////////////////////////////////////////////////////
                            1. SETUP & HELPERS
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        uint256 forkId = vm.createFork("eth");
        vm.selectFork(forkId);
        super.setUp();
        vm.label(address(WSTETH), "WSTETH"); //uses mainnet fork to set up wstETH

        erc1271Mock = new ERC1271WalletMock(alice);
        vm.deal(alice, 1 ether);
    }

    function setupCreationRwaLido() public returns (RwaMock, Eth0) {
        address ethCollateralToken = address(WSTETH);
        vm.label(ethCollateralToken, "WSTETH Forked");

        //dont really need the IRWA mock here, but dont wanna rewrite the other yet
        _linkSTBCToRwa(IRwaMock(ethCollateralToken));

        Eth0 stbc = stbcToken;
        whitelistPublisher(address(ethCollateralToken), address(stbc));
        _setupBucket(ethCollateralToken, address(stbc));
        _setOraclePriceFork(ethCollateralToken, 10 ** 18, WSTETH);

        return (RwaMock(ethCollateralToken), stbc);
    }

    function setupCreationRwa1() public returns (RwaMock, Eth0) {
        address token = address(WSTETH);
        vm.label(token, "WSTETH Forked");
        _linkSTBCToRwa(IRwaMock(token));
        Eth0 stbc = stbcToken;
        // add mock oracle for rwa token
        whitelistPublisher(address(token), address(stbc));
        _setupBucket(token, address(stbc));
        _setOraclePriceFork(token, 10 ** 18, WSTETH);

        return (RwaMock(token), stbc);
    }

    function setupCreationRwa2() public returns (RwaMock, Eth0) {
        address token = address(WSTETH);
        vm.label(token, "WSTETH Forked");
        _linkSTBCToRwa(IRwaMock(token));
        Eth0 stbc = stbcToken;
        // add mock oracle for rwa token
        whitelistPublisher(address(token), address(stbc));
        _setupBucket(token, address(stbc));
        _setOraclePriceFork(token, 10 ** 18, WSTETH);

        return (RwaMock(token), stbc);
    }

    function setupCreationRwa1_withMint(uint256 amount) public returns (RwaMock, Eth0) {
        (RwaMock token, Eth0 stbc) = setupCreationRwa1();
        deal(address(token), alice, amount);
        vm.prank(alice);
        token.approve(address(daoCollateral), type(uint256).max);
        return (token, stbc);
    }

    function setupCreationRwa2_withMint(uint256 amount) public returns (RwaMock, Eth0) {
        (RwaMock token, Eth0 stbc) = setupCreationRwa2();
        deal(address(token), alice, amount);
        vm.prank(alice);
        token.approve(address(daoCollateral), type(uint256).max);
        return (token, stbc);
    }

    /// @dev This test checks that the swap and redeem functions work correctly when the supply plus the amount is greater than the RWA backing
    function testSwapAndRedeemWhenSupplyPlusAmountIsRWABackingShouldWork__fork() public {
        // Arrange
        uint256 rwaAmount = 10e18;
        (RwaMock rwa1, Eth0 stbc) = setupCreationRwa1();

        // Setup initial wstETH token state
        deal(address(rwa1), alice, rwaAmount);
        uint256 amount = ERC20(address(rwa1)).balanceOf(alice);

        // Setup Bob's initial state
        uint256 amountInRWA = (amount * 1e18) / classicalOracle.getPrice(address(rwa1));
        deal(address(rwa1), bob, amountInRWA);

        // Act - Part 1: Swap RWA for stablecoins
        vm.startPrank(bob);
        ERC20(address(rwa1)).approve(address(daoCollateral), amountInRWA);
        daoCollateral.swap(address(rwa1), amountInRWA, 0);

        // Get stable balance after swap
        uint256 stbcBalance = ERC20(address(stbc)).balanceOf(bob);

        // Act - Part 2: Redeem stablecoins back to RWA
        stbc.approve(address(daoCollateral), stbcBalance);
        daoCollateral.redeem(address(rwa1), stbcBalance, 0);
        vm.stopPrank();

        // Calculate expected RWA amount considering the redemption fee
        uint256 redemptionFee = Math.mulDiv(
            stbcBalance, daoCollateral.redeemFee(), BASIS_POINT_BASE, Math.Rounding.Floor
        );
        uint256 amountRedeemedMinusFee = stbcBalance - redemptionFee;
        uint256 wadPriceInUSD = classicalOracle.getPrice(address(rwa1));
        uint8 decimals = IERC20Metadata(address(rwa1)).decimals();
        uint256 expectedRwaAmount =
            amountRedeemedMinusFee.wadTokenAmountForPrice(wadPriceInUSD, decimals);

        // Assert
        assertEq(ERC20(address(rwa1)).balanceOf(bob), expectedRwaAmount, "Incorrect RWA balance");
        assertEq(ERC20(address(stbc)).balanceOf(bob), 0, "Stable balance should be 0");
        assertEq(
            ERC20(address(stbc)).balanceOf(treasuryYield), redemptionFee, "Incorrect fee transfer"
        );
    }

    /// @dev This test checks that the swap and redeem functions work correctly when the supply plus the amount is greater than the RWA backing
    function testSwapAndRedeemWhenSupplyPlusAmountIsRWABackingShouldWorkEth__fork() public {
        // Arrange
        uint256 rwaAmount = 10e18;

        (RwaMock rwa1, Eth0 stbc) = setupCreationRwaLido();

        // Setup initial RWA token state
        deal(address(rwa1), alice, rwaAmount, false);

        uint256 amount = ERC20(address(rwa1)).balanceOf(alice);

        // Setup Bob's initial state
        uint256 amountInRWA = (amount * 1e18) / classicalOracle.getPrice(address(rwa1));

        deal(address(rwa1), bob, amountInRWA, false);

        // Act - Part 1: Swap RWA for stablecoins
        vm.startPrank(bob);
        ERC20(address(rwa1)).approve(address(daoCollateral), amountInRWA);
        daoCollateral.swap(address(rwa1), amountInRWA, 0);

        // Get stable balance after swap
        uint256 stbcBalance = ERC20(address(stbc)).balanceOf(bob);

        // Act - Part 2: Redeem stablecoins back to RWA
        stbc.approve(address(daoCollateral), stbcBalance);

        daoCollateral.redeem(address(rwa1), stbcBalance, 0);
        vm.stopPrank();

        // Calculate expected RWA amount considering the redemption fee
        uint256 redemptionFee = Math.mulDiv(
            stbcBalance, daoCollateral.redeemFee(), BASIS_POINT_BASE, Math.Rounding.Floor
        );

        uint256 amountRedeemedMinusFee = stbcBalance - redemptionFee;

        uint256 wadPriceInUSD = classicalOracle.getPrice(address(rwa1));

        uint8 decimals = IERC20Metadata(address(rwa1)).decimals();

        uint256 expectedRwaAmount =
            amountRedeemedMinusFee.wadTokenAmountForPrice(wadPriceInUSD, decimals);

        // Assert
        uint256 bobRwaBalance = ERC20(address(rwa1)).balanceOf(bob);
        assertEq(bobRwaBalance, expectedRwaAmount, "Incorrect RWA balance");

        uint256 bobStbcBalance = ERC20(address(stbc)).balanceOf(bob);
        assertEq(bobStbcBalance, 0, "Stable balance should be 0");

        uint256 treasuryYieldBalance = ERC20(address(stbc)).balanceOf(treasuryYield);
        assertEq(treasuryYieldBalance, redemptionFee, "Incorrect fee transfer");
    }

    /*//////////////////////////////////////////////////////////////
                        2. INTERNAL & PRIVATE
    //////////////////////////////////////////////////////////////*/
    // This function returns the Alice's permit data
    function _getAlicePermitData(uint256 deadline, address token, address spender, uint256 amount)
        internal
        returns (uint256, uint8, bytes32, bytes32)
    {
        // to avoid compiler error
        uint256 deadlineOk = deadline;
        (uint8 v, bytes32 r, bytes32 s) =
            _getSelfPermitData(token, alice, alicePrivKey, spender, amount, deadlineOk);
        return (deadline, v, r, s);
    }

    function _setOraclePriceFork(address token, uint256 amount, address feed) internal {
        dataSource = new LidoProxyWstETHPriceFeed(feed);

        vm.prank(admin);
        classicalOracle.initializeTokenOracle(token, address(dataSource), ONE_WEEK, false);

        amount = Normalize.tokenAmountToWad(amount, uint8(dataSource.decimals()));
        assertEq(
            classicalOracle.getPrice(address(token)),
            IWstETH(WSTETH).stEthPerToken(),
            "Price not set"
        );
    }
    /*//////////////////////////////////////////////////////////////
                            3. INITIALIZE
    //////////////////////////////////////////////////////////////*/
    // This test checks that the new DaoCollateral contract fails if the parameters are wrong

    function testNewDaoCollateralShouldFailIfWrongParameters() public {
        DaoCollateral daoCollateralTmp = new DaoCollateral();
        _resetInitializerImplementation(address(daoCollateralTmp));

        vm.expectRevert(abi.encodeWithSelector(NullContract.selector));
        daoCollateralTmp.initialize(address(0), 10);

        daoCollateralTmp = new DaoCollateral();
        _resetInitializerImplementation(address(daoCollateralTmp));

        vm.expectRevert(abi.encodeWithSelector(RedeemFeeTooBig.selector));
        daoCollateralTmp.initialize(address(registryContract), MAX_REDEEM_FEE + 1);

        vm.expectRevert(abi.encodeWithSelector(RedeemFeeCannotBeZero.selector));
        daoCollateralTmp.initialize(address(registryContract), 0);
    }

    // This test checks that the new DaoCollateral contract fails if it is already initialized
    function testNewDaoCollateralV1ShouldFailIfAlreadyInitialized() public {
        DaoCollateral daoCollateralTmp = new DaoCollateral();
        _resetInitializerImplementation(address(daoCollateralTmp));

        vm.expectRevert(abi.encodeWithSelector(NullContract.selector));
        daoCollateralTmp.initialize(address(0), 10);
    }

    /*//////////////////////////////////////////////////////////////
                                4. SWAP
    //////////////////////////////////////////////////////////////*/
    // 4.1 Testing revert properties //
    /// @dev This test checks that the swap function does not need to be authorized
    function testRWASwapDoesNotNeedToBeAuthorized(uint256 amount) public {
        amount = bound(amount, 1e6, type(uint128).max - 1);
        (RwaMock token,) = setupCreationRwa1_withMint(amount);

        vm.prank(alice);
        // expect not authorized
        // vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        daoCollateral.swap(address(token), amount, 0);
    }

    /// @dev This test checks that the swap function fails if the amount is too big
    function testRWASwapAmountTooBig(uint256 amount) public {
        amount = bound(amount, type(uint128).max, type(uint256).max - 1);
        amount += 1;
        (RwaMock token,) = setupCreationRwa1_withMint(amount);

        vm.expectRevert(abi.encodeWithSelector(AmountTooBig.selector));
        vm.prank(alice);
        daoCollateral.swap(address(token), amount, 0);
    }

    /// @dev This test checks that the swapWithPermit function fails if the amount is too big
    function testRWASwapWithPermitAmountTooBig(uint256 amount) public {
        amount = bound(amount, type(uint128).max, type(uint256).max - 1);
        amount += 1;
        (RwaMock token,) = setupCreationRwa1_withMint(amount);

        (uint256 deadline, uint8 v, bytes32 r, bytes32 s) = _getAlicePermitData(
            block.timestamp + 1 days, address(token), address(daoCollateral), amount
        );

        vm.expectRevert(abi.encodeWithSelector(AmountTooBig.selector));
        vm.prank(alice);
        daoCollateral.swapWithPermit(address(token), amount, amount, deadline, v, r, s);
    }

    /// @dev This test checks that the swap function fails if the amount is too low
    function testSwapShouldFailIfAmountTooLow(uint256 amount, uint256 excessAmount) public {
        amount = bound(amount, 10e6, type(uint128).max);
        excessAmount = bound(excessAmount, 1, type(uint128).max);
        (RwaMock token,) = setupCreationRwa1_withMint(amount);

        // it is the same as price is 1e18 except for the imprecision
        uint256 amountInUsd = amount * 1e12;
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AmountTooLow.selector));
        daoCollateral.swap(address(token), amount, amountInUsd + excessAmount);
    }

    /// @dev This test checks that the swap function fails if the amount is zero
    function testSwapShouldFailIfAmountZero() public {
        uint256 amount = 0;
        (RwaMock token,) = setupCreationRwa1_withMint(amount);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AmountIsZero.selector));
        daoCollateral.swap(address(token), amount, 0);
    }

    /// @dev This test checks that the swapWithPermit function fails if the amount is too low
    function testSwapWithPermitShouldFailIfAmountTooLow(uint256 amount, uint256 excessAmount)
        public
    {
        amount = bound(amount, 10e6, type(uint128).max);
        excessAmount = bound(excessAmount, 1, type(uint128).max);
        (RwaMock token,) = setupCreationRwa1_withMint(amount);

        (uint256 deadline, uint8 v, bytes32 r, bytes32 s) = _getAlicePermitData(
            block.timestamp + 1 days, address(token), address(daoCollateral), amount
        );

        // it is the same as price is 1e18 except for the imprecision
        uint256 amountInUsd = amount * 1e12;
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AmountTooLow.selector));
        daoCollateral.swapWithPermit(
            address(token), amount, amountInUsd + excessAmount, deadline, v, r, s
        );
    }

    /// @dev This test checks that the swap function fails if the token is invalid
    function testSwapShouldFailIfInvalidToken() public {
        uint256 amount = 10_000_000_000;
        setupCreationRwa1_withMint(amount);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(InvalidToken.selector));
        daoCollateral.swap(address(0x21), amount, 0);
    }

    /// @dev This test checks that the swapWithPermit function fails if the token is invalid
    function testSwapWithPermitShouldFailIfInvalidToken() public {
        uint256 amount = 10_000_000_000;
        setupCreationRwa1_withMint(amount);

        vm.prank(alice);
        rwaFactory.createRwa("Hashnote US Yield Coin2", "USYC2", 6);
        address invalidToken = rwaFactory.getRwaFromSymbol("USYC2");

        (uint256 deadline, uint8 v, bytes32 r, bytes32 s) = _getAlicePermitData(
            block.timestamp + 1 days, address(invalidToken), address(daoCollateral), amount
        );

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(InvalidToken.selector));
        daoCollateral.swapWithPermit(invalidToken, amount, amount, deadline, v, r, s);
    }

    /// @dev This test checks that the swapWithPermit function fails if the permit is invalid
    function testSwapWithPermitFailingERC20Permit__fork(uint256 amount, uint256 excessAmount)
        public
    {
        amount = bound(amount, 100e6, type(uint128).max);
        excessAmount = bound(excessAmount, 1, amount);
        (RwaMock token,) = setupCreationRwa1_withMint(amount);
        // swap for ETH0
        (uint256 deadline, uint8 v, bytes32 r, bytes32 s) =
            _getAlicePermitData(block.timestamp - 1, address(token), address(daoCollateral), amount);
        vm.startPrank(alice);
        token.approve(address(daoCollateral), 0);

        // deadline in the past
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        daoCollateral.swapWithPermit(address(token), amount, amount, deadline, v, r, s);
        deadline = block.timestamp + 100;

        // insufficient amount
        (, v, r, s) = _getAlicePermitData(
            deadline, address(token), address(daoCollateral), amount - excessAmount
        );
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        daoCollateral.swapWithPermit(address(token), amount, amount, deadline, v, r, s);

        // bad v
        (, v, r, s) = _getAlicePermitData(deadline, address(token), address(daoCollateral), amount);
        vm.expectRevert("ERC20: transfer amount exceeds allowance");

        daoCollateral.swapWithPermit(address(token), amount, amount, deadline, v + 1, r, s);

        // bad r
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        daoCollateral.swapWithPermit(
            address(token), amount, amount, deadline, v, keccak256("bad r"), s
        );

        // bad s
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        daoCollateral.swapWithPermit(
            address(token), amount, amount, deadline, v, r, keccak256("bad s")
        );

        //bad nonce
        (v, r, s) = _getSelfPermitData(
            address(token),
            alice,
            alicePrivKey,
            address(daoCollateral),
            amount,
            deadline,
            IERC20Permit(address(stbcToken)).nonces(alice) + excessAmount
        );
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        daoCollateral.swapWithPermit(address(token), amount, amount, deadline, v, r, s);

        //bad spender
        (v, r, s) = _getSelfPermitData(
            address(token),
            bob,
            bobPrivKey,
            address(daoCollateral),
            amount,
            deadline,
            IERC20Permit(address(stbcToken)).nonces(bob)
        );
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        daoCollateral.swapWithPermit(address(token), amount, amount, deadline, v, r, s);
        vm.stopPrank();
    }

    // 4.2 Testing basic flows //
    /// @dev This test checks that the swap function works correctly
    function testRWASwap(uint256 amount) public returns (RwaMock, Eth0) {
        amount = bound(amount, 1e6, type(uint128).max - 1);
        (RwaMock token, Eth0 stbc) = setupCreationRwa1_withMint(amount);
        uint256 price = classicalOracle.getPrice(address(token));
        uint256 amountInUsd = amount * price / 1e18;
        vm.prank(alice);
        daoCollateral.swap(address(token), amount, amountInUsd);
        // it is the same as price is 1e18 except for the imprecision

        assertEq(stbc.balanceOf(alice), amountInUsd);
        return (token, stbc);
    }

    /// @dev This test checks that the swapWithPermit function works correctly
    function testRWASwapWithPermit__fork(uint256 amount) public {
        amount = bound(amount, 1e6, type(uint128).max - 1);
        (RwaMock token, Eth0 stbc) = setupCreationRwa1_withMint(amount);

        (uint256 deadline, uint8 v, bytes32 r, bytes32 s) = _getAlicePermitData(
            block.timestamp + 1 days, address(token), address(daoCollateral), amount
        );

        vm.prank(alice);
        daoCollateral.swapWithPermit(address(token), amount, amount, deadline, v, r, s);
        uint256 price = classicalOracle.getPrice(address(token));
        uint256 amountInETH = amount * price / 1e18;
        assertEq(stbc.balanceOf(alice), amountInETH);
    }

    /// @dev This test checks that the swap function works correctly with fuzzing
    function testFuzz_Swap__fork(uint256 amount, uint256 minAmountOut) public {
        // Bound amount to reasonable values
        amount = bound(amount, 1e6, type(uint128).max - 1);
        minAmountOut = bound(minAmountOut, 0, amount * 2);

        (RwaMock token,) = setupCreationRwa1_withMint(amount);
        // Get price of the token
        uint256 price = classicalOracle.getPrice(address(token));
        vm.startPrank(alice);
        if (minAmountOut > amount * price / 1e18) {
            vm.expectRevert(abi.encodeWithSelector(AmountTooLow.selector));
            daoCollateral.swap(address(token), amount, minAmountOut);
        } else {
            daoCollateral.swap(address(token), amount, minAmountOut);
            assertGe(stbcToken.balanceOf(alice), minAmountOut);
        }
        vm.stopPrank();
    }

    /// @dev This test checks that the swapWithPermit function works correctly with fuzzing
    function testFuzz_SwapWithPermit__fork(uint256 amount, uint256 minAmountOut, uint256 deadline)
        public
    {
        // Bound values to reasonable ranges
        amount = bound(amount, 1e6, type(uint128).max - 1);
        minAmountOut = bound(minAmountOut, 0, amount * 2);
        deadline = bound(deadline, block.timestamp, type(uint256).max);

        (RwaMock token,) = setupCreationRwa1_withMint(amount);

        (uint8 v, bytes32 r, bytes32 s) = _getSelfPermitData(
            address(token), alice, alicePrivKey, address(daoCollateral), amount, deadline
        );
        // Get price of the token
        uint256 price = classicalOracle.getPrice(address(token));
        vm.startPrank(alice);
        if (minAmountOut > amount * price / 1e18) {
            vm.expectRevert(abi.encodeWithSelector(AmountTooLow.selector));
            daoCollateral.swapWithPermit(address(token), amount, minAmountOut, deadline, v, r, s);
        } else {
            daoCollateral.swapWithPermit(address(token), amount, minAmountOut, deadline, v, r, s);
            assertGe(stbcToken.balanceOf(alice), minAmountOut);
        }
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            5. REDEEM
    //////////////////////////////////////////////////////////////*/
    // 5.1 Testing revert properties //

    /// @dev This test checks that the redeem function fails if the token is invalid
    function testRedeemInvalidRwaFailEarly() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(InvalidToken.selector));
        daoCollateral.redeem(address(0xdeadbeef), 1e18, 0);
        vm.stopPrank();
    }

    /// @dev This test checks that the redeem function fails if the amount is zero
    function testRedeemForStableCoinFailAmount(uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max - 1);
        (RwaMock token,) = testRWASwap(amount);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AmountIsZero.selector));
        daoCollateral.redeem(address(token), 0, 0);
    }

    /// @dev This test checks that the redeem function fails if the amount is too big
    function testMultipleRedeemForStableCoinFailWhenNotEnoughCollateral(uint256 amount) public {
        amount = bound(amount, 1e6, type(uint128).max - 1);
        (RwaMock token, Eth0 stbc) = testRWASwap(amount);

        vm.startPrank(alice);
        uint256 actualBalance = stbc.balanceOf(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                alice,
                actualBalance, // What Alice actually has
                actualBalance * 2 // What she's trying to redeem (double her balance)
            )
        );

        daoCollateral.redeem(address(token), actualBalance * 2, 0);

        vm.stopPrank();
    }

    /// @dev This test checks that the redeem function fails with insufficient balance
    /// @dev This test checks that the redeem function fails with insufficient balance
    function testMultipleRedeemForStableCoinFail__fork(uint256 amount) public {
        amount = bound(amount, 1e6, type(uint128).max - 1);
        (RwaMock token, Eth0 stbc) = testRWASwap(amount);

        vm.startPrank(alice);

        // Get the actual balance after swap
        uint256 actualBalance = stbc.balanceOf(alice);

        // Calculate half of the balance (safely)
        uint256 halfBalance = actualBalance / 2;

        // First redeem half of the balance
        daoCollateral.redeem(address(token), halfBalance, 0);

        // The remaining balance should now be actualBalance - halfBalance
        uint256 remainingBalance = stbc.balanceOf(alice);

        // Try to redeem more than remaining balance
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                alice,
                remainingBalance, // What Alice has now
                remainingBalance + 1 // More than what she has now
            )
        );

        // Attempt to redeem more than available
        daoCollateral.redeem(address(token), remainingBalance + 1, 0);

        vm.stopPrank();
    }

    /// @dev This test checks that the redeem function fails if the minAmountOut is too low
    function testRedeemShouldFailIfMinAmountOut__fork() public {
        (RwaMock token,) = testRWASwap(1e18);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AmountTooLow.selector));
        daoCollateral.redeem(address(token), 1e18, 1e18);
    }

    // 5.2 Testing basic flows //

    /// @dev This test checks that the redeem function works correctly with 6 decimals
    function testRedeemFiatWith6Decimals(uint256 amount) public {
        amount = bound(amount, 1e6, type(uint128).max - 1);
        (RwaMock token, Eth0 stbc) = testRWASwap(amount);

        vm.startPrank(alice);
        uint256 eth0Amount = stbc.balanceOf(alice);
        uint256 fee = _getDotOnePercent(amount);
        daoCollateral.redeem(address(token), eth0Amount, 0);
        vm.stopPrank();
        // The formula to calculate the amount of RWA that the user
        // should be able to get by redeeming STBC should be amountStableCoin * rwaDecimals / oraclePrice

        assertEq(stbc.balanceOf(alice), 0);
        assertApproxEqRel(token.balanceOf(alice), amount - fee, 0.00001 ether);
    }

    /// @dev This test checks that the redeem function works correctly with 18 decimals
    function testRedeemFiatFixWithWadRwa__fork() public {
        (RwaMock token, Eth0 stbc) = setupCreationRwa1();

        assertEq(token.balanceOf(alice), 0);
        deal(address(token), treasury, 99_999_999_999_999);
        vm.prank(address(daoCollateral));
        stbc.mint(alice, 99_999_999_999_999);

        vm.prank(admin);
        // redeem fee 0.01 %
        daoCollateral.setRedeemFee(1);
        // we redeem 0.000099999999999999 ETH
        // 0.01% is 10000000000
        vm.prank(alice);
        daoCollateral.redeem(address(token), 99_999_999_999_999, 0);
        uint256 price = classicalOracle.getPrice(address(token));
        assertEq(token.balanceOf(alice), (99_990_000_000_000 * 1e18) / price);
        assertEq(IERC20(stbc).balanceOf(treasuryYield), 9_999_999_999);
    }

    /// @dev This test checks that the redeem function works correctly by fuzzing the amount and the redeem fee
    function testFuzz_Redeem__fork(uint256 amount, uint256 redeemFee) public {
        // Bound values
        amount = bound(amount, 100e6, type(uint128).max - 1);
        redeemFee = bound(redeemFee, 1, MAX_REDEEM_FEE);

        (RwaMock token, Eth0 stbc) = testRWASwap(amount);
        uint256 price = classicalOracle.getPrice(address(token));

        assertEq(token.balanceOf(alice), 0);
        uint256 stbcAmount = amount * price / 1e18;
        assertEq(stbc.balanceOf(alice), stbcAmount);

        uint256 balanceBefore = stbc.balanceOf(treasuryYield);

        if (redeemFee != daoCollateral.redeemFee()) {
            vm.prank(admin);
            daoCollateral.setRedeemFee(redeemFee);
        }

        vm.startPrank(alice);
        uint256 stbcBalance = stbc.balanceOf(alice);

        // Calculate fee based on ETH0 amount (stbc)
        uint256 stableFee =
            Math.mulDiv(stbcBalance, redeemFee, BASIS_POINT_BASE, Math.Rounding.Floor);

        // Calculate the amount of ETH0 that will be burnt (minus fee)
        uint256 burnedEth0 = stbcBalance - stableFee;

        // Calculate the expected RWA amount returned based on the burnt ETH0
        // This is the direct calculation equivalent to wadTokenAmountForPrice
        uint256 expectedReturnedCollateral = Math.mulDiv(
            burnedEth0, 10 ** IERC20Metadata(address(token)).decimals(), price, Math.Rounding.Floor
        );
        // Perform redemption
        daoCollateral.redeem(address(token), stbcBalance, expectedReturnedCollateral);

        // Verify ETH0 fee collected
        uint256 balanceAfter = stbc.balanceOf(treasuryYield);
        assertEq(balanceAfter - balanceBefore, stableFee);

        // Verify RWA tokens received
        assertApproxEqRel(
            token.balanceOf(alice),
            expectedReturnedCollateral,
            0.000001e18 // 0.0001% tolerance for rounding errors
        );

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            6. REDEEM_DAO
    //////////////////////////////////////////////////////////////*/
    // 6.1 Testing revert properties //

    /// @dev This test checks that the redeemDao function fails if the token is invalid
    function testRedeemDaoShouldFailIfNotAuthorized() public {
        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        daoCollateral.redeemDao(address(0x21), 1e18);
    }

    function testRedeemDaoShouldFailIfPaused() public {
        (RwaMock token, Eth0 stbc) = testRWASwap(1e18);
        vm.prank(pauser);
        daoCollateral.pause();
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        vm.prank(daoredeemer);
        daoCollateral.redeemDao(address(token), 1e18);
    }

    /// @dev This test checks that the redeemDao function fails if the amount is zero
    function testRedeemDaoShouldFailIfAmountZero() public {
        vm.startPrank(daoredeemer);
        vm.expectRevert(abi.encodeWithSelector(AmountIsZero.selector));
        daoCollateral.redeemDao(address(0x21), 0);
        vm.stopPrank();
    }

    /// @dev This test checks that the redeemDao function fails if the amount is too low
    function testRedeemDaoShouldFailIfAmountTooLow__fork(uint256 amount, uint256 amountToRedeem)
        public
    {
        amount = bound(amount, 1e6, type(uint128).max - 1);
        amountToRedeem = bound(amount, 1e6, 1e12 - 1);
        (RwaMock token, Eth0 stbc) = testRWASwap(amount);

        vm.prank(alice);
        stbc.transfer(daoredeemer, amount);

        vm.startPrank(daoredeemer);
        uint256 price = classicalOracle.getPrice(address(token));
        if (amountToRedeem > amount * price / 1e18) {
            vm.expectRevert(abi.encodeWithSelector(AmountTooLow.selector));
            daoCollateral.redeemDao(address(token), amountToRedeem);
        } else {
            daoCollateral.redeemDao(address(token), amountToRedeem);
        }
        vm.stopPrank();
    }

    /// @dev This test checks that the redeemDao function fails if the token is invalid
    function testRedeemDaoShouldFailIfInvalidToken() public {
        vm.startPrank(daoredeemer);
        vm.expectRevert(abi.encodeWithSelector(InvalidToken.selector));
        daoCollateral.redeemDao(address(0xdeadbeef), 1e18);
        vm.stopPrank();
    }

    // 6.2 Testing basic flows //

    /// @dev This test checks that the redeemDao function works correctly
    function testRedeemDao__fork(uint256 amount) public {
        amount = bound(amount, 1e6, type(uint128).max - 1);
        (RwaMock token, Eth0 stbc) = testRWASwap(amount);

        vm.prank(alice);
        stbc.transfer(daoredeemer, amount);
        assertEq(token.balanceOf(daoredeemer), 0);
        vm.prank(daoredeemer);
        daoCollateral.redeemDao(address(token), amount);

        assertEq(stbc.balanceOf(daoredeemer), 0);
        assertGt(token.balanceOf(daoredeemer), 0);
    }

    /*//////////////////////////////////////////////////////////////
              7. PAUSE, UNPAUSE, PAUSE_SWAP & UNPAUSE_SWAP
    //////////////////////////////////////////////////////////////*/
    // 7.1 Testing revert properties //

    /// @dev This test checks that the unpause function fails if the caller is not the admin
    function testUnpauseFailIfNotAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        daoCollateral.unpause();

        vm.prank(pauser);
        daoCollateral.pause();
        vm.prank(unpauser);
        daoCollateral.unpause();
    }

    /// @dev This test checks that the unpauseSwap function fails if the swap is not paused
    function testUnpauseSwapFailIfNotPaused() public {
        vm.expectRevert(abi.encodeWithSelector(SwapMustBePaused.selector));
        vm.prank(admin);
        daoCollateral.unpauseSwap();
    }

    /// @dev This test checks that the pauseSwap function fails if the swap is already paused
    function testPauseSwapShouldFailIfPaused() public {
        vm.prank(pauser);
        daoCollateral.pauseSwap();
        assertEq(daoCollateral.isSwapPaused(), true);
        vm.expectRevert(abi.encodeWithSelector(SwapMustNotBePaused.selector));
        vm.prank(pauser);
        daoCollateral.pauseSwap();
    }

    /// @dev This test checks that the swap function fails if the swap is paused
    function testSwapShouldFailIfPaused() public {
        uint256 amount = 10_000_000_000;

        (RwaMock token,) = setupCreationRwa1_withMint(amount);

        vm.prank(pauser);
        daoCollateral.pause();
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        vm.prank(alice);
        daoCollateral.swap(address(token), amount, 0);
    }

    /// @dev This test checks that the swapWithPermit function fails if the swap is paused
    function testSwapWithPermitShouldFailIfPaused() public {
        uint256 amount = 10_000_000_000;
        (RwaMock token,) = setupCreationRwa1_withMint(amount);

        (uint256 deadline, uint8 v, bytes32 r, bytes32 s) = _getAlicePermitData(
            block.timestamp + 100, address(token), address(daoCollateral), amount
        );

        vm.prank(pauser);
        daoCollateral.pause();
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        vm.prank(alice);
        daoCollateral.swapWithPermit(address(token), amount, amount, deadline, v, r, s);
    }

    // 7.2 Testing basic flows //

    /// @dev This test checks that the pauseSwap function works correctly
    function testPauseSwap() public {
        vm.prank(pauser);
        daoCollateral.pauseSwap();

        assertEq(daoCollateral.isSwapPaused(), true);
    }

    /// @dev This test checks that the unpauseSwap function works correctly
    function testUnpauseSwap() public {
        vm.prank(pauser);
        daoCollateral.pauseSwap();

        vm.prank(unpauser);
        daoCollateral.unpauseSwap();
        assertEq(daoCollateral.isSwapPaused(), false);
    }

    /// @dev This test checks that the isSwapPaused function works correctly
    function testGetSwapPaused() public {
        assertEq(daoCollateral.isSwapPaused(), false);
        vm.prank(pauser);
        daoCollateral.pauseSwap();
        assertEq(daoCollateral.isSwapPaused(), true);
    }

    /*//////////////////////////////////////////////////////////////
                    8. PAUSE_REDEEM & UNPAUSE_REDEEM
    //////////////////////////////////////////////////////////////*/
    // 8.1 Testing revert properties //

    /// @dev This test checks that the redeem function fails if the redeem is paused
    function testRedeemShouldFailIfRedeemPaused() public {
        (RwaMock token,) = testRWASwap(1e6);

        vm.prank(pauser);
        daoCollateral.pauseRedeem();

        vm.expectRevert(abi.encodeWithSelector(RedeemMustNotBePaused.selector));
        vm.prank(alice);
        daoCollateral.redeem(address(token), 1e18, 0);
    }

    /// @dev This test checks that the unpauseRedeem function fails if the redeem is not paused
    function testUnpauseRedeemShouldFailIfNotPaused() public {
        vm.expectRevert(abi.encodeWithSelector(RedeemMustBePaused.selector));
        vm.prank(admin);
        daoCollateral.unpauseRedeem();
    }

    /// @dev This test checks that the redeem function fails if the redeem is paused
    function testRedeemShouldFailIfPaused__fork() public {
        (RwaMock token,) = testRWASwap(100e18);

        vm.prank(pauser);
        daoCollateral.pause();

        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        vm.prank(alice);
        daoCollateral.redeem(address(token), 100e18, 1e6);

        vm.prank(unpauser);
        daoCollateral.unpause();

        vm.prank(alice);
        daoCollateral.redeem(address(token), 100e18, 1e6);
    }

    /// @dev This test checks that the unpauseRedeem function fails if the caller is not the admin
    function testUnPauseRedeemShouldFailIfNotAdmin() public {
        vm.prank(pauser);
        daoCollateral.pauseRedeem();

        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        daoCollateral.unpauseRedeem();
    }

    // 8.2 Testing basic flows //

    /// @dev This test checks that the isRedeemPaused function works correctly
    function testGetRedeemPaused() public {
        assertEq(daoCollateral.isRedeemPaused(), false);
        vm.prank(pauser);
        daoCollateral.pauseRedeem();
        assertEq(daoCollateral.isRedeemPaused(), true);

        vm.prank(unpauser);
        daoCollateral.unpauseRedeem();
        assertEq(daoCollateral.isRedeemPaused(), false);
    }

    /// @dev This test checks that the unpauseRedeem function emits the RedeemUnPaused event
    function testUnPauseRedeemEmitEvent() public {
        vm.startPrank(pauser);
        daoCollateral.pauseRedeem();
        vm.expectEmit();
        emit RedeemUnPaused();
        vm.startPrank(unpauser);
        daoCollateral.unpauseRedeem();
    }

    /*//////////////////////////////////////////////////////////////
                            8. REDEEM_FEE
    //////////////////////////////////////////////////////////////*/
    // 9.1 Testing revert properties //

    /// @dev This test checks that the setRedeemFee function fails if the redeem fee is the same as the current redeem fee
    function testSetRedeemFeeShouldFailIfSameValue() public {
        vm.prank(admin);
        daoCollateral.setRedeemFee(52);
        vm.expectRevert(abi.encodeWithSelector(SameValue.selector));
        vm.prank(admin);
        daoCollateral.setRedeemFee(52);
    }

    /// @dev This test checks that the setRedeemFee function fails if the redeem fee is too big
    function testSetRedeemFeeShouldFailIfAmountTooBig() public {
        vm.expectRevert(abi.encodeWithSelector(RedeemFeeTooBig.selector));
        vm.prank(admin);
        daoCollateral.setRedeemFee(MAX_REDEEM_FEE + 1);
    }

    /// @dev This test checks that the setRedeemFee function fails if the caller is not the admin
    function testSettersShouldFailIfNotAuthorized() public {
        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        daoCollateral.setRedeemFee(MAX_REDEEM_FEE);
    }

    // 9.2 Testing basic flows //

    /// @dev This test checks that the setRedeemFee function works correctly with fuzzing
    function testFuzz_SetRedeemFee(uint256 fee) public {
        vm.startPrank(admin);

        if (fee > MAX_REDEEM_FEE) {
            vm.expectRevert(abi.encodeWithSelector(RedeemFeeTooBig.selector));
            daoCollateral.setRedeemFee(fee);
        } else if (fee == daoCollateral.redeemFee()) {
            vm.expectRevert(abi.encodeWithSelector(SameValue.selector));
            daoCollateral.setRedeemFee(fee);
        } else if (fee == 0) {
            vm.expectRevert(abi.encodeWithSelector(RedeemFeeCannotBeZero.selector));
            daoCollateral.setRedeemFee(0);
        } else {
            daoCollateral.setRedeemFee(fee);
            assertEq(daoCollateral.redeemFee(), fee);
        }
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                9. CBR
    //////////////////////////////////////////////////////////////*/
    // 9.1 Testing revert properties //

    /// @dev This test checks that the activateCBR function fails if the CBR is too high
    function testActivateCBRShouldFailIfCBRIsTooHigh__fork(uint256 amount) public {
        amount = bound(amount, 1e6, type(uint128).max - 1);
        (RwaMock rwa1, Eth0 stbc) = setupCreationRwa1_withMint(amount);
        (RwaMock rwa2,) = setupCreationRwa2_withMint(amount);
        deal(address(rwa1), alice, amount * 2);

        vm.startPrank(alice);
        daoCollateral.swap(address(rwa1), amount, amount);
        daoCollateral.swap(address(rwa2), amount, amount);
        vm.stopPrank();

        // push MMF price to 0.5 stETH per wstETH
        vm.mockCall(
            address(dataSource),
            abi.encodeWithSelector(IAggregator.latestRoundData.selector),
            abi.encode(0, 0.5e18, block.timestamp, block.timestamp, 0)
        );
        assertEq(classicalOracle.getPrice(address(rwa1)), 0.5e18);
        // increase rwa2 amount in treasury to make cbrCoef greater than
        deal(address(rwa2), treasury, amount * 2);
        // activate cbr
        assertEq(daoCollateral.cbrCoef(), 0);
        // increase usdBalanceInInsurance
        vm.prank(address(daoCollateral));
        deal(address(stbc), usdInsurance, amount * 1e12);
        vm.expectRevert(abi.encodeWithSelector(CBRIsTooHigh.selector));
        vm.prank(admin);
        daoCollateral.activateCBR(5e18);
        assertFalse(daoCollateral.isCBROn());
        assertEq(daoCollateral.cbrCoef(), 0);
    }

    /// @dev This test checks that the activateCBR function fails if the CBR is zero
    function testActivateCBRShouldFailIfCBRisNull__fork(uint256 amount) public {
        amount = bound(amount, 1e6, type(uint128).max - 1);
        (RwaMock rwa1, Eth0 stbc) = setupCreationRwa1_withMint(amount);
        (RwaMock rwa2,) = setupCreationRwa2_withMint(amount);
        deal(address(rwa1), alice, amount * 2);

        vm.startPrank(alice);
        // we swap amountInRWA of MMF for amount STBC
        daoCollateral.swap(address(rwa1), amount, amount);
        daoCollateral.swap(address(rwa2), amount, amount);
        vm.stopPrank();

        assertEq(stbc.balanceOf(usdInsurance), 0);
        assertEq(ERC20(address(stbc)).balanceOf(treasuryYield), 0);

        // push MMF price to 0.5$
        vm.mockCall(
            address(dataSource),
            abi.encodeWithSelector(IAggregator.latestRoundData.selector),
            abi.encode(0, 0.5e18, block.timestamp, block.timestamp, 0)
        );

        // burn all rwa1 and rwa2 in treasury to make cbrCoef equal to 0
        deal(address(rwa1), treasury, 0);

        // activate cbr
        assertEq(daoCollateral.cbrCoef(), 0);
        vm.expectRevert(abi.encodeWithSelector(CBRIsNull.selector));
        vm.prank(admin);
        daoCollateral.activateCBR(0); //0
        assertFalse(daoCollateral.isCBROn());
        assertEq(daoCollateral.cbrCoef(), 0);
    }

    /// @dev This test checks that the deactivateCBR function fails if the CBR is not active
    function testDeactivateCBRShouldFailIfNotActive() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(SameValue.selector));
        daoCollateral.deactivateCBR();
    }

    // 9.2 Testing basic flows //

    /// @dev This test checks that the rounding in the CBR coefficient calculation works correctly
    function testRoundingInCbrCoefCalculation(uint256 amount) public pure {
        amount = bound(amount, 100e18, type(uint128).max - 1);
        uint256 wadTotalRwaValueInUsd = amount - 1;
        uint256 totalUsdSupply = amount;
        uint256 price = Math.mulDiv(wadTotalRwaValueInUsd, SCALAR_ONE, amount);
        uint256 price2 = Math.mulDiv(amount - 100, SCALAR_ONE, amount);

        assertEq(price, price2);
        uint256 cbrCoef_Floor = Math.mulDiv(wadTotalRwaValueInUsd, SCALAR_ONE, totalUsdSupply);

        uint256 cbrCoef_Ceil =
            Math.mulDiv(wadTotalRwaValueInUsd, SCALAR_ONE, totalUsdSupply, Math.Rounding.Ceil);
        assertLt(cbrCoef_Floor, cbrCoef_Ceil); // we should lean toward cbrCoef_Floor
            // 999999999999999999 < 1000000000000000000
    }

    /// @dev This test checks that the activateCBR function works correctly with fuzzing
    function testFuzz_ActivateCBR(uint256 coefficient) public {
        // First setup some initial state
        (RwaMock rwa1,) = setupCreationRwa1_withMint(100e6);
        vm.prank(alice);
        daoCollateral.swap(address(rwa1), 100e6, 0);

        vm.startPrank(admin);

        if (coefficient > SCALAR_ONE) {
            vm.expectRevert(abi.encodeWithSelector(CBRIsTooHigh.selector));
            daoCollateral.activateCBR(coefficient);
        } else if (coefficient == 0) {
            vm.expectRevert(abi.encodeWithSelector(CBRIsNull.selector));
            daoCollateral.activateCBR(coefficient);
        } else {
            daoCollateral.activateCBR(coefficient);
            assertEq(daoCollateral.cbrCoef(), coefficient);
            assertTrue(daoCollateral.isCBROn());
            assertTrue(daoCollateral.isSwapPaused());
        }
        vm.stopPrank();
    }

    /// @dev This test checks that the deactivateCBR function works correctly
    function testDeactivateCBR() public {
        vm.startPrank(admin);

        // activate cbr
        daoCollateral.activateCBR(1);

        vm.expectEmit();
        emit CBRDeactivated();
        daoCollateral.deactivateCBR();
        assertFalse(daoCollateral.isCBROn());
    }
}
