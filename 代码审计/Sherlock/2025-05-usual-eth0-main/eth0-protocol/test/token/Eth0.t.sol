//// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import {SetupTest} from "test/setup.t.sol";
import {ETH0_MINT, CONTRACT_DAO_COLLATERAL, WSTETH, MINT_CAP_OPERATOR} from "src/constants.sol";
import {RwaMock} from "src/mock/rwaMock.sol";
import {IRwaMock} from "src/interfaces/token/IRwaMock.sol";
import {IAggregator} from "src/interfaces/oracles/IAggregator.sol";
import {ETH0Name, ETH0Symbol} from "src/mock/constants.sol";
import {
    NotAuthorized,
    Blacklisted,
    SameValue,
    AmountExceedBacking,
    AmountExceedCap,
    MintCapTooSmall
} from "src/errors.sol";
import {Eth0} from "src/token/Eth0.sol";
import {LidoProxyWstETHPriceFeed} from "src/oracles/LidoWstEthOracle.sol";

import {IERC20Errors} from "openzeppelin-contracts/interfaces/draft-IERC6093.sol";
import {IERC20Permit} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Permit.sol";
import {Pausable} from "openzeppelin-contracts/utils/Pausable.sol";
// @title: ETH0 test contract
// @notice: Contract to test ETH0 token implementation

