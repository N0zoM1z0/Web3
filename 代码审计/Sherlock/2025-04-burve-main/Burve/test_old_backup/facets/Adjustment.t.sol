// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {MultiSetupTest} from "./MultiSetup.u.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockERC4626} from "../mocks/MockERC4626.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {VaultType} from "../../src/multi/VaultProxy.sol";
import {TransferHelper} from "../../src/TransferHelper.sol";

contract AdjustmentTest is MultiSetupTest {
    function setUp() public {
        _newDiamond();
        _newTokens(2);

        // Add a 6 decimal token.
        tokens.push(address(new MockERC20("Test Token 3", "TEST3", 6)));
        vaults.push(
            IERC4626(
                address(new MockERC4626(ERC20(tokens[2]), "vault 3", "V3"))
            )
        );
        simplexFacet.addVertex(tokens[2], address(vaults[2]), VaultType.E4626);

        _fundAccount(address(this));
    }

    function testInitLiq() public {
        // Mint some liquidity. We should put them in equal proportion according to their decimals.
        uint128[] memory amounts = new uint128[](3);
        amounts[0] = 100e18;
        amounts[1] = 100e18;
        amounts[2] = 100e6;
        liqFacet.addLiq(address(this), 0x7, amounts);

        uint160 sqrtPX96 = swapFacet.getSqrtPrice(tokens[2], tokens[0]);
        assertEq(sqrtPX96, 1 << 96);

        // Had we minted with equal balances, 3 would be cheap.
        amounts[0] = 0;
        amounts[1] = 0;
        amounts[2] = 100e18 - 100e6;
        liqFacet.addLiq(address(this), 0x7, amounts);
        // This will lower the third tokens price.
        sqrtPX96 = swapFacet.getSqrtPrice(tokens[2], tokens[0]);
        if (tokens[2] < tokens[0]) {
            assertLt(sqrtPX96, 1 << 96);
        } else {
            assertGt(sqrtPX96, 1 << 96);
        }
    }

    function testAddedShares() public {
        // Mint some liquidity. We should put them in equal proportion according to their decimals.
        uint128[] memory amounts = new uint128[](3);
        amounts[0] = 1e18;
        amounts[1] = 1e18;
        amounts[2] = 1e6;
        uint256 initLiq = liqFacet.addLiq(address(this), 0x7, amounts);

        // These three mints should all be of roughly equal value.
        amounts[0] = 1e12;
        amounts[1] = 0;
        amounts[2] = 0;
        uint256 added0 = liqFacet.addLiq(address(this), 0x7, amounts);
        amounts[0] = 0;
        amounts[1] = 1e12;
        amounts[2] = 0;
        uint256 added1 = liqFacet.addLiq(address(this), 0x7, amounts);
        amounts[0] = 0;
        amounts[1] = 0;
        amounts[2] = 1;
        uint256 added2 = liqFacet.addLiq(address(this), 0x7, amounts);
        assertApproxEqRel(initLiq / 3e6, added0, 1e16); // 1% diff
        assertApproxEqRel(added0, added1, 1e16); // 1% diff.
        assertApproxEqRel(added0, added2, 1e16); // 1% diff.
        assertApproxEqRel(added1, added2, 1e16); // 1% diff.
        // What appears odd at first is that adding these small amounts together gets successively more shares.
        // This is because it slightly pushes down the price of the token after they deposit.
        // So effective the induced slight arb is given to the next person LPing.
        assertGt(added1, added0);
        assertGt(added2, added1);
        // To show this is not a property of the token, we now add 2 again.
        uint256 added22 = liqFacet.addLiq(address(this), 0x7, amounts);
        assertLt(added22, added2);
        assertApproxEqRel(added22, added2, 1e16); // 1% diff.
        // Being the first to move things out of balance is what causes it.
        // In fact, at these small balances, the two "firsts" have equal shares.
        assertEq(added0, added22);
    }

    function testSwap() public {
        uint128[] memory amounts = new uint128[](3);
        amounts[0] = 100e18;
        amounts[1] = 100e18;
        amounts[2] = 100e6;
        liqFacet.addLiq(address(this), 0x7, amounts);

        // Our swap should basically be one for one, adjusted.
        (uint256 x, uint256 y, ) = swapFacet.simSwap(
            tokens[0],
            tokens[1],
            10000,
            1 << 95
        );
        assertApproxEqAbs(x, y, 1); // 1 for rounding.

        (, uint256 refY, ) = swapFacet.simSwap(
            tokens[0],
            tokens[1],
            1e12,
            1 << 95
        );

        uint160 limit = tokens[2] < tokens[0] ? 1 << 95 : 1 << 97;
        (, y) = swapFacet.swap(address(this), tokens[2], tokens[0], 1, limit); // The same as swapping 1e12.
        assertEq(y, refY);
        assertApproxEqAbs(y, 1e12, 1e5); // There's some slippage at this amount.
    }

    function testVault() public {
        uint128[] memory amounts = new uint128[](3);
        amounts[0] = 100e18;
        amounts[1] = 100e18;
        amounts[2] = 100e5;
        liqFacet.addLiq(address(this), 0x7, amounts);

        // Balance is currently insufficient.
        uint160 sqrtPX96 = swapFacet.getSqrtPrice(tokens[2], tokens[0]);
        if (tokens[2] < tokens[0])
            assertGt(sqrtPX96, 1 << 97); // More valuable, greater than 2.
        else assertLt(sqrtPX96, 1 << 95); // The price is less than 0.5!

        // Adding some tokens to the vault will skew prices because of the adjustment.
        TransferHelper.safeTransfer(
            tokens[2],
            address(vaults[2]),
            100e6 - 100e5 + 10 // Due to openzeppelin's ERC4626 conversions, directly sending tokens loses some dust.
        );
        sqrtPX96 = swapFacet.getSqrtPrice(tokens[2], tokens[0]);
        assertEq(sqrtPX96, 1 << 96, "2");
    }
}
