// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {AdminLib} from "Commons/Util/Admin.sol";

import {IBGTExchanger} from "./IBGTExchanger.sol";
import {FullMath} from "../../FullMath.sol";
import {TransferHelper} from "../../TransferHelper.sol";

contract BGTExchanger is IBGTExchanger {
    mapping(address token => uint256 rateX128) public rate;
    mapping(address caller => uint256) public owed;
    mapping(address caller => uint256) public withdrawn;
    mapping(address caller => bool) public isExchanger;
    address public bgtToken;
    // The amount still unowed to anyone.
    // Because of this, one can't just send bgt to this contract to fund it or it
    // won't be counted in this balance.
    uint256 public bgtBalance;
    IBGTExchanger public backupEx;

    error NoExchangePermissions();
    error InsufficientOwed();

    constructor(address _bgtToken) {
        AdminLib.initOwner(msg.sender);
        bgtToken = _bgtToken;
    }

    /// @inheritdoc IBGTExchanger
    function exchange(
        address inToken,
        uint128 amount
    ) external returns (uint256 bgtAmount, uint256 spendAmount) {
        if (!isExchanger[msg.sender]) revert NoExchangePermissions();

        (bgtAmount, spendAmount) = viewExchange(inToken, amount); // 这里有overflow的预防
        if (bgtAmount > 0) {
            bgtBalance -= bgtAmount;
            TransferHelper.safeTransferFrom( // We take what we need.
                    inToken,
                    msg.sender,
                    address(this),
                    spendAmount
                );
            owed[msg.sender] += bgtAmount;
        }
    }

    /// @inheritdoc IBGTExchanger
    function viewExchange(
        address inToken,
        uint128 amount
    ) public view returns (uint256 bgtAmount, uint256 spendAmount) {
        // If rate is zero, the spendAmount remains zero.
        bgtAmount = FullMath.mulX128(rate[inToken], amount, false);

        if (bgtBalance < bgtAmount) {
            bgtAmount = bgtBalance;
            // Rate won't be zero here or else bgtAmount is 0 and can't be more.
            amount = uint128(
                FullMath.mulDivRoundingUp(bgtAmount, 1 << 128, rate[inToken])
            );
        }

        if (bgtAmount != 0) {
            spendAmount = amount;
        }
    }

    /// @inheritdoc IBGTExchanger
    function getOwed(address caller) public view returns (uint256 _owed) {
        _owed = owed[caller];
        if (address(backupEx) != address(0)) {
            _owed += backupEx.getOwed(caller); // 它表明可能存在一个 Exchanger 合约升级或迁移的机制。用户可能在旧的（现在是 backupEx）合约里还有未领取的 BGT，这个函数会将新旧合约里的欠款合并计算。
        }
        _owed -= withdrawn[caller];
    }

    /// @inheritdoc IBGTExchanger
    function withdraw(address recipient, uint256 bgtAmount) external {
        uint256 _owed = getOwed(msg.sender);
        if (bgtAmount == 0) return;
        if (_owed < bgtAmount) revert InsufficientOwed();
        withdrawn[msg.sender] += bgtAmount;
        TransferHelper.safeTransfer(bgtToken, recipient, bgtAmount);
    }

    /* Admin Functions */

    /// @inheritdoc IBGTExchanger
    function addExchanger(address caller) external {
        AdminLib.validateOwner();
        isExchanger[caller] = true;
    }

    /// @inheritdoc IBGTExchanger
    function removeExchanger(address caller) external {
        AdminLib.validateOwner();
        isExchanger[caller] = false;
    }

    /// @inheritdoc IBGTExchanger
    function setRate(address inToken, uint256 rateX128) external {
        AdminLib.validateOwner();
        rate[inToken] = rateX128;
    }

    /// @inheritdoc IBGTExchanger
    function sendBalance(address token, address to, uint256 amount) external {
        AdminLib.validateOwner();
        TransferHelper.safeTransfer(token, to, amount);
    }

    /// @inheritdoc IBGTExchanger
    function fund(uint256 amount) external {
        bgtBalance += amount;
        TransferHelper.safeTransferFrom(
            bgtToken,
            msg.sender,
            address(this),
            amount
        );
    }

    /// @inheritdoc IBGTExchanger
    function setBackup(address backup) external {
        AdminLib.validateOwner();
        backupEx = IBGTExchanger(backup);
    }
}
