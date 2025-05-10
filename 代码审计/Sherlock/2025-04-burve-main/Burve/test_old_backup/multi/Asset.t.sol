// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {AssetLib} from "../../src/multi/Asset.sol";
import {ClosureId} from "../../src/multi/Closure.sol";

contract AssetTest is Test {
    function setUp() public {}

    function testBasic() public {
        address owner = address(0xB33F);
        ClosureId cid = ClosureId.wrap(1);
        uint256 shares = AssetLib.add(owner, cid, 100, 100);
        uint256 percentX256 = AssetLib.remove(owner, cid, shares);
        assertApproxEqAbs(type(uint256).max, percentX256, 100);
    }

    // Removing too many shares fails.
    function testOverRemove() public {
        address owner = address(0xB33F);
        ClosureId cid = ClosureId.wrap(1);
        uint256 shares = AssetLib.add(owner, cid, 100, 100);
        vm.expectRevert();
        AssetLib.remove(owner, cid, shares + 1);
    }

    // Under remove is fine though.
    function testHalfRemove() public {
        address owner = address(0xB33F);
        ClosureId cid = ClosureId.wrap(1);
        uint256 shares = AssetLib.add(owner, cid, 100, 100);
        uint256 percentX256 = AssetLib.remove(owner, cid, shares / 2);
        assertApproxEqAbs(1 << 255, percentX256, 100);
    }

    // Remove multiple adds together.
    function testMultipleAdds() public {
        address owner = address(0xB33F);
        ClosureId cid = ClosureId.wrap(1);
        uint256 shares0 = AssetLib.add(owner, cid, 100, 100);
        uint256 shares1 = AssetLib.add(owner, cid, 200, 300);
        uint256 percentX256 = AssetLib.remove(owner, cid, shares0 + shares1);
        assertApproxEqAbs(type(uint256).max, percentX256, 100);
    }
}