contract Eth0Test is SetupTest {
    Eth0 public eth0Token;
    LidoProxyWstETHPriceFeed lidoWstEthOracle;

    event Blacklist(address account);
    event UnBlacklist(address account);
    event MintCapUpdated(uint256 newMintCap);

    function setUp() public virtual override {
        uint256 forkId = vm.createFork("eth");
        vm.selectFork(forkId);
        super.setUp();
        eth0Token = stbcToken;

        lidoWstEthOracle = new LidoProxyWstETHPriceFeed(WSTETH);
        vm.startPrank(admin);
        classicalOracle.initializeTokenOracle(WSTETH, address(lidoWstEthOracle), 7 days, false);

        tokenMapping.addEth0CollateralToken(WSTETH);
        vm.stopPrank();

        deal(WSTETH, treasury, type(uint128).max);
    }

    function setupCreationRwa2(uint8 decimals) public returns (RwaMock) {
        rwaFactory.createRwa("Hashnote US Yield Coin 2", "STETH2", decimals);
        address rwa2 = rwaFactory.getRwaFromSymbol("STETH2");
        vm.label(rwa2, "STETH2 Mock");

        _whitelistRWA(rwa2, alice);
        _whitelistRWA(rwa2, address(daoCollateral));
        _whitelistRWA(rwa2, treasury);
        _linkSTBCToRwa(IRwaMock(rwa2));
        // add mock oracle for rwa token
        whitelistPublisher(address(rwa2), address(eth0Token));
        _setupBucket(rwa2, address(eth0Token));
        _setOraclePrice(rwa2, 10 ** decimals);

        return RwaMock(rwa2);
    }

    function testName() external view {
        assertEq(ETH0Name, eth0Token.name());
    }

    function testSymbol() external view {
        assertEq(ETH0Symbol, eth0Token.symbol());
    }

    function allowlistAliceAndMintTokens() public {
        vm.prank(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)));
        eth0Token.mint(alice, 2e18);
        assertEq(eth0Token.totalSupply(), eth0Token.balanceOf(alice));
    }

    function testInitializeShouldFailWithNullAddress() public {
        _resetInitializerImplementation(address(eth0Token));
        vm.expectRevert(abi.encodeWithSelector(NullContract.selector));
        eth0Token.initialize(address(0), ETH0Name, ETH0Symbol);
    }

    function testConstructor() public {
        Eth0 eth0 = new Eth0();
        assertTrue(address(eth0) != address(0));
    }

    function testAnyoneCanCreateEth0() public {
        Eth0 stbcToken = new Eth0();
        _resetInitializerImplementation(address(stbcToken));
        Eth0(address(stbcToken)).initialize(address(registryContract), ETH0Name, ETH0Symbol);

        assertTrue(address(stbcToken) != address(0));
    }

    function testMintShouldNotFail() public {
        address minter = address(registryContract.getContract(CONTRACT_DAO_COLLATERAL));
        vm.prank(minter);
        eth0Token.mint(alice, 2e18);
    }

    function testMintShouldFailDueToNoBacking() public {
        deal(WSTETH, treasury, 0);
        _adminGiveEth0MintRoleTo(alice);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AmountExceedBacking.selector));
        eth0Token.mint(alice, 2e18);
    }

    // Additional test functions for the Eth0Test contract

    function testUnauthorizedAccessToMintAndBurn() public {
        // Attempt to mint by a non-authorized address
        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        eth0Token.mint(alice, 1e18);

        // Attempt to burn by a non-authorized address
        vm.prank(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)));
        eth0Token.mint(alice, 10e18); // Mint some tokens for Alice
        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        eth0Token.burnFrom(alice, 5e18);
    }

    function testRoleChangesAffectingMintAndTreasuryNotBackedFail() public {
        deal(WSTETH, treasury, 0);
        // Grant and revoke roles dynamically and test access control
        _adminGiveEth0MintRoleTo(carol);
        vm.stopPrank();
        vm.prank(carol);
        vm.expectRevert(abi.encodeWithSelector(AmountExceedBacking.selector));
        eth0Token.mint(alice, 1e18); // Should fail now since there is no STETH in the treasury
    }

    function testMintNullAddress() public {
        vm.prank(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)));
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0))
        );
        eth0Token.mint(address(0), 2e18);
    }

    function testMintAmountZero() public {
        vm.prank(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)));
        vm.expectRevert(AmountIsZero.selector);
        eth0Token.mint(alice, 0);
    }

    function testBurnFromDoesNotFailIfNotAuthorized() public {
        vm.prank(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)));
        eth0Token.mint(alice, 10e18);
        assertEq(eth0Token.balanceOf(alice), 10e18);
        vm.prank(admin);

        vm.prank(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)));
        // vm.expectRevert(abi.encodeWithSelector(NotAllowlisted.selector, alice));
        eth0Token.burnFrom(alice, 8e18);

        assertEq(eth0Token.totalSupply(), 2e18);
        assertEq(eth0Token.balanceOf(alice), 2e18);
    }

    function testBurnFrom() public {
        vm.startPrank(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)));
        eth0Token.mint(alice, 10e18);
        assertEq(eth0Token.balanceOf(alice), 10e18);

        eth0Token.burnFrom(alice, 8e18);

        assertEq(eth0Token.totalSupply(), 2e18);
        assertEq(eth0Token.balanceOf(alice), 2e18);
    }

    function testBurnFromFail() public {
        vm.prank(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)));
        eth0Token.mint(alice, 10e18);
        assertEq(eth0Token.balanceOf(alice), 10e18);

        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        eth0Token.burnFrom(alice, 8e18);

        vm.expectRevert(abi.encodeWithSelector(AmountIsZero.selector));
        eth0Token.burnFrom(alice, 0);

        assertEq(eth0Token.totalSupply(), 10e18);
        assertEq(eth0Token.balanceOf(alice), 10e18);
    }

    function testBurn() public {
        vm.startPrank(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)));
        eth0Token.mint(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)), 10e18);

        eth0Token.burn(8e18);

        assertEq(
            eth0Token.balanceOf(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL))),
            2e18
        );
    }

    function testBurnFail() public {
        vm.prank(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)));
        eth0Token.mint(alice, 10e18);
        assertEq(eth0Token.balanceOf(alice), 10e18);

        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        eth0Token.burn(8e18);

        vm.expectRevert(abi.encodeWithSelector(AmountIsZero.selector));
        eth0Token.burn(0);

        assertEq(eth0Token.totalSupply(), 10e18);
        assertEq(eth0Token.balanceOf(alice), 10e18);
    }

    function testApprove() public {
        assertTrue(eth0Token.approve(alice, 1e18));
        assertEq(eth0Token.allowance(address(this), alice), 1e18);
    }

    function testTransfer() external {
        allowlistAliceAndMintTokens();
        vm.startPrank(alice);
        eth0Token.transfer(bob, 0.5e18);
        assertEq(eth0Token.balanceOf(bob), 0.5e18);
        assertEq(eth0Token.balanceOf(alice), 1.5e18);
        vm.stopPrank();
    }

    function testTransferAllowlistDisabledSender() public {
        allowlistAliceAndMintTokens(); // Mint to Alice who is allowlisted
        vm.prank(alice);
        eth0Token.transfer(bob, 0.5e18); // This should succeed because alice is allowlisted
        assertEq(eth0Token.balanceOf(bob), 0.5e18);
        assertEq(eth0Token.balanceOf(alice), 1.5e18);

        // Bob tries to transfer to Carol but is not allowlisted
        vm.startPrank(bob);
        // vm.expectRevert(abi.encodeWithSelector(NotAllowlisted.selector, carol));
        eth0Token.transfer(carol, 0.3e18);
        vm.stopPrank();
    }

    function testTransferAllowlistDisabledRecipient() public {
        allowlistAliceAndMintTokens(); // Mint to Alice who is allowlisted
        vm.startPrank(alice);
        eth0Token.transfer(bob, 0.5e18); // This should succeed because both are allowlisted
        assertEq(eth0Token.balanceOf(bob), 0.5e18);
        assertEq(eth0Token.balanceOf(alice), 1.5e18);

        // Alice tries to transfer to Carol who is not allowlisted
        // vm.expectRevert(abi.encodeWithSelector(NotAllowlisted.selector, carol));
        eth0Token.transfer(carol, 0.3e18);
        vm.stopPrank();
    }

    function testTransferFrom() external {
        allowlistAliceAndMintTokens();
        vm.prank(alice);
        eth0Token.approve(address(this), 1e18);
        assertTrue(eth0Token.transferFrom(alice, bob, 0.7e18));
        assertEq(eth0Token.allowance(alice, address(this)), 1e18 - 0.7e18);
        assertEq(eth0Token.balanceOf(alice), 2e18 - 0.7e18);
        assertEq(eth0Token.balanceOf(bob), 0.7e18);
    }

    function testTransferFromWithPermit(uint256 amount) public {
        amount = bound(amount, 100_000_000_000, type(uint128).max);

        vm.startPrank(admin);
        registryAccess.grantRole(ETH0_MINT, admin);
        eth0Token.mint(alice, amount);
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) =
            _getSelfPermitData(address(eth0Token), alice, alicePrivKey, bob, amount, deadline);

        IERC20Permit(address(eth0Token)).permit(alice, bob, amount, deadline, v, r, s);

        vm.stopPrank();
        vm.prank(bob);
        eth0Token.transferFrom(alice, bob, amount);

        assertEq(eth0Token.balanceOf(bob), amount);
        assertEq(eth0Token.balanceOf(alice), 0);
    }

    function testTransferFromAllowlistDisabled() public {
        allowlistAliceAndMintTokens(); // Mint to Alice who is allowlisted

        vm.prank(alice);
        eth0Token.approve(bob, 2e18); // Alice approves Bob to manage 2 tokens
        // Bob attempts to transfer from Alice to himself
        vm.prank(bob);
        eth0Token.transferFrom(alice, bob, 1e18); // This should succeed because both are allowlisted
        assertEq(eth0Token.balanceOf(bob), 1e18);
        assertEq(eth0Token.balanceOf(alice), 1e18);

        // Bob tries to transfer from Alice again, which is not allowlisted anymore
        vm.prank(bob);
        // vm.expectRevert(abi.encodeWithSelector(NotAllowlisted.selector, alice));
        eth0Token.transferFrom(alice, bob, 0.5e18);
        vm.stopPrank();
    }

    function testTransferFromWorksAllowlistDisabledRecipient() public {
        allowlistAliceAndMintTokens();

        vm.prank(alice);
        eth0Token.approve(bob, 2e18); // Alice approves Bob to manage 2 tokens
        vm.startPrank(bob);
        eth0Token.approve(bob, 2e18);
        // Bob attempts to transfer from Alice to himself, then to Carol
        eth0Token.transferFrom(alice, bob, 1e18); // This should succeed because both are allowlisted
        assertEq(eth0Token.balanceOf(bob), 1e18);
        assertEq(eth0Token.balanceOf(alice), 1e18);

        //  Bob is allowlisted, but he tries to transfer from himself to Carol, who is not allowlisted
        // vm.expectRevert(abi.encodeWithSelector(NotAllowlisted.selector, carol));
        eth0Token.transferFrom(bob, carol, 0.5e18);
        vm.stopPrank();
    }

    function testPauseUnPause() external {
        allowlistAliceAndMintTokens();

        vm.prank(pauser);
        eth0Token.pause();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        eth0Token.transfer(bob, 1e18);
        vm.prank(unpauser);
        eth0Token.unpause();
        vm.prank(alice);
        eth0Token.transfer(bob, 1e18);
    }

    function testPauseUnPauseShouldFailWhenNotAuthorized() external {
        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        eth0Token.pause();
        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        eth0Token.unpause();
    }

    function testBlacklistUser() external {
        allowlistAliceAndMintTokens();
        vm.startPrank(blacklistOperator);

        eth0Token.blacklist(alice);
        vm.expectRevert(abi.encodeWithSelector(SameValue.selector));
        eth0Token.blacklist(alice);
        vm.stopPrank();

        vm.assertTrue(eth0Token.isBlacklisted(alice));

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Blacklisted.selector));
        eth0Token.transfer(bob, 1e18);

        vm.startPrank(blacklistOperator);
        eth0Token.unBlacklist(alice);
        vm.expectRevert(abi.encodeWithSelector(SameValue.selector));
        eth0Token.unBlacklist(alice);
        vm.stopPrank();

        vm.prank(alice);
        eth0Token.transfer(bob, 1e18);
    }

    function testBlacklistShouldRevertIfAddressIsZero() external {
        vm.expectRevert(abi.encodeWithSelector(NullAddress.selector));
        eth0Token.blacklist(address(0));
    }

    function testBlacklistAndUnBlacklistEmitsEvents() external {
        allowlistAliceAndMintTokens();
        vm.startPrank(blacklistOperator);
        vm.expectEmit();
        emit Blacklist(alice);
        eth0Token.blacklist(alice);

        vm.expectEmit();
        emit UnBlacklist(alice);
        eth0Token.unBlacklist(alice);
    }

    function testOnlyAdminCanUseBlacklist(address user) external {
        vm.assume(user != blacklistOperator);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        eth0Token.blacklist(alice);

        vm.prank(blacklistOperator);
        eth0Token.blacklist(alice);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        eth0Token.unBlacklist(alice);
    }

    function testRoleChangesAffectingMintAndBurn() public {
        // Grant and revoke roles dynamically and test access control
        vm.startPrank(admin);

        registryAccess.grantRole(ETH0_MINT, carol);
        vm.stopPrank();
        vm.prank(carol);
        eth0Token.mint(alice, 1e18); // Should succeed now that Carol can mint

        vm.prank(admin);
        registryAccess.revokeRole(ETH0_MINT, carol);
        vm.prank(carol);
        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        eth0Token.mint(alice, 1e18); // Should fail now that Carol's mint role is revoked
    }

    function testMintingWithBacking() external {
        _adminGiveEth0MintRoleTo(alice);
        vm.prank(alice);
        eth0Token.mint(alice, 100_000e18); // Since we put STETH in treasury, we should be able to mint
    }

    function testMintingWithBackingNotDaoCollateralAndTwoRwasFuzz(uint256 amount, uint256 decimals)
        external
    {
        amount = bound(amount, 1, type(uint128).max);
        decimals = bound(decimals, 1, 27);
        RwaMock rwa2 = setupCreationRwa2(uint8(decimals));
        deal(address(rwa2), treasury, amount * (10 ** decimals));

        _adminGiveEth0MintRoleTo(alice);
        vm.prank(alice);
        eth0Token.mint(alice, 2 * amount);
        assertEq(eth0Token.balanceOf(alice), 2 * amount);
    }

    function testMintingWithBackingNotDaoCollateralAndTwoRwasRevertFuzz(
        uint256 amount,
        uint256 decimals
    ) external {
        amount = bound(amount, 1, type(uint128).max);
        decimals = bound(decimals, 1, 27);
        RwaMock rwa2 = setupCreationRwa2(uint8(decimals));
        deal(WSTETH, treasury, 0);
        deal(address(rwa2), treasury, amount * (10 ** decimals));

        _adminGiveEth0MintRoleTo(alice);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AmountExceedBacking.selector));
        eth0Token.mint(alice, 3 * amount * 1e18);
    }

    function testMintingWithBackingAndTwoRwasRevert() external {
        RwaMock rwa2 = setupCreationRwa2(12);
        deal(WSTETH, treasury, 0);
        deal(address(rwa2), treasury, 100_000e12);

        _adminGiveEth0MintRoleTo(alice);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AmountExceedBacking.selector));
        eth0Token.mint(alice, 210_000e18);
    }

    function testMintingWithBackingDaoCollateral() external {
        _adminGiveEth0MintRoleTo(alice);
        vm.prank(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)));
        eth0Token.mint(alice, 100_000e18); // Since we put STETH in treasury, we should be able to mint
    }

    function testMintingWithBackingDaoCollateralRevert() external {
        deal(WSTETH, treasury, 0);
        _adminGiveEth0MintRoleTo(alice);
        vm.prank(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)));
        vm.expectRevert(abi.encodeWithSelector(AmountExceedBacking.selector));
        eth0Token.mint(alice, 200_000e18);
    }

    function testRWAPriceDropMintFail() external {
        deal(WSTETH, treasury, 100_000e18);
        _adminGiveEth0MintRoleTo(alice);

        vm.prank(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)));
        eth0Token.mint(alice, 100_000e18); // Since we put STETH in treasury, we should be able to mint

        // Mock STETH PriceFeed
        uint80 roundId = 1;
        int256 answer = 0.9e8;
        uint256 startedAt = block.timestamp - 1;
        uint256 updatedAt = block.timestamp - 1;
        uint80 answeredInRound = 1;
        vm.mockCall(
            address(lidoWstEthOracle),
            abi.encodeWithSelector(IAggregator.latestRoundData.selector),
            abi.encode(roundId, answer, startedAt, updatedAt, answeredInRound)
        );

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AmountExceedBacking.selector));
        eth0Token.mint(alice, 1); // Since the price drops, we should not be able to mint
    }

    function testFuzzingRWAPriceChange(uint256 oraclePriceReturn) external {
        (, int256 price,,,) = lidoWstEthOracle.latestRoundData();
        deal(WSTETH, treasury, 100_000e18);
        // Oracle return price on 18 decimals
        oraclePriceReturn = bound(oraclePriceReturn, 0.1e18, 10e18);

        _adminGiveEth0MintRoleTo(alice);

        vm.prank(address(registryContract.getContract(CONTRACT_DAO_COLLATERAL)));
        eth0Token.mint(alice, (100_000e18 * uint256(price)) / 1e18); // Since we put STETH in treasury, we should be able to mint

        // Mock STETH PriceFeed
        uint80 roundId = 1;
        int256 answer = int256(oraclePriceReturn);
        uint256 startedAt = block.timestamp - 1;
        uint256 updatedAt = block.timestamp - 1;
        uint80 answeredInRound = 1;
        vm.mockCall(
            address(lidoWstEthOracle),
            abi.encodeWithSelector(IAggregator.latestRoundData.selector),
            abi.encode(roundId, answer, startedAt, updatedAt, answeredInRound)
        );

        if (oraclePriceReturn <= uint256(price)) {
            vm.prank(alice);
            vm.expectRevert(abi.encodeWithSelector(AmountExceedBacking.selector));
            eth0Token.mint(alice, 1); // Since the price drops, we should not be able to mint
        } else {
            vm.prank(alice);
            eth0Token.mint(alice, 1);
        }
    }

    function testSetMintCap() external {
        _adminGiveMintCapOperatorRoleTo(admin);
        uint256 newCap = 1000e18;
        vm.prank(admin);
        vm.expectEmit(true, true, true, true, address(eth0Token));
        emit MintCapUpdated(newCap);
        eth0Token.setMintCap(newCap);
        assertEq(eth0Token.getMintCap(), newCap);
    }

    function testSetMintCapShouldFailIfAmountIsZero() external {
        _adminGiveMintCapOperatorRoleTo(admin);
        vm.prank(admin);
        vm.expectRevert(AmountIsZero.selector);
        eth0Token.setMintCap(0);
    }

    function testSetMintCapShouldFailIfmintCapBelowTotalSupply() external {
        _adminGiveMintCapOperatorRoleTo(admin);
        uint256 initialCap = 100e18;
        vm.prank(admin);
        eth0Token.setMintCap(initialCap);

        // Mint some tokens to increase total supply
        _adminGiveEth0MintRoleTo(alice);
        vm.prank(alice);
        eth0Token.mint(bob, 100e18);

        // Attempt to set mint cap below total supply
        vm.expectRevert(abi.encodeWithSelector(MintCapTooSmall.selector));
        vm.prank(admin);
        eth0Token.setMintCap(100e18 - 1);
    }

    function testSetMintCapShouldFailIfSameValue() external {
        _adminGiveMintCapOperatorRoleTo(admin);
        uint256 initialCap = 500e18;
        vm.prank(admin);
        eth0Token.setMintCap(initialCap);
        vm.expectRevert(SameValue.selector);
        vm.prank(admin);
        eth0Token.setMintCap(initialCap);
    }

    function testSetMintCapShouldFailIfNotAuthorized() external {
        uint256 newCap = 1000e18;
        vm.prank(alice); // alice is not MINT_CAP_OPERATOR
        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        eth0Token.setMintCap(newCap);
    }

    function testGetMintCap() external {
        _adminGiveMintCapOperatorRoleTo(admin);
        uint256 capToSet = 750e18;
        vm.prank(admin);
        eth0Token.setMintCap(capToSet);
        assertEq(eth0Token.getMintCap(), capToSet);
    }

    function testMintShouldFailIfExceedsCap() external {
        _adminGiveMintCapOperatorRoleTo(admin);
        uint256 mintCap = 100e18;
        vm.prank(admin);
        eth0Token.setMintCap(mintCap);

        _adminGiveEth0MintRoleTo(alice);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AmountExceedCap.selector));
        eth0Token.mint(bob, mintCap + 1);
    }

    function testMintShouldSucceedIfBelowCap() external {
        _adminGiveMintCapOperatorRoleTo(admin);
        uint256 mintCap = 200e18;
        vm.prank(admin);
        eth0Token.setMintCap(mintCap);

        _adminGiveEth0MintRoleTo(alice);
        vm.prank(alice);
        uint256 mintAmount = 150e18;
        eth0Token.mint(bob, mintAmount);
        assertEq(eth0Token.balanceOf(bob), mintAmount);
        assertEq(eth0Token.totalSupply(), mintAmount);
    }

    function testMintShouldSucceedAtCapBoundary() external {
        _adminGiveMintCapOperatorRoleTo(admin);
        uint256 mintCap = 200e18;
        vm.prank(admin);
        eth0Token.setMintCap(mintCap);

        _adminGiveEth0MintRoleTo(alice);
        vm.prank(alice);
        uint256 mintAmount = mintCap;
        eth0Token.mint(bob, mintAmount);
        assertEq(eth0Token.balanceOf(bob), mintAmount);
        assertEq(eth0Token.totalSupply(), mintAmount);
    }

    function _adminGiveEth0MintRoleTo(address user) internal {
        vm.prank(admin);
        registryAccess.grantRole(ETH0_MINT, user);
    }

    function _adminGiveMintCapOperatorRoleTo(address user) internal {
        vm.prank(admin);
        registryAccess.grantRole(MINT_CAP_OPERATOR, user);
    }
}
