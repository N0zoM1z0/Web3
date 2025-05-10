// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

/// A naive interface for exchanging fees for BGT.
/// For now its not very gas optimized because gas is very cheap but in the future
/// we can use transient storage to reserve a conversion balance.
interface IBGTExchanger {
    /// Requests the specified token and amount in exchange for bgt at the set rate.
    /// The BGT is not given immediately, instead the caller has a right for which they can withdraw.
    /// By keeping the BGT on this contract, we have more flexibility for migrations, or staking, etc.
    /// If the entire in amount is not needed for the remaining bgt available, it'll only take what is needed.
    function exchange(
        address inToken,
        uint128 amount
    ) external returns (uint256 bgtAmount, uint256 spendAmount);

    /// A view version of exchange that anyone can call.
    function viewExchange(
        address inToken,
        uint128 amount
    ) external view returns (uint256 bgtAmount, uint256 spendAmount);

    /// Query the amount of BGT owed to a caller.
    function getOwed(address caller) external view returns (uint256 bgtOwed);

    /// Withdraw some of the bgt owed to the msg sender.
    function withdraw(address recipient, uint256 bgtAmount) external;

    /// Returns the amount of bgt one unit of the inToken would fetch as an X128 number.
    function rate(address inToken) external view returns (uint256 rateX128);

    /// Get the liquid bgt in use. This can potentially change.
    function bgtToken() external view returns (address liquidBGT);

    /// The amount of BGT up for exchange.
    function bgtBalance() external view returns (uint256 balance);

    /// Check if a contract can exchange bgt or not.
    function isExchanger(address caller) external view returns (bool);

    /* Admin Functions */
    /// The admin can add which contracts are allowed to exchange.
    function addExchanger(address caller) external;

    /// Remove permissions from this caller from exchanging.
    function removeExchanger(address caller) external;

    function setRate(address inToken, uint256 rateX128) external;

    /// Send the earned token balance to a target (the reward vault to earn more BGT)
    function sendBalance(address token, address to, uint256 amount) external;

    /// Retrieves bgt from the msg sender for exchange.
    function fund(uint256 amount) external;

    /// Set a backup IBGTExchanger to fallback to owed balances.
    /// This is useful when updating a protocol to a new IBGTExchanger but we need to pay out owed balances.
    function setBackup(address backup) external;
}
