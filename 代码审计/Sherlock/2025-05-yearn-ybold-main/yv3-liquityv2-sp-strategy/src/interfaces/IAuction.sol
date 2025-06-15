// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

interface IAuction {

    function auctionLength() external view returns (uint256);
    function available(
        address _token
    ) external view returns (uint256);
    function isActive(
        address _token
    ) external view returns (bool);
    function price(
        address _from
    ) external view returns (uint256);
    function startingPrice() external view returns (uint256);
    function kick(
        address _token
    ) external returns (uint256);
    function setStartingPrice(
        uint256 _startingPrice
    ) external;
    function enable(
        address _from
    ) external;
    function settle(
        address _token
    ) external;

}
