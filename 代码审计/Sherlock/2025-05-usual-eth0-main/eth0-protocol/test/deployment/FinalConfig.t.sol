// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {CONTRACT_ORACLE} from "src/constants.sol";
import {WSTETH} from "src/constants.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {BaseDeploymentTest} from "test/deployment/baseDeployment.t.sol";

/// @author  Usual Tech Team
/// @title   ERC20 LayerZero Deployment Script
/// @dev     Do not use in production this is for research purposes only
/// @dev     See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
/// @notice  ERC20 using LayerZero deployment script
contract DeploymentTest is BaseDeploymentTest {
    uint256 public _amount = 100 ether;
    address public STETH_WHALE = 0x0B925eD163218f6662a35e0f0371Ac234f9E9371;

    function setUp() public override {
        super.setUp();
        vm.prank(mintcapOperator);
        ETH0.setMintCap(type(uint256).max);
        vm.prank(treasury);
        ERC20(collateralToken).approve(address(daoCollateral), type(uint256).max);
    }

    function testOracle() public view {
        require(
            deploy.registryContract().getContract(CONTRACT_ORACLE) != address(0),
            "Deployment failed"
        );
        uint256 quote = classicalOracle.getQuote(address(WSTETH), 1e18);
        assertApproxEqAbs(quote, 1.2 ether, 1e17);
    }

    function testSwap__eth0() public {
        _mintSTETH();
        require(address(daoCollateral) != address(0), "Deployment failed");

        assertEq(address(deploy.eth0()), address(ETH0));

        assertEq(ETH0.balanceOf(alice), 0);
        vm.startPrank(alice);
        IERC20(address(collateralToken)).approve(address(daoCollateral), type(uint256).max);
        // we swap amount collateral token for amount ETH0
        daoCollateral.swap(address(collateralToken), _amount, 0);
        vm.stopPrank();
        assertGt(ETH0.balanceOf(alice), 0);
    }

    function testRedeem__eth0() public {
        testSwap__eth0();
        assertEq(IERC20(address(collateralToken)).balanceOf(alice), 0);
        uint256 balance = ETH0.balanceOf(alice);
        assertGt(balance, 0);

        vm.startPrank(alice);
        daoCollateral.redeem(address(collateralToken), balance, 0);
        vm.stopPrank();
        assertGt(IERC20(address(collateralToken)).balanceOf(alice), 0);
        assertEq(ETH0.balanceOf(alice), 0);
    }

    function _mintSTETH() internal {
        vm.startPrank(STETH_WHALE);
        IERC20(WSTETH).transfer(alice, _amount);
        IERC20(WSTETH).transfer(treasury, _amount);
        IERC20(WSTETH).transfer(bob, _amount);
        vm.stopPrank();
    }
}
