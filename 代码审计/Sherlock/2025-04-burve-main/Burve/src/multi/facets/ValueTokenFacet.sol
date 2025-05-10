// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Store} from "../Store.sol";
import {Closure} from "../closure/Closure.sol";
import {ClosureId} from "../closure/Id.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

/// An ERC20 interface for the Value token which is mint and burned by unstaking/staking value.
contract ValueTokenFacet is ERC20 {
    /// BGT earning value must be less than overall value when staking or unstaking.
    error InsufficientValueForBgt(uint256 value, uint256 bgtValue);

    constructor() ERC20("", "") {}

    function mint(uint256 value, uint256 bgtValue, uint16 _cid) external {
        require(bgtValue <= value, InsufficientValueForBgt(value, bgtValue));
        ClosureId cid = ClosureId.wrap(_cid);
        Closure storage c = Store.closure(cid); // Validates cid.
        c.unstakeValue(value, bgtValue);
        Store.assets().remove(msg.sender, cid, value, bgtValue);
        _mint(msg.sender, value);
    }

    function burn(uint256 value, uint256 bgtValue, uint16 _cid) external {
        require(bgtValue <= value, InsufficientValueForBgt(value, bgtValue));
        _burn(msg.sender, value);
        ClosureId cid = ClosureId.wrap(_cid);
        Closure storage c = Store.closure(cid); // Validates cid.
        c.stakeValue(value, bgtValue);
        Store.assets().add(msg.sender, cid, value, bgtValue);
    }

    /* Override base contract */
    function name() public view override returns (string memory) {
        string memory _name = Store.simplex().name;
        return string.concat("brv", _name);
    }

    function symbol() public view override returns (string memory) {
        string memory _symbol = Store.simplex().symbol;
        return string.concat("brv", _symbol);
    }
}
