// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import "forge-std/console.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {Pausable} from "openzeppelin-contracts/utils/Pausable.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IUSDC} from "test/interfaces/IUSDC.sol";
import {SetupTest} from "./setup.t.sol";
import {IRwaMock} from "src/interfaces/token/IRwaMock.sol";
import {RwaMock} from "src/mock/rwaMock.sol";
import {MyERC20} from "src/mock/myERC20.sol";
import {Eth0} from "src/token/Eth0.sol";
import {IERC20Errors} from "openzeppelin-contracts/interfaces/draft-IERC6093.sol";
import {Normalize} from "src/utils/normalize.sol";

import {Math} from "openzeppelin-contracts/utils/math/Math.sol";
import {IOracle} from "src/interfaces/oracles/IOracle.sol";

import {DaoCollateral} from "src/daoCollateral/DaoCollateral.sol";

import {IERC20Permit} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SigUtils} from "test/utils/sigUtils.sol";
import {
    MAX_REDEEM_FEE,
    SCALAR_ONE,
    BASIS_POINT_BASE,
    BASIS_POINT_BASE,
    ONE_YEAR,
    STETH,
    WSTETH
} from "src/constants.sol";
import {USDC} from "src/mock/constants.sol";
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

contract DaoCollateralTest is SetupTest {
    using Normalize for uint256;

    ERC1271WalletMock public erc1271Mock;

    event RedeemUnPaused();
    event CBRDeactivated();

    /*//////////////////////////////////////////////////////////////
                            1. SETUP & HELPERS
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        uint256 forkId = vm.createFork("eth");
        vm.selectFork(forkId);
        super.setUp();

        erc1271Mock = new ERC1271WalletMock(alice);
        vm.deal(alice, 1 ether);
    }

    function setupCreationRwaLido() public returns (address, Eth0) {
        address ethCollateralToken = address(WSTETH);
        vm.label(ethCollateralToken, "WSTETH Forked");

        //dont really need the IRWA mock here, but dont wanna rewrite the other yet
        if (!tokenMapping.isEth0Collateral(ethCollateralToken)) {
            vm.prank(admin);
            tokenMapping.addEth0CollateralToken(ethCollateralToken);
        }

        Eth0 stbc = stbcToken;
        whitelistPublisher(address(ethCollateralToken), address(stbc));
        _setupBucket(ethCollateralToken, address(stbc));
        _setOraclePrice(ethCollateralToken, 10 ** 18); //decimals we could also fetch from stETh, but not needed to do a RPC call everytime rn

        return (ethCollateralToken, stbc);
    }

    // This setup create a new RWA token with X decimals and set the price to 1
    function setupCreationRwa1(uint8 decimals) public returns (RwaMock, Eth0) {
        rwaFactory.createRwa("Hashnote US Yield Coin", "USYC", decimals);
        address token = rwaFactory.getRwaFromSymbol("USYC");
        vm.label(token, "USYC Mock");

        _whitelistRWA(token, alice);
        _whitelistRWA(token, address(daoCollateral));
        _whitelistRWA(token, treasury);
        _linkSTBCToRwa(IRwaMock(token));
        Eth0 stbc = stbcToken;
        // add mock oracle for rwa token
        whitelistPublisher(address(token), address(stbc));
        _setupBucket(token, address(stbc));
        //  vm.label(USYC_PRICE_FEED_MAINNET, "USYC_PRICE_FEED");
        _setOraclePrice(token, 10 ** decimals);

        return (RwaMock(token), stbc);
    }

    // This setup create a new RWA token with X decimals, mint it to alice and set the price to 1
    function setupCreationRwa2(uint8 decimals) public returns (RwaMock, Eth0) {
        rwaFactory.createRwa("Hashnote US Yield Coin 2", "USYC2", decimals);
        address token = rwaFactory.getRwaFromSymbol("USYC2");
        vm.label(token, "USYC2 Mock");

        _whitelistRWA(token, alice);
        _whitelistRWA(token, address(daoCollateral));
        _whitelistRWA(token, treasury);
        _linkSTBCToRwa(IRwaMock(token));
        Eth0 stbc = stbcToken;
        // add mock oracle for rwa token
        whitelistPublisher(address(token), address(stbc));
        _setupBucket(token, address(stbc));
        // vm.label(USYC_PRICE_FEED_MAINNET, "USYC_PRICE_FEED");
        _setOraclePrice(token, 10 ** decimals);

        return (RwaMock(token), stbc);
    }

    // This setup create a new RWA token with X decimals, mint it to alice and set the price to 1
    function setupCreationRwa1_withMint(uint8 decimals, uint256 amount)
        public
        returns (RwaMock, Eth0)
    {
        (RwaMock token, Eth0 stbc) = setupCreationRwa1(decimals);
        token.mint(alice, amount);
        vm.prank(alice);
        token.approve(address(daoCollateral), amount);
        return (token, stbc);
    }

    // This setup create a new RWA token with X decimals, mint it to alice and set the price to 1
    function setupCreationRwa2_withMint(uint8 decimals, uint256 amount)
        public
        returns (RwaMock, Eth0)
    {
        (RwaMock token, Eth0 stbc) = setupCreationRwa2(decimals);
        token.mint(alice, amount);
        vm.prank(alice);
        token.approve(address(daoCollateral), amount);
        return (token, stbc);
    }

    /// @dev This test checks that the swap and redeem functions work correctly when the supply plus the amount is greater than the RWA backing
    function testSwapAndRedeemWhenSupplyPlusAmountIsRWABackingShouldWork() public {
        // Arrange
        uint256 rwaAmount = 1000e6;
        (RwaMock rwa1, Eth0 stbc) = setupCreationRwa1(6);
        // Setup initial RWA token state
        rwa1.mint(alice, rwaAmount);
        uint256 amount = ERC20(address(rwa1)).balanceOf(alice);

        // Setup oracle price ($1)
        _setOraclePrice(address(rwa1), 1e6);
        assertEq(classicalOracle.getPrice(address(rwa1)), 1e18);

        // Setup Bob's initial state
        uint256 amountInRWA = (amount * 1e18) / classicalOracle.getPrice(address(rwa1));
        _whitelistRWA(address(rwa1), bob);
        rwa1.mint(bob, amountInRWA);

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

    function testDustAmountShouldWork() external {
        (address wseth, Eth0 eth0Token) = setupCreationRwaLido();
        // 1 wstETH = 1 ETH
        _setStEthRatio(1 ether, 1 ether);

        deal(WSTETH, alice, 1 ether);

        // Alice wants to mint ETH0
        vm.startPrank(alice);
        IERC20(wseth).approve(address(daoCollateral), 1 ether);
        daoCollateral.swap(WSTETH, 1 ether, 1 ether);
        vm.stopPrank();

        uint256 amount = 10_000;

        // 1 stETH = 1.000...001 ETH
        _setStEthRatio(1 ether + amount, 1 ether);

        // Bob is an attacker trying to extract max value
        vm.startPrank(bob);
        IERC20(wseth).approve(address(daoCollateral), type(uint256).max);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        daoCollateral.swap(WSTETH, 1, 1);

        vm.stopPrank();

        //no ETH0 minted out of thin air!
        assertEq(eth0Token.balanceOf(bob), 0);

        deal(WSTETH, alice, 1 ether);

        // Alice is a real user who wants to mint ETH0
        vm.startPrank(alice);
        IERC20(wseth).approve(address(daoCollateral), 1 ether);
        daoCollateral.swap(WSTETH, 1 ether, 1 ether);
        vm.stopPrank();
        assertEq(eth0Token.balanceOf(alice), 2 ether);
    }

    function _setStEthRatio(uint256 pooledEth, uint256 supply) private {
        uint256 DEPOSIT_SIZE = 32 ether;
        bytes32 TOTAL_SHARES_POSITION = keccak256("lido.StETH.totalShares");
        bytes32 CL_BALANCE_POSITION = keccak256("lido.Lido.beaconBalance");
        bytes32 DEPOSITED_VALIDATORS_POSITION = keccak256("lido.Lido.depositedValidators");
        bytes32 CL_VALIDATORS_POSITION = keccak256("lido.Lido.beaconValidators");
        bytes32 BUFFERED_ETHER_POSITION = keccak256("lido.Lido.bufferedEther");
        uint256 validators = pooledEth / DEPOSIT_SIZE;
        uint256 buffer = pooledEth - validators * DEPOSIT_SIZE;

        vm.store(STETH, DEPOSITED_VALIDATORS_POSITION, bytes32(validators));
        vm.store(STETH, CL_VALIDATORS_POSITION, bytes32(validators));
        vm.store(STETH, CL_BALANCE_POSITION, bytes32(validators * DEPOSIT_SIZE));
        vm.store(STETH, BUFFERED_ETHER_POSITION, bytes32(buffer));
        vm.store(STETH, TOTAL_SHARES_POSITION, bytes32(supply));
    }

    /// @dev This test checks that the swap and redeem functions work correctly when the supply plus the amount is greater than the RWA backing
    function testSwapAndRedeemWhenSupplyPlusAmountIsRWABackingShouldWorkEth() public {
        // Arrange
        uint256 rwaAmount = 1000e6;
        console.log("Initial RWA amount:", rwaAmount);

        (address rwa1, Eth0 stbc) = setupCreationRwaLido();
        console.log("Setup complete - RWA address:", rwa1);
        console.log("Setup complete - STBC address:", address(stbc));

        // Setup initial RWA token state
        deal(rwa1, alice, rwaAmount, false);
        console.log("Dealt RWA to alice:", rwaAmount);

        uint256 amount = ERC20(rwa1).balanceOf(alice);
        console.log("Alice's RWA balance:", amount);

        // Setup Bob's initial state
        uint256 amountInRWA = (amount * 1e18) / classicalOracle.getPrice(rwa1);
        console.log("Amount in RWA for Bob:", amountInRWA);

        console.log("Oracle price:", classicalOracle.getPrice(rwa1));

        deal(rwa1, bob, amountInRWA, false);
        console.log("Dealt RWA to bob:", amountInRWA);

        // Act - Part 1: Swap RWA for stablecoins
        vm.startPrank(bob);
        ERC20(rwa1).approve(address(daoCollateral), amountInRWA);
        console.log("Bob approved daoCollateral to spend RWA");

        daoCollateral.swap(rwa1, amountInRWA, 0);
        console.log("Swap completed");

        // Get stable balance after swap
        uint256 stbcBalance = ERC20(address(stbc)).balanceOf(bob);
        console.log("Bob's STBC balance after swap:", stbcBalance);

        // Act - Part 2: Redeem stablecoins back to RWA
        stbc.approve(address(daoCollateral), stbcBalance);
        console.log("Bob approved daoCollateral to spend STBC");

        daoCollateral.redeem(rwa1, stbcBalance, 0);
        console.log("Redeem completed");
        vm.stopPrank();

        // Calculate expected RWA amount considering the redemption fee
        uint256 redemptionFee = Math.mulDiv(
            stbcBalance, daoCollateral.redeemFee(), BASIS_POINT_BASE, Math.Rounding.Floor
        );
        console.log("Redemption fee:", redemptionFee);

        uint256 amountRedeemedMinusFee = stbcBalance - redemptionFee;
        console.log("Amount redeemed minus fee:", amountRedeemedMinusFee);

        uint256 wadPriceInUSD = classicalOracle.getPrice(rwa1);
        console.log("WAD price in USD:", wadPriceInUSD);

        uint8 decimals = IERC20Metadata(rwa1).decimals();
        console.log("RWA decimals:", decimals);

        uint256 expectedRwaAmount =
            amountRedeemedMinusFee.wadTokenAmountForPrice(wadPriceInUSD, decimals);
        console.log("Expected RWA amount:", expectedRwaAmount);

        // Assert
        uint256 bobRwaBalance = ERC20(rwa1).balanceOf(bob);
        console.log("Bob's final RWA balance:", bobRwaBalance);
        assertEq(bobRwaBalance, expectedRwaAmount, "Incorrect RWA balance");

        uint256 bobStbcBalance = ERC20(address(stbc)).balanceOf(bob);
        console.log("Bob's final STBC balance:", bobStbcBalance);
        assertEq(bobStbcBalance, 0, "Stable balance should be 0");

        uint256 treasuryYieldBalance = ERC20(address(stbc)).balanceOf(treasuryYield);
        console.log("Treasury yield balance:", treasuryYieldBalance);
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
        (RwaMock token,) = setupCreationRwa1_withMint(6, amount);

        vm.prank(alice);
        // expect not authorized
        // vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        daoCollateral.swap(address(token), amount, 0);
    }

    /// @dev This test checks that the swap function fails if the amount is too big
    function testRWASwapAmountTooBig(uint256 amount) public {
        amount = bound(amount, type(uint128).max, type(uint256).max - 1);
        amount += 1;
        (RwaMock token,) = setupCreationRwa1_withMint(6, amount);

        vm.expectRevert(abi.encodeWithSelector(AmountTooBig.selector));
        vm.prank(alice);
        daoCollateral.swap(address(token), amount, 0);
    }

    /// @dev This test checks that the swapWithPermit function fails if the amount is too big
    function testRWASwapWithPermitAmountTooBig(uint256 amount) public {
        amount = bound(amount, type(uint128).max, type(uint256).max - 1);
        amount += 1;
        (RwaMock token,) = setupCreationRwa1_withMint(6, amount);

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
        (RwaMock token,) = setupCreationRwa1_withMint(6, amount);

        // it is the same as price is 1e18 except for the imprecision
        uint256 amountInUsd = amount * 1e12;
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AmountTooLow.selector));
        daoCollateral.swap(address(token), amount, amountInUsd + excessAmount);
    }

    /// @dev This test checks that the swap function fails if the amount is zero
    function testSwapShouldFailIfAmountZero() public {
        uint256 amount = 0;
        (RwaMock token,) = setupCreationRwa1_withMint(6, amount);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AmountIsZero.selector));
        daoCollateral.swap(address(token), amount, 0);
    }

    /// @dev This test checks that the swap function fails if the oracle returns a price of 0 for the collateral token
    function testSwapShouldFailIfOracleReturnsZeroPrice() public {
        uint256 amount = 100e6;
        (RwaMock rwaToken,) = setupCreationRwa1_withMint(6, amount);
        address collateralToken = address(rwaToken);

        vm.mockCall(
            address(classicalOracle),
            abi.encodeWithSelector(IOracle.getPrice.selector, collateralToken),
            abi.encode(0) // Return 0 for the price
        );

        vm.startPrank(alice);
        IERC20(collateralToken).approve(address(daoCollateral), amount);
        vm.expectRevert(abi.encodeWithSelector(AmountTooLow.selector));
        daoCollateral.swap(collateralToken, amount, 0);
        vm.stopPrank();

        vm.clearMockedCalls();
    }

    /// @dev This test checks that the swapWithPermit function fails if the amount is too low
    function testSwapWithPermitShouldFailIfAmountTooLow(uint256 amount, uint256 excessAmount)
        public
    {
        amount = bound(amount, 10e6, type(uint128).max);
        excessAmount = bound(excessAmount, 1, type(uint128).max);
        (RwaMock token,) = setupCreationRwa1_withMint(6, amount);

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
        setupCreationRwa1_withMint(6, amount);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(InvalidToken.selector));
        daoCollateral.swap(address(0x21), amount, 0);
    }

    /// @dev This test checks that the swapWithPermit function fails if the token is invalid
    function testSwapWithPermitShouldFailIfInvalidToken() public {
        uint256 amount = 10_000_000_000;
        setupCreationRwa1_withMint(6, amount);

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
    function testSwapWithPermitFailingERC20Permit(uint256 amount, uint256 excessAmount) public {
        amount = bound(amount, 100e6, type(uint128).max);
        excessAmount = bound(excessAmount, 1, amount);
        (RwaMock token,) = setupCreationRwa1_withMint(6, amount);

        // swap for ETH0
        (uint256 deadline, uint8 v, bytes32 r, bytes32 s) =
            _getAlicePermitData(block.timestamp - 1, address(token), address(daoCollateral), amount);
        vm.startPrank(alice);
        token.approve(address(daoCollateral), 0);

        // deadline in the past
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(daoCollateral), 0, amount
            )
        );
        daoCollateral.swapWithPermit(address(token), amount, amount, deadline, v, r, s);
        deadline = block.timestamp + 100;

        // insufficient amount
        (, v, r, s) = _getAlicePermitData(
            deadline, address(token), address(daoCollateral), amount - excessAmount
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(daoCollateral), 0, amount
            )
        );
        daoCollateral.swapWithPermit(address(token), amount, amount, deadline, v, r, s);

        // bad v
        (, v, r, s) = _getAlicePermitData(deadline, address(token), address(daoCollateral), amount);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(daoCollateral), 0, amount
            )
        );

        daoCollateral.swapWithPermit(address(token), amount, amount, deadline, v + 1, r, s);

        // bad r
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(daoCollateral), 0, amount
            )
        );
        daoCollateral.swapWithPermit(
            address(token), amount, amount, deadline, v, keccak256("bad r"), s
        );

        // bad s
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(daoCollateral), 0, amount
            )
        );
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
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(daoCollateral), 0, amount
            )
        );
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
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(daoCollateral), 0, amount
            )
        );
        daoCollateral.swapWithPermit(address(token), amount, amount, deadline, v, r, s);
        vm.stopPrank();
    }

    /// @dev This test checks that the swap is paused after the CBR is activated
    function testSwapPausedAfterCBROn(uint256 amount, uint256 newPrice, uint256 cbrCoef) public {
        amount = bound(amount, 10e6, type(uint128).max);
        newPrice = bound(newPrice, 1e2, 1e5);
        cbrCoef = bound(cbrCoef, 0.01 ether, 1 ether);
        (RwaMock rwa1, Eth0 stbc) = setupCreationRwa1_withMint(6, amount);
        assertEq(classicalOracle.getPrice(address(rwa1)), 1e18);
        assertEq(ERC20(address(rwa1)).balanceOf(treasury), 0);

        uint256 balanceTreasuryBefore = ERC20(address(rwa1)).balanceOf(treasury);

        // Alice swaps RWA for ETH0
        vm.startPrank(alice);
        ERC20(address(rwa1)).approve(address(daoCollateral), amount);
        daoCollateral.swap(address(rwa1), amount, amount);
        vm.stopPrank();

        // Check balances after swap
        assertEq(ERC20(address(stbc)).balanceOf(alice), amount * 1e12);
        assertEq(ERC20(address(rwa1)).balanceOf(treasury), balanceTreasuryBefore + amount);
        assertEq(stbc.balanceOf(usdInsurance), 0);
        assertEq(ERC20(address(stbc)).balanceOf(treasuryYield), 0);
        assertEq(ERC20(address(stbc)).totalSupply(), amount * 1e12);

        // Update oracle price
        _setOraclePrice(address(rwa1), newPrice);
        assertEq(classicalOracle.getPrice(address(rwa1)), newPrice * 1e12);

        // Activate and check cbr coefficient
        vm.prank(admin);
        daoCollateral.setRedeemFee(1);
        vm.prank(admin);
        daoCollateral.activateCBR(cbrCoef);

        // Try to swap
        vm.prank(alice);
        ERC20(address(rwa1)).approve(address(daoCollateral), amount);
        vm.expectRevert(abi.encodeWithSelector(SwapMustNotBePaused.selector));
        // Should revert
        daoCollateral.swap(address(rwa1), amount, amount);
        vm.stopPrank();

        // Swap is paused
        assertEq(daoCollateral.isSwapPaused(), true);
        assertEq(daoCollateral.isCBROn(), true);
        assertEq(daoCollateral.cbrCoef(), cbrCoef);
        vm.stopPrank();
    }

    // 4.2 Testing basic flows //
    /// @dev This test checks that the swap function works correctly
    function testRWASwap(uint256 amount) public returns (RwaMock, Eth0) {
        amount = bound(amount, 1e6, type(uint128).max - 1);
        (RwaMock token, Eth0 stbc) = setupCreationRwa1_withMint(6, amount);

        uint256 amountInUsd = amount * 1e12;
        vm.prank(alice);
        daoCollateral.swap(address(token), amount, amountInUsd);
        // it is the same as price is 1e18 except for the imprecision

        assertEq(stbc.balanceOf(alice), amountInUsd);
        return (token, stbc);
    }

    /// @dev This test checks that the swapWithPermit function works correctly
    function testRWASwapWithPermit(uint256 amount) public {
        amount = bound(amount, 1e6, type(uint128).max - 1);
        (RwaMock token, Eth0 stbc) = setupCreationRwa1_withMint(6, amount);

        (uint256 deadline, uint8 v, bytes32 r, bytes32 s) = _getAlicePermitData(
            block.timestamp + 1 days, address(token), address(daoCollateral), amount
        );

        vm.prank(alice);
        daoCollateral.swapWithPermit(address(token), amount, amount, deadline, v, r, s);
        // it is the same as price is 1e18 except for the imprecision
        uint256 amountInUsd = amount * 1e12;
        assertEq(stbc.balanceOf(alice), amountInUsd);
    }

    /// @dev This test checks that the swap function works correctly with 27 decimals
    function testRWAWith27DecimalsSwap(uint256 amount) public returns (RwaMock, Eth0) {
        amount = bound(amount, 1e18, type(uint128).max - 1);
        (RwaMock token, Eth0 stbc) = setupCreationRwa1_withMint(27, amount);
        _setOraclePrice(address(token), 1000e27);
        uint256 amountInEth = (amount * 1000e18) / 1e27;
        assertEq(token.balanceOf(treasury), 0);
        vm.prank(alice);
        daoCollateral.swap(address(token), amount, 0);
        // the formula to be used to calculate the correct amount of ETH0 should be rwaAmount * price / rwaDecimals
        assertApproxEqRel(stbc.balanceOf(alice), amountInEth, 0.000001e18);
        // RWA token is now on bucket and not on dao Collateral
        assertEq(token.balanceOf(address(daoCollateral)), 0);
        assertEq(token.balanceOf(treasury), amount);
        assertEq(token.balanceOf(alice), 0);

        return (token, stbc);
    }

    /// @dev This test checks that the swapWithPermit function works correctly with 27 decimals
    function testRWAWith27DecimalsSwapWithPermit(uint256 amount) public {
        amount = bound(amount, 1e18, type(uint128).max - 1);
        (RwaMock token, Eth0 stbc) = setupCreationRwa1_withMint(27, amount);
        _setOraclePrice(address(token), 1000e27);

        (uint256 deadline, uint8 v, bytes32 r, bytes32 s) = _getAlicePermitData(
            block.timestamp + 1 days, address(token), address(daoCollateral), amount
        );

        vm.prank(alice);
        daoCollateral.swapWithPermit(address(token), amount, 0, deadline, v, r, s);
        // the formula to be used to calculate the correct amount of ETH0 should be rwaAmount * price / rwaDecimals
        uint256 amountInEth = amount * 1000e18 / 1e27;
        assertApproxEqRel(stbc.balanceOf(alice), amountInEth, 0.000001e18);
        // RWA token is now on bucket and not on dao Collateral
        assertEq(token.balanceOf(address(daoCollateral)), 0);
        assertEq(token.balanceOf(treasury), amount);
        assertEq(token.balanceOf(alice), 0);
    }

    // swap 3 times ETH => ETH0  for a total of "amount" ETH
    // 1st swap of 1/4 th of the amount
    // 2nd swap of half of the amount
    // 3rd swap of 1/4 th of the amount
    function testMultipleSwapsTwoTimesFromSecurity(uint256 amount) public {
        amount = bound(amount, 40e6, (type(uint128).max) - 100e6 - 1);
        // make sure it can be divided by four
        amount = amount - (amount % 4);
        uint256 wholeAmount = amount + 100e6;

        (RwaMock token, Eth0 stbc) = setupCreationRwa1_withMint(6, wholeAmount);

        uint256 tokenBalanceBefore = token.balanceOf(alice);
        assertEq(tokenBalanceBefore, wholeAmount);

        vm.startPrank(alice);
        // multiple swap
        // will swap  for 1/4 of the amount
        uint256 amount1fourth = amount / 4;

        daoCollateral.swap(address(token), amount1fourth, 0);
        assertEq(stbc.balanceOf(alice), amount1fourth * 1e12);
        uint256 amountHalf = amount / 2;
        // will swap for 1/2 of the amount
        daoCollateral.swap(address(token), amountHalf, 0);
        assertEq(stbc.balanceOf(alice), (amount1fourth + amountHalf) * 1e12);
        // will swap for 1/4of the amount
        daoCollateral.swap(address(token), amount1fourth, 0);
        assertEq(stbc.balanceOf(alice), (amount1fourth + amountHalf + amount1fourth) * 1e12);
        vm.stopPrank();
    }

    /// @dev This test checks that the swap function works correctly with several RWA
    function testSwapWithSeveralRWA(uint256 rawAmount) public {
        rawAmount = bound(rawAmount, 1e6, type(uint128).max - 1);
        (RwaMock rwa1, Eth0 stbc) = setupCreationRwa1_withMint(6, rawAmount);

        (RwaMock rwa2,) = setupCreationRwa2(18);

        // we need to whitelist alice for rwa
        _whitelistRWA(address(rwa2), bob);
        IRwaMock(rwa2).mint(bob, rawAmount);

        // add mock oracle for rwa token
        vm.prank(admin);
        _setOraclePrice(address(rwa2), 1e18);

        uint256 amount = ERC20(address(rwa1)).balanceOf(alice);
        // push MMF price to 1.01$
        _setOraclePrice(address(rwa1), 1.01e6);
        assertEq(classicalOracle.getPrice(address(rwa1)), 1.01e18);
        // considering amount of $ find corresponding amount of MMF
        uint256 amountInRWA = (amount * 1e18) / classicalOracle.getPrice(address(rwa1));
        uint256 oracleQuote = classicalOracle.getQuote(address(rwa1), amountInRWA);
        uint256 approxAmount = (amountInRWA * 1.01e6) / 1e6;
        assertApproxEqRel(approxAmount, amount, 0.0001 ether);
        assertEq(oracleQuote, approxAmount);
        // bob and bucket distribution need to be whitelisted
        _whitelistRWA(address(rwa1), bob);

        rwa1.mint(bob, amountInRWA);
        assertEq(ERC20(address(rwa1)).balanceOf(bob), amountInRWA);
        vm.startPrank(bob);
        ERC20(address(rwa1)).approve(address(daoCollateral), amountInRWA);
        vm.label(address(rwa1), "rwa1");
        vm.label(address(rwa2), "rwa2");
        vm.label(address(classicalOracle), "ClassicalOracle");
        // we swap amountInRWA of MMF for amount STBC
        daoCollateral.swap(address(rwa1), amountInRWA, 0);
        vm.stopPrank();
        assertApproxEqRel(ERC20(address(stbc)).balanceOf(bob), amount * 1e12, 0.000001 ether);

        // bob redeems his stbc for MMF
        vm.startPrank(bob);
        assertEq(ERC20(address(rwa1)).balanceOf(bob), 0);

        uint256 stbcBalance = ERC20(address(stbc)).balanceOf(bob);

        stbc.approve(address(daoCollateral), stbcBalance);

        daoCollateral.redeem(address(rwa1), stbcBalance, 0);

        // fee is 0.1% and goes to treasury
        assertApproxEqRel(
            ERC20(address(stbc)).balanceOf(treasuryYield),
            _getDotOnePercent(amount * 1e12),
            0.0012 ether
        );
        uint256 amountRedeemedMinusFee = stbcBalance - ERC20(address(stbc)).balanceOf(treasuryYield);
        // considering amount of $ find corresponding amount of MMF
        amountInRWA = (amountRedeemedMinusFee * 1e6) / classicalOracle.getPrice(address(rwa1));
        assertApproxEqRel(ERC20(address(rwa1)).balanceOf(bob), amountInRWA, 0.000002 ether);
        // bob doesn't own STBC anymore
        assertEq(ERC20(address(stbc)).balanceOf(bob), 0);

        vm.stopPrank();
        // swap rwa2 for stbc
        amount = ERC20(address(rwa2)).balanceOf(bob);
        assertGt(amount, 0);
        // push MMF price to 1.21e18$
        uint256 oraclePrice = 1.21e18;
        _setOraclePrice(address(rwa2), oraclePrice);
        assertEq(classicalOracle.getPrice(address(rwa2)), oraclePrice);
        // considering amount of $ find corresponding amount of MMF
        uint256 amountInRWA2 = (amount * 1 ether) / classicalOracle.getPrice(address(rwa2));
        oracleQuote = classicalOracle.getQuote(address(rwa2), amountInRWA2);
        approxAmount = (amountInRWA2 * oraclePrice) / 1e18;
        assertApproxEqRel(approxAmount, amount, 0.0001 ether);
        assertEq(oracleQuote, approxAmount);
        // bucket distribution need to be whitelisted
        _whitelistRWA(address(rwa2), treasury);
        _whitelistRWA(address(rwa2), alice);
        vm.startPrank(bob);
        // transfer to alice so that only amountInRWA2 remains for bob
        ERC20(rwa2).transfer(alice, amount - amountInRWA2);
        assertEq(ERC20(address(rwa2)).balanceOf(bob), amountInRWA2);

        ERC20(address(rwa2)).approve(address(daoCollateral), amountInRWA2);
        // we swap amountInRWA of MMF for amount STBC
        daoCollateral.swap(address(rwa2), amountInRWA2, 0);
        vm.stopPrank();
        assertApproxEqRel(ERC20(address(stbc)).balanceOf(bob), amount, 0.00001 ether);
        // bob redeems his stbc for MMF
        vm.startPrank(bob);
        assertEq(ERC20(address(rwa2)).balanceOf(bob), 0);

        stbcBalance = ERC20(address(stbc)).balanceOf(bob);

        stbc.approve(address(daoCollateral), stbcBalance);
        uint256 bucketEth0BalanceBefore = ERC20(address(stbc)).balanceOf(treasuryYield);
        daoCollateral.redeem(address(rwa2), stbcBalance, 0);
        uint256 bucketAddedEth0 =
            ERC20(address(stbc)).balanceOf(treasuryYield) - bucketEth0BalanceBefore;
        // fee is 0.1% and goes to treasury
        assertApproxEqRel(bucketAddedEth0, _getDotOnePercent(amount), 0.001 ether);
        amountRedeemedMinusFee = stbcBalance - bucketAddedEth0;
        // considering amount of $ find corresponding amount of MMF
        amountInRWA = (amountRedeemedMinusFee * 1e18) / classicalOracle.getPrice(address(rwa2));

        assertApproxEqRel(ERC20(address(rwa2)).balanceOf(bob), amountInRWA, 0.00000001 ether);
        // bob doesn't own STBC anymore
        assertEq(ERC20(address(stbc)).balanceOf(bob), 0);

        vm.stopPrank();
    }

    /// @dev This test checks that the swap function works correctly with CBR on
    function testSwapRWA2CBROn() public returns (uint256) {
        (RwaMock rwa1, Eth0 stbc) = setupCreationRwa1_withMint(6, 100e6);
        (RwaMock rwa2,) = setupCreationRwa2_withMint(18, 100e18);
        deal(address(rwa1), treasury, 0);
        deal(address(rwa2), treasury, 0);

        // we swap amountInRWA of MMF for amount STBC
        vm.startPrank(alice);
        ERC20(rwa2).approve(address(daoCollateral), type(uint256).max);
        ERC20(rwa1).approve(address(daoCollateral), type(uint256).max);
        daoCollateral.swap(address(rwa1), 100e6, 100e18);
        daoCollateral.swap(address(rwa2), 100e18, 100e18);
        vm.stopPrank();
        assertEq(ERC20(address(stbc)).balanceOf(alice), 200e18);
        assertEq(ERC20(address(rwa1)).balanceOf(treasury), 100e6);
        assertEq(ERC20(address(rwa2)).balanceOf(treasury), 100e18);
        assertEq(stbc.balanceOf(usdInsurance), 0);
        assertEq(ERC20(address(stbc)).balanceOf(treasuryYield), 0);

        // push RWA price to 0.5$
        vm.prank(admin);
        _setOraclePrice(address(rwa1), 0.5e6);
        assertEq(classicalOracle.getPrice(address(rwa1)), 0.5e18);

        // activate cbr
        assertEq(daoCollateral.cbrCoef(), 0);

        uint256 snapshot = vm.snapshot(); // saves the state
        vm.prank(admin);
        daoCollateral.activateCBR(0.75 ether); //0.75 ether

        assertEq(daoCollateral.cbrCoef(), 0.75 ether);

        vm.revertTo(snapshot); // restores the state
        assertEq(daoCollateral.cbrCoef(), 0);
        deal(address(rwa1), treasury, 62 ether);
        vm.prank(address(daoCollateral));
        stbc.mint(usdInsurance, 62 ether);
        assertEq(ERC20(address(stbc)).balanceOf(usdInsurance), 62 ether);
        assertEq(ERC20(address(stbc)).totalSupply(), 262 ether);
        uint256 firstCalcCoef =
            Math.mulDiv(212e18, SCALAR_ONE, ERC20(address(stbc)).totalSupply(), Math.Rounding.Floor);
        vm.prank(admin);
        daoCollateral.activateCBR(firstCalcCoef);
        // we have minted 200ETH0 but only 0.5 *100 + 1 * 100 in collateral but as we also have 62e18 on
        // the insurance bucket can't mint because the ETH0 totalSupply is 262 (62 + 150 -262)

        // push MMF price to 0.99$
        uint256 newPrice = 0.99e6;
        _setOraclePrice(address(rwa1), newPrice);
        assertEq(classicalOracle.getPrice(address(rwa1)), newPrice * 1e12);
        // we update the coef
        uint256 calcCoef = Math.mulDiv(
            100e18 + 100 * newPrice * 1e12 + 62e18,
            SCALAR_ONE,
            ERC20(address(stbc)).totalSupply(),
            Math.Rounding.Floor
        );
        vm.prank(admin);
        daoCollateral.activateCBR(calcCoef);
        assertEq(daoCollateral.cbrCoef(), calcCoef);
        assertGt(calcCoef, firstCalcCoef);

        // push MMF price back to 0.5$
        _setOraclePrice(address(rwa1), 0.5e6);
        assertEq(classicalOracle.getPrice(address(rwa1)), 0.5e18);
        // we update the coef
        vm.prank(admin);
        daoCollateral.activateCBR(firstCalcCoef);
        assertEq(daoCollateral.cbrCoef(), firstCalcCoef);

        // if we redeem rwa2 we redeem less than when cbr is off
        vm.startPrank(alice);
        // alice redeems his stbc for MMF

        assertEq(ERC20(address(rwa2)).balanceOf(alice), 0);

        uint256 stbcBalance = ERC20(address(stbc)).balanceOf(alice);

        stbc.approve(address(daoCollateral), stbcBalance);

        // we can't redeem all in rwa2
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                treasury,
                1e20,
                161_670_229_007_633_587_710
            )
        );

        daoCollateral.redeem(address(rwa2), stbcBalance, 0);
        // we only have the insurance bucket funds

        assertEq(ERC20(address(stbc)).balanceOf(usdInsurance), 62e18);

        uint256 amount = 25e18;
        daoCollateral.redeem(address(rwa2), amount, 0);
        uint256 stbcBalanceMinusFee = _getDotOnePercent(amount);
        uint256 amountRedeemedMinusFee = amount - stbcBalanceMinusFee;
        // considering amount of $ find corresponding amount of MMF
        uint256 amountInRWA =
            (amountRedeemedMinusFee * firstCalcCoef) / classicalOracle.getPrice(address(rwa2));
        assertApproxEqRel(ERC20(address(rwa2)).balanceOf(alice), amountInRWA, 0.00000001 ether);
        // alice doesn't own STBC anymore
        assertEq(ERC20(address(stbc)).balanceOf(alice), stbcBalance - amount);

        vm.stopPrank();
        return firstCalcCoef;
    }

    /// @dev This test checks that the swap function works correctly with fuzzing
    function testFuzz_Swap(uint256 amount, uint256 minAmountOut) public {
        // Bound amount to reasonable values
        amount = bound(amount, 1e6, type(uint128).max - 1);
        minAmountOut = bound(minAmountOut, 0, amount * 2);

        (RwaMock token,) = setupCreationRwa1_withMint(6, amount);

        vm.startPrank(alice);
        if (minAmountOut > amount * 1e12) {
            vm.expectRevert(abi.encodeWithSelector(AmountTooLow.selector));
            daoCollateral.swap(address(token), amount, minAmountOut);
        } else {
            daoCollateral.swap(address(token), amount, minAmountOut);
            assertGe(stbcToken.balanceOf(alice), minAmountOut);
        }
        vm.stopPrank();
    }

    /// @dev This test checks that the swapWithPermit function works correctly with fuzzing
    function testFuzz_SwapWithPermit(uint256 amount, uint256 minAmountOut, uint256 deadline)
        public
    {
        // Bound values to reasonable ranges
        amount = bound(amount, 1e6, type(uint128).max - 1);
        minAmountOut = bound(minAmountOut, 0, amount * 2);
        deadline = bound(deadline, block.timestamp, type(uint256).max);

        (RwaMock token,) = setupCreationRwa1_withMint(6, amount);

        (uint8 v, bytes32 r, bytes32 s) = _getSelfPermitData(
            address(token), alice, alicePrivKey, address(daoCollateral), amount, deadline
        );

        vm.startPrank(alice);
        if (minAmountOut > amount * 1e12) {
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
        (RwaMock token,) = testRWASwap(amount);

        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, alice, amount * 1e12, amount * 2e12
            )
        );

        daoCollateral.redeem(address(token), amount * 2e12, 0);
        daoCollateral.redeem(address(token), amount * 1e12, 0);

        vm.stopPrank();
    }

    /// @dev This test checks that the redeem function fails with insufficient balance
    function testMultipleRedeemForStableCoinFail(uint256 amount) public {
        amount = bound(amount, 1e6, type(uint128).max - 1);
        (RwaMock token, Eth0 stbc) = testRWASwap(amount);

        vm.startPrank(alice);
        daoCollateral.redeem(address(token), stbc.balanceOf(alice) - amount * 0.5e12, 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                alice,
                amount * 0.5e12,
                amount * 1e12
            )
        );
        daoCollateral.redeem(address(token), amount * 1e12, 0);
        daoCollateral.redeem(address(token), amount * 0.5e12, 0);

        vm.stopPrank();
    }

    /// @dev This test checks that the redeem function fails if the minAmountOut is too low
    function testRedeemShouldFailIfMinAmountOut() public {
        (RwaMock token,) = testRWASwap(1e6);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AmountTooLow.selector));
        daoCollateral.redeem(address(token), 1e18, 1e6);
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

    /// @dev This test checks that the redeem function works correctly with 6 decimals and low redeem fee
    function testRedeemFiatFixAudit() public {
        (RwaMock token, Eth0 stbc) = setupCreationRwa1(6);

        deal(address(stbc), alice, 99_999_999_999_999);
        deal(address(token), address(treasury), 99);

        vm.prank(admin);
        // redeem fee 0.01 %
        daoCollateral.setRedeemFee(1);
        vm.prank(alice);

        // we redeem 0.000099999999999999 ETH
        // 0.01% is 10000000000 but 10000000000 / 1e12 (to make it on 6 decimals )= 0
        // the treasury is not allowed to own `stbc` tokens when no collateral exists
        daoCollateral.redeem(address(token), 99_999_999_999_999, 0);
        assertEq(IERC20(token).balanceOf(alice), 99);
        assertEq(IERC20(token).balanceOf(treasury), 0);
        assertEq(IERC20(stbc).balanceOf(treasuryYield), 0);
    }

    /// @dev This test checks that the redeem function works correctly with fuzzing
    function testRedeemFiatFuzzing(uint256 fee, uint256 amount) public {
        fee = bound(fee, 1, MAX_REDEEM_FEE);
        amount = bound(amount, 1, type(uint128).max - 1);
        (RwaMock rwa, Eth0 stbc) = setupCreationRwa1(18);
        rwa.mint(treasury, amount);
        // mint stbc
        vm.prank(address(daoCollateral));
        stbc.mint(alice, amount);

        if (daoCollateral.redeemFee() != fee) {
            vm.prank(admin);
            // redeem fee 1 = 0.01 % max is 2500 = 25%
            daoCollateral.setRedeemFee(fee);
        }
        // calculate the redeem fee
        uint256 calculatedFee = Math.mulDiv(amount, fee, BASIS_POINT_BASE, Math.Rounding.Floor);
        vm.prank(alice);
        daoCollateral.redeem(address(rwa), amount, 0);
        assertEq(IERC20(rwa).balanceOf(alice), amount - calculatedFee);
        // rwa left on treasury equals to the fee taken out
        assertEq(IERC20(rwa).balanceOf(treasury), calculatedFee);
        // stbc left on treasury equals to the fee taken out
        assertEq(IERC20(stbc).balanceOf(treasuryYield), calculatedFee);
    }

    /// @dev This test checks that the redeem function works correctly with 18 decimals
    function testRedeemFiatFixWithWadRwa() public {
        (RwaMock token, Eth0 stbc) = setupCreationRwa1(18);

        assertEq(token.balanceOf(alice), 0);
        token.mint(address(treasury), 99_999_999_999_999);
        vm.prank(address(daoCollateral));
        stbc.mint(alice, 99_999_999_999_999);

        vm.prank(admin);
        // redeem fee 0.01 %
        daoCollateral.setRedeemFee(1);
        vm.prank(alice);
        // we redeem 0.000099999999999999 ETH
        // 0.01% is 10000000000
        daoCollateral.redeem(address(token), 99_999_999_999_999, 0);
        assertEq(token.balanceOf(alice), 99_990_000_000_000);
        assertEq(IERC20(stbc).balanceOf(treasuryYield), 9_999_999_999);
        assertEq(token.balanceOf(treasury), 9_999_999_999);
    }

    /// @dev This test checks that the redeem function works correctly with 27 decimals
    function testRedeemFiatWith27Decimals(uint256 amount) public {
        amount = bound(amount, 1_000_000_000_000, type(uint128).max - 1);
        (RwaMock token, Eth0 stbc) = testRWAWith27DecimalsSwap(amount);

        vm.startPrank(alice);
        uint256 eth0Amount = stbc.balanceOf(alice);
        uint256 amountInRWA = (eth0Amount * 1e27) / 1000e18;
        uint256 fee = _getDotOnePercent(amountInRWA);
        daoCollateral.redeem(address(token), eth0Amount, 0);
        vm.stopPrank();
        // The formula to calculate the amount of RWA that the user
        // should be able to get by redeeming STBC should be amountStableCoin * rwaDecimals / oraclePrice

        assertEq(stbc.balanceOf(alice), 0);
        assertApproxEqRel(token.balanceOf(alice), amountInRWA - fee, 0.00001 ether);
    }

    // solhint-disable-next-line max-states-count
    // swap 6 times "amount" of USYC => ETH0
    // and try to redeem "amount" with only 5   ETH0 => USYC to assert
    function testMultipleSwapAndRedeemForFiat(uint256 amount) public {
        amount = bound(amount, 320e6, (type(uint128).max) - 100e6 - 1);
        amount = amount - (amount % 32);
        uint256 wholeAmount = amount + 100e6;
        (RwaMock token, Eth0 stbc) = setupCreationRwa1_withMint(6, wholeAmount);

        vm.startPrank(alice);
        // multiple swap from USYC => ETH0
        // will swap  for 1/2 of the amount
        uint256 amountToSwap1 = amount / 2;
        daoCollateral.swap(address(token), amountToSwap1, 0);

        // amount swap is rounded due to oracle price
        uint256 amountToSwap2 = amountToSwap1 / 2;
        // will swap for 1/4 of the amount
        daoCollateral.swap(address(token), amountToSwap2, 0);

        uint256 amountToSwap3 = amountToSwap2 / 2;
        // will swap for 1/8 of the amount
        daoCollateral.swap(address(token), amountToSwap3, 0);

        uint256 amountToSwap4 = amountToSwap3 / 2;
        // will swap for 1/16 of the amount
        daoCollateral.swap(address(token), amountToSwap4, 0);

        uint256 amountToSwap5 = amountToSwap4 / 2;
        // will swap for 1/32 of the amount
        daoCollateral.swap(address(token), amountToSwap5, 0);

        uint256 allFirst5 =
            amountToSwap1 + amountToSwap2 + amountToSwap3 + amountToSwap4 + amountToSwap5;
        // will swap for the remaining amount
        uint256 remainingAmount = (wholeAmount - allFirst5);
        daoCollateral.swap(address(token), remainingAmount, 0);
        vm.stopPrank();
        // Alice now has "wholeAmount" ETH0 and 0 USYC
        assertEq(stbc.balanceOf(alice), wholeAmount * 1e12);
        assertEq(token.balanceOf(alice), wholeAmount - remainingAmount - allFirst5);

        // in total 6 swaps was done for Alice
        vm.startPrank(alice);
        stbc.approve(address(daoCollateral), allFirst5 * 1e12);
        assertEq(token.balanceOf(treasury), remainingAmount + allFirst5);

        // ETH0 => USYC
        // trying to redeem amountToSwap1 + amountToSwap2 + amountToSwap3 + amountToSwap4 + amountToSwap5

        daoCollateral.redeem(address(token), amountToSwap1 * 1e12, 0);
        daoCollateral.redeem(address(token), amountToSwap2 * 1e12, 0);
        daoCollateral.redeem(address(token), amountToSwap3 * 1e12, 0);
        daoCollateral.redeem(address(token), amountToSwap4 * 1e12, 0);
        daoCollateral.redeem(address(token), amountToSwap5 * 1e12, 0);

        vm.stopPrank();

        // Alice was only able to swap "allFirst5" amount of ETH0 to USYC
        // she now has "remainingAmount" of ETH0 and "returnedCollateral" USYC

        uint256 returnedCollateral = _getAmountMinusFeeInUSD(amountToSwap1, address(token));
        returnedCollateral += _getAmountMinusFeeInUSD(amountToSwap2, address(token));
        returnedCollateral += _getAmountMinusFeeInUSD(amountToSwap3, address(token));
        returnedCollateral += _getAmountMinusFeeInUSD(amountToSwap4, address(token));
        returnedCollateral += _getAmountMinusFeeInUSD(amountToSwap5, address(token));
        assertApproxEqRel(
            token.balanceOf(alice),
            wholeAmount - remainingAmount - allFirst5 + returnedCollateral,
            1e16
        );
        assertEq(stbc.balanceOf(alice), remainingAmount * 1e12);
        // the 0.1% fee in stable is sent to the treasury
        assertApproxEqRel(
            stbc.balanceOf(treasuryYield), (allFirst5 - returnedCollateral) * 1e12, 1e16
        );
    }

    /// @dev This test checks that the swap function works correctly by fuzzing the oracle price
    function testSwapWithRwaPriceFuzzFlow(uint256 oraclePrice) public {
        // uint256 oraclePrice = 10.2 ether;
        oraclePrice = bound(oraclePrice, 1e3, 1e12);
        uint256 rawAmount = 10_000e6;
        (RwaMock rwaToken, Eth0 stbc) = setupCreationRwa1_withMint(6, rawAmount);
        _setOraclePrice(address(rwaToken), oraclePrice);

        assertEq(classicalOracle.getPrice(address(rwaToken)), oraclePrice * 1e12);
        // considering amount of $ fin corresponding amount of MMF
        uint256 amountInRWA = (rawAmount * 1e18) / classicalOracle.getPrice(address(rwaToken));
        uint256 oracleQuote = classicalOracle.getQuote(address(rwaToken), amountInRWA);
        assertApproxEqRel(oracleQuote, rawAmount, ONE_PERCENT);

        _whitelistRWA(address(rwaToken), bob);
        rwaToken.mint(bob, amountInRWA);
        assertEq(ERC20(address(rwaToken)).balanceOf(bob), amountInRWA);

        vm.startPrank(bob);
        rwaToken.approve(address(daoCollateral), amountInRWA);
        // we swap amountInRWA of MMF for  amount STBC
        daoCollateral.swap(address(rwaToken), amountInRWA, 0);

        assertApproxEqRel(ERC20(address(stbc)).balanceOf(bob), rawAmount * 1e12, 0.0001 ether);
        assertEq(ERC20(address(rwaToken)).balanceOf(bob), 0);

        uint256 stbcBalance = ERC20(address(stbc)).balanceOf(bob);

        stbc.approve(address(daoCollateral), stbcBalance);

        daoCollateral.redeem(address(rwaToken), stbcBalance, 0);

        // fee is 0.1% and goes to treasury
        assertApproxEqRel(
            ERC20(address(stbc)).balanceOf(treasuryYield),
            _getDotOnePercent(rawAmount * 1e12),
            0.0001 ether
        );
        uint256 amountRedeemedMinusFee = stbcBalance - ERC20(address(stbc)).balanceOf(treasuryYield);
        // considering amount of $ find corresponding amount of MMF
        amountInRWA = (amountRedeemedMinusFee * 1e6) / classicalOracle.getPrice(address(rwaToken));
        assertApproxEqRel(ERC20(address(rwaToken)).balanceOf(bob), amountInRWA, 0.0002 ether);
        // bob doesn't own STBC anymore
        assertEq(ERC20(address(stbc)).balanceOf(bob), 0);

        vm.stopPrank();
    }

    /// @dev This test checks that the redeem function works correctly by fuzzing the amount and the redeem fee
    function testFuzz_Redeem(uint256 amount, uint256 redeemFee) public {
        // Bound values
        amount = bound(amount, 100e6, type(uint128).max - 1);
        redeemFee = bound(redeemFee, 1, MAX_REDEEM_FEE);

        (RwaMock token, Eth0 stbc) = testRWASwap(amount);

        assertEq(token.balanceOf(alice), 0);
        assertEq(stbc.balanceOf(alice), amount * 1e12);

        uint256 balanceBefore = stbc.balanceOf(treasuryYield);

        if (redeemFee != daoCollateral.redeemFee()) {
            vm.prank(admin);
            daoCollateral.setRedeemFee(redeemFee);
        }

        vm.startPrank(alice);
        uint256 stbcBalance = stbc.balanceOf(alice);

        uint256 feeAmount = (amount * redeemFee / BASIS_POINT_BASE);

        daoCollateral.redeem(address(token), stbcBalance, amount - feeAmount);

        uint256 balanceAfter = stbc.balanceOf(treasuryYield);

        if (redeemFee != 0) {
            assertEq(token.balanceOf(alice), amount - feeAmount);
        } else {
            assertEq(token.balanceOf(alice), amount);
        }

        assertEq(balanceAfter - balanceBefore, feeAmount * 1e12);

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

    /// @dev This test checks that the redeemDao function fails if the amount is zero
    function testRedeemDaoShouldFailIfAmountZero() public {
        vm.startPrank(daoredeemer);
        vm.expectRevert(abi.encodeWithSelector(AmountIsZero.selector));
        daoCollateral.redeemDao(address(0x21), 0);
        vm.stopPrank();
    }

    /// @dev This test checks that the redeemDao function fails if the amount is too low
    function testRedeemDaoShouldFailIfAmountTooLow(uint256 amount, uint256 amountToRedeem) public {
        amount = bound(amount, 1e6, type(uint128).max - 1);
        amountToRedeem = bound(amount, 1, 1e12 - 1);
        (RwaMock token, Eth0 stbc) = testRWASwap(amount);

        vm.prank(alice);
        stbc.transfer(daoredeemer, amount * 1e12);

        vm.startPrank(daoredeemer);
        vm.expectRevert(abi.encodeWithSelector(AmountTooLow.selector));
        daoCollateral.redeemDao(address(token), amountToRedeem);
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
    function testRedeemDao(uint256 amount) public {
        amount = bound(amount, 1e6, type(uint128).max - 1);
        (RwaMock token, Eth0 stbc) = testRWASwap(amount);
        _whitelistRWA(address(token), daoredeemer);

        vm.prank(alice);
        stbc.transfer(daoredeemer, amount * 1e12);
        vm.prank(daoredeemer);
        daoCollateral.redeemDao(address(token), amount * 1e12);

        assertEq(stbc.balanceOf(daoredeemer), 0);
        assertEq(token.balanceOf(daoredeemer), amount);
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
        vm.prank(unpauser);
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

        (RwaMock token,) = setupCreationRwa1_withMint(6, amount);

        vm.prank(pauser);
        daoCollateral.pause();
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        vm.prank(alice);
        daoCollateral.swap(address(token), amount, 0);
    }

    /// @dev This test checks that the swapWithPermit function fails if the swap is paused
    function testSwapWithPermitShouldFailIfPaused() public {
        uint256 amount = 10_000_000_000;
        (RwaMock token,) = setupCreationRwa1_withMint(6, amount);

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
    function testRedeemShouldFailIfPaused() public {
        (RwaMock token,) = testRWASwap(100e6);

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
            daoCollateral.setRedeemFee(fee);
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
    function testActivateCBRShouldFailIfCBRIsTooHigh(uint256 amount) public {
        amount = bound(amount, 1e6, type(uint128).max - 1);
        (RwaMock rwa1, Eth0 stbc) = setupCreationRwa1_withMint(6, amount);
        (RwaMock rwa2,) = setupCreationRwa2_withMint(6, amount);

        vm.startPrank(alice);
        daoCollateral.swap(address(rwa1), amount, amount * 1e12);
        daoCollateral.swap(address(rwa2), amount, amount * 1e12);
        vm.stopPrank();

        // push MMF price to 0.5$
        _setOraclePrice(address(rwa1), 0.5e6);
        assertEq(classicalOracle.getPrice(address(rwa1)), 0.5e18);
        // increase rwa2 amount in treasury to make cbrCoef greater than
        IRwaMock(rwa2).mint(treasury, amount * 2);
        // activate cbr
        assertEq(daoCollateral.cbrCoef(), 0);
        // increase usdBalanceInInsurance
        vm.prank(address(daoCollateral));
        stbc.mint(usdInsurance, amount * 1e12);
        vm.expectRevert(abi.encodeWithSelector(CBRIsTooHigh.selector));
        vm.prank(admin);
        daoCollateral.activateCBR(5e18);
        assertFalse(daoCollateral.isCBROn());
        assertEq(daoCollateral.cbrCoef(), 0);
    }

    /// @dev This test checks that the activateCBR function fails if the CBR is zero
    function testActivateCBRShouldFailIfCBRisNull(uint256 amount) public {
        amount = bound(amount, 1e6, type(uint128).max - 1);
        (RwaMock rwa1, Eth0 stbc) = setupCreationRwa1_withMint(6, amount);
        (RwaMock rwa2,) = setupCreationRwa2_withMint(6, amount);

        vm.startPrank(alice);
        // we swap amountInRWA of MMF for amount STBC
        daoCollateral.swap(address(rwa1), amount, amount * 1e12);
        daoCollateral.swap(address(rwa2), amount, amount * 1e12);
        vm.stopPrank();

        assertEq(stbc.balanceOf(usdInsurance), 0);
        assertEq(ERC20(address(stbc)).balanceOf(treasuryYield), 0);

        // push MMF price to 0.5$
        _setOraclePrice(address(rwa1), 0.5e6);

        // burn all rwa1 and rwa2 in treasury to make cbrCoef equal to 0
        IRwaMock(rwa2).burnFrom(treasury, IRwaMock(rwa2).balanceOf(treasury));
        IRwaMock(rwa1).burnFrom(treasury, IRwaMock(rwa1).balanceOf(treasury));

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
        (RwaMock rwa1,) = setupCreationRwa1_withMint(6, 100e6);
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

    /// @dev This test checks that the redeem function with CBR on should burn fee
    function testRedeemWithCBROnShouldBurnFee() public {
        uint256 amount = 100e18;
        (RwaMock rwa1, Eth0 stbc) = setupCreationRwa1_withMint(18, amount);
        deal(address(rwa1), treasury, 0);
        vm.prank(alice);
        daoCollateral.swap(address(rwa1), amount, 0);

        // Update oracle price
        _setOraclePrice(address(rwa1), 1e18 - 1);
        assertEq(classicalOracle.getPrice(address(rwa1)), 1e18 - 1);

        // Verify expected totalRWAValueInUSD
        uint8 decimals = ERC20(address(rwa1)).decimals();
        assertEq(decimals, 18);
        uint256 tokenAmount = ERC20(address(rwa1)).balanceOf(treasury);
        uint256 wadAmount = Normalize.tokenAmountToWad(tokenAmount, decimals);
        uint256 wadPriceInUSD = uint256(classicalOracle.getPrice(address(rwa1)));
        uint256 totalRWAValueInUSD =
            Math.mulDiv(wadAmount, wadPriceInUSD, SCALAR_ONE, Math.Rounding.Ceil);
        assertEq(totalRWAValueInUSD, amount - 100); // precision loss

        // Activate and check cbr coefficient
        uint256 firstCalcCoefFloor = Math.mulDiv(
            totalRWAValueInUSD, // Total RWA value in USD
            SCALAR_ONE, // SCALAR_ONE assumed to be 1e18 for scaling
            ERC20(address(stbc)).totalSupply(),
            Math.Rounding.Floor // Adjusted to Floor to prevent overestimation
        );

        vm.prank(admin);
        daoCollateral.activateCBR(firstCalcCoefFloor);

        vm.prank(admin);
        daoCollateral.setRedeemFee(MAX_REDEEM_FEE);
        assertEq(daoCollateral.redeemFee(), MAX_REDEEM_FEE);

        assertEq(stbc.balanceOf(treasuryYield), 0);
        uint256 stableSupply = stbc.totalSupply();
        // calculate the redeem fee
        uint256 calculatedFee =
            Math.mulDiv(amount, MAX_REDEEM_FEE, BASIS_POINT_BASE, Math.Rounding.Floor);
        vm.prank(alice);

        daoCollateral.redeem(address(rwa1), amount, 0);
        assertEq(ERC20(address(rwa1)).balanceOf(alice), amount - calculatedFee - 1);
        assertEq(ERC20(address(rwa1)).balanceOf(treasury), calculatedFee + 1);
        // stable total supply is decreased by the total amount of stable
        assertEq(stbc.totalSupply(), stableSupply - amount);
        // treasury balance stays the same
        assertEq(stbc.balanceOf(treasuryYield), 0);
    }

    // Test for DOMAIN_SEPARATOR function
    function testDomainSeparator() public view {
        bytes32 eip712DomainTypeHash = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        bytes32 nameHash = keccak256(bytes("daoCollateral"));
        bytes32 versionHash = keccak256(bytes("1"));
        uint256 chainId = block.chainid;
        address verifyingContract = address(daoCollateral);

        bytes32 expectedDomainSeparator = keccak256(
            abi.encode(eip712DomainTypeHash, nameHash, versionHash, chainId, verifyingContract)
        );

        assertEq(
            daoCollateral.DOMAIN_SEPARATOR(), expectedDomainSeparator, "Domain separator mismatch"
        );
    }
}
