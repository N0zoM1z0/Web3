// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {BurveFacetBase} from "../../src/multi/facets/Base.sol";
import {TokenRegistry, TokenRegLib} from "../../src/multi/Token.sol";
import {Store} from "../../src/multi/Store.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract BurveFacetBaseTest is Test, BurveFacetBase {
    /* Guarded functions */

    function tokenCall(address token) external validToken(token) {}
    function tokensCall(
        address _token0,
        address _token1
    ) external validTokens(_token0, _token1) {}

    /* Tests */

    function testValidToken() public {
        address token0 = address(new MockERC20("0", "0", 18));
        address token1 = address(new MockERC20("1", "1", 18));

        TokenRegistry storage tokenReg = Store.tokenRegistry();
        tokenReg.register(token0);
        // This should be fine.
        this.tokenCall(token0);
        // But this hasn't been registered
        vm.expectRevert(
            abi.encodeWithSelector(TokenRegLib.TokenNotFound.selector, token1)
        );
        this.tokenCall(token1);
    }

    /// @dev Because we're reverting on ourself, the test will end prematurely so we split up this test.
    function testInvalidTokens() public {
        address token0 = address(new MockERC20("0", "0", 18));
        address token1 = address(new MockERC20("1", "1", 18));

        vm.expectRevert(
            abi.encodeWithSelector(TokenRegLib.TokenNotFound.selector, token0)
        );
        this.tokensCall(token0, token1);
    }

    function testInvalidTokens1() public {
        address token0 = address(new MockERC20("0", "0", 18));
        address token1 = address(new MockERC20("1", "1", 18));

        TokenRegistry storage tokenReg = Store.tokenRegistry();
        tokenReg.register(token0);

        vm.expectRevert(
            abi.encodeWithSelector(TokenRegLib.TokenNotFound.selector, token1)
        );
        this.tokensCall(token0, token1);
    }

    function testValidTokens() public {
        address token0 = address(new MockERC20("0", "0", 18));
        address token1 = address(new MockERC20("1", "1", 18));

        TokenRegistry storage tokenReg = Store.tokenRegistry();
        tokenReg.register(token0);
        tokenReg.register(token1);
        // No issue
        this.tokensCall(token0, token1);
    }
}
