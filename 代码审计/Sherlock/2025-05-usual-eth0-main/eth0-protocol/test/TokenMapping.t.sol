// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {SetupTest} from "./setup.t.sol";
import {MyERC20} from "src/mock/myERC20.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IEth0} from "src/interfaces/token/IEth0.sol";
import {SameValue} from "src/errors.sol";
import {CONTRACT_ETH0} from "src/constants.sol";
import {ETH0Name, ETH0Symbol} from "src/mock/constants.sol";
import {TooManyCollateralTokens, NullAddress} from "src/errors.sol";
import {TokenMapping} from "src/TokenMapping.sol";

import {Eth0} from "src/token/Eth0.sol";

contract ZeroDecimalERC20 is ERC20 {
    constructor() ERC20("ZeroDecimalERC20", "ZERO") {}

    function decimals() public view virtual override returns (uint8) {
        return 0;
    }
}

contract TokenMappingTest is SetupTest {
    address myRwa;

    IEth0 stbc;

    event Initialized(uint64);

    function setUp() public virtual override {
        super.setUp();

        myRwa = rwaFactory.createRwa("rwa", "rwa", 6);
        stbc = new Eth0();
        _resetInitializerImplementation(address(stbc));
        Eth0(address(stbc)).initialize(address(registryContract), ETH0Name, ETH0Symbol);
    }

    function testConstructor() external {
        vm.expectEmit();
        emit Initialized(type(uint64).max);

        TokenMapping tokenMapping = new TokenMapping();
        assertTrue(address(tokenMapping) != address(0));
    }

    function testInitialize() public {
        tokenMapping = new TokenMapping();
        _resetInitializerImplementation(address(tokenMapping));
        vm.expectRevert(abi.encodeWithSelector(NullAddress.selector));
        tokenMapping.initialize(address(0), address(registryContract));
        vm.expectRevert(abi.encodeWithSelector(NullAddress.selector));
        tokenMapping.initialize(address(registryAccess), address(0));
    }

    function testSetEth0ToRwa() public {
        vm.prank(admin);
        registryContract.setContract(CONTRACT_ETH0, address(stbc));

        address rwa = rwaFactory.createRwa("rwa", "rwa", 6);
        // allow rwa
        vm.prank(admin);
        tokenMapping.addEth0CollateralToken(rwa);

        uint256 lastId = tokenMapping.getLastEth0CollateralTokenId();
        assertEq(lastId, 1);
        assertTrue(tokenMapping.isEth0Collateral(rwa));
        assertTrue(tokenMapping.getEth0CollateralTokenById(lastId) == rwa);
    }

    function testSetEth0ToSeveralRwas() public {
        vm.prank(admin);
        registryContract.setContract(CONTRACT_ETH0, address(stbc));

        address rwa1 = rwaFactory.createRwa("rwa1", "rwa1", 6);
        address rwa2 = rwaFactory.createRwa("rwa2", "rwa2", 6);
        vm.startPrank(admin);
        tokenMapping.addEth0CollateralToken(rwa1);
        tokenMapping.addEth0CollateralToken(rwa2);
        vm.stopPrank();

        uint256 lastId = tokenMapping.getLastEth0CollateralTokenId();
        assertTrue(tokenMapping.getEth0CollateralTokenById(lastId) == rwa2);
        vm.expectRevert(abi.encodeWithSelector(InvalidToken.selector));
        tokenMapping.getEth0CollateralTokenById(0);
        assertTrue(tokenMapping.getEth0CollateralTokenById(1) == rwa1);
    }

    function testSetMoreThanTenRwaFail() public {
        vm.prank(address(admin));
        registryContract.setContract(CONTRACT_ETH0, address(stbc));
        address rwa1 = rwaFactory.createRwa("rwa1", "rwa1", 6);
        address rwa2 = rwaFactory.createRwa("rwa2", "rwa2", 6);
        address rwa3 = rwaFactory.createRwa("rwa3", "rwa3", 6);
        address rwa4 = rwaFactory.createRwa("rwa4", "rwa4", 6);
        address rwa5 = rwaFactory.createRwa("rwa5", "rwa5", 6);
        address rwa6 = rwaFactory.createRwa("rwa6", "rwa6", 6);
        address rwa7 = rwaFactory.createRwa("rwa7", "rwa7", 6);
        address rwa8 = rwaFactory.createRwa("rwa8", "rwa8", 6);
        address rwa9 = rwaFactory.createRwa("rwa9", "rwa9", 6);
        address rwa10 = rwaFactory.createRwa("rwa10", "rwa10", 6);
        address rwa11 = rwaFactory.createRwa("rwa11", "rwa11", 6);
        vm.startPrank(admin);
        tokenMapping.addEth0CollateralToken(rwa1);
        tokenMapping.addEth0CollateralToken(rwa2);
        tokenMapping.addEth0CollateralToken(rwa3);
        tokenMapping.addEth0CollateralToken(rwa4);
        tokenMapping.addEth0CollateralToken(rwa5);
        tokenMapping.addEth0CollateralToken(rwa6);
        tokenMapping.addEth0CollateralToken(rwa7);
        tokenMapping.addEth0CollateralToken(rwa8);
        tokenMapping.addEth0CollateralToken(rwa9);
        tokenMapping.addEth0CollateralToken(rwa10);
        vm.stopPrank();

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(TooManyCollateralTokens.selector));
        tokenMapping.addEth0CollateralToken(rwa11);
    }

    function testSetRwaToEth0() public {
        address rwa = rwaFactory.createRwa("rwa", "rwa", 6);
        vm.prank(admin);
        tokenMapping.addEth0CollateralToken(rwa);
        assertTrue(tokenMapping.isEth0Collateral(rwa));
    }

    function testSetRwaToEth0FailZero() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(NullAddress.selector));
        tokenMapping.addEth0CollateralToken(address(0));
    }

    function testSetRwaToEth0FailIfSameValue() public {
        address rwa = rwaFactory.createRwa("rwa", "rwa", 6);
        vm.prank(admin);
        tokenMapping.addEth0CollateralToken(rwa);
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(SameValue.selector));
        tokenMapping.addEth0CollateralToken(rwa);
    }

    function testGetAllEth0Rwa() public {
        vm.prank(admin);
        registryContract.setContract(CONTRACT_ETH0, address(stbc));

        address rwa1 = rwaFactory.createRwa("rwa1", "rwa1", 6);
        address rwa2 = rwaFactory.createRwa("rwa2", "rwa2", 6);
        vm.startPrank(admin);
        tokenMapping.addEth0CollateralToken(rwa1);
        tokenMapping.addEth0CollateralToken(rwa2);
        vm.stopPrank();

        address[] memory rwas = tokenMapping.getAllEth0CollateralTokens();
        assertTrue(rwas.length == 2);
        assertTrue(rwas[0] == rwa1);
        assertTrue(rwas[1] == rwa2);
    }

    function testSetRwa() external {
        vm.prank(admin);
        tokenMapping.addEth0CollateralToken(myRwa);
        assertTrue(tokenMapping.isEth0Collateral(myRwa));
    }

    function testSetRwaShouldFailIfNoDecimals() external {
        ZeroDecimalERC20 zeroDecimalERC20 = new ZeroDecimalERC20();
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Invalid.selector));
        tokenMapping.addEth0CollateralToken(address(zeroDecimalERC20));
    }

    function testSetRwaRevertIfNotAuthorized() external {
        vm.prank(address(bob));
        vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
        tokenMapping.addEth0CollateralToken(myRwa);
    }

    function testSetRwaRevertIfSameValue() external {
        vm.prank(admin);
        tokenMapping.addEth0CollateralToken(myRwa);
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(SameValue.selector));
        tokenMapping.addEth0CollateralToken(myRwa);
    }

    function testInitializeRevertIfNullAddressForRegistryAccess() external {
        _resetInitializerImplementation(address(tokenMapping));
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(NullAddress.selector));
        tokenMapping.initialize(address(0), address(registryContract));
    }

    function testInitializeRevertIfNullAddressForRegistryContract() external {
        _resetInitializerImplementation(address(tokenMapping));
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(NullAddress.selector));
        tokenMapping.initialize(address(registryAccess), address(0));
    }
}
