// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {USDC, USYC} from "src/mock/constants.sol";
import {IUSYCAuthority, USYCRole} from "test/interfaces/IUSYCAuthority.sol";
import {IUSYC} from "test/interfaces/IUSYC.sol";

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IUSDC} from "test/interfaces/IUSDC.sol";

/// @author  Usual Tech Team
/// @title   Deal Tokens
/// @dev     Common functions to deal tokens
contract DealTokens is Test {
    address public constant NULL_ADDRESS = 0x000000000000000000000000000000000000dEaD; // Null address with more than 10,000 ETH
    address public constant USYC_ROLE_SETTER = 0xDbE01f447040F78ccbC8Dfd101BEc1a2C21f800D;

    function _dealUSDC(address to, uint256 amount) internal {
        vm.prank(IUSDC(USDC).masterMinter());
        IUSDC(USDC).configureMinter(address(this), amount);
        IUSDC(USDC).mint(address(to), amount);
    }

    function _dealETH(address _to) internal {
        if (_to.balance >= 1e18) return;

        vm.broadcast(NULL_ADDRESS);
        payable(_to).transfer(10e18);
    }

    function _dealUSYC(address daoCollateral, address _to, uint256 _amount) internal {
        _whitelistUSYC(_to);

        address authority = IUSYC(USYC).authority();
        address authOwner = IUSYCAuthority(authority).owner();

        _dealETH(authOwner);

        vm.startBroadcast(authOwner);
        IUSYCAuthority(authority).setUserRole(authOwner, USYCRole.System_FundAdmin, true);
        IUSYCAuthority(authority).setRoleCapability(
            USYCRole.Custodian_Decentralized, USYC, ERC20.transferFrom.selector, true
        );
        IUSYCAuthority(authority).setUserRole(
            address(daoCollateral), USYCRole.Custodian_Decentralized, true
        );

        IUSYC(USYC).setMinterAllowance(authOwner, _amount);
        IUSYC(USYC).mint(_to, _amount);
        vm.stopBroadcast();
    }

    function _whitelistUSYC(address _to) internal {
        address authority = IUSYC(USYC).authority();
        //address roleSetter = IUSYCAuthority(authority).owner();
        address roleSetter = USYC_ROLE_SETTER;
        _dealETH(roleSetter);

        vm.broadcast(roleSetter);
        IUSYCAuthority(authority).setUserRole(_to, USYCRole.Investor_MFFeederDomestic, true);
    }
}
