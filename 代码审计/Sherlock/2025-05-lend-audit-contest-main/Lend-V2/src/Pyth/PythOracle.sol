// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import "../PriceOracle.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

contract PythOracle is PriceOracle {
    error PythOracle_FeedNotFound(address lToken);
    error PythOracle_NoValidPrices(address lToken);
    error PythOracle_StalePrice(address lToken);

    uint256 public constant PRICE_SCALAR = 1e10;
    uint256 public constant STALENESS_THRESHOLD = 60 minutes;

    IPyth public immutable pyth;
    mapping(address lToken => bytes32 priceId) public lTokenToPriceId;
    mapping(address lToken => uint256 lastValidPrice) public lastValidPrices;

    constructor(address _pyth) {
        pyth = IPyth(_pyth);
    }

    function addLTokenToPriceId(address lToken, bytes32 priceId) external {
        lTokenToPriceId[lToken] = priceId;
    }

    function getUnderlyingPrice(LToken lToken) external view virtual override returns (uint256) {
        bytes32 priceId = lTokenToPriceId[address(lToken)];
        if (priceId == bytes32(0)) revert PythOracle_FeedNotFound(address(lToken));

        PythStructs.Price memory price = pyth.getPriceUnsafe(priceId);

        // If price is stale, return the last valid price
        if (block.timestamp - price.publishTime > STALENESS_THRESHOLD && lastValidPrices[address(lToken)] != 0) {
            return lastValidPrices[address(lToken)];
        }

        // If price is not valid, return the last valid price
        if (price.price <= 0 && lastValidPrices[address(lToken)] != 0) {
            return lastValidPrices[address(lToken)];
        }

        uint256 exponent = 18 - abs(price.expo);

        return abs(price.price) * (10 ** exponent);
    }

    /// @dev Returns the absolute value of `x`.
    function abs(int256 x) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(sar(255, x), add(sar(255, x), x))
        }
    }
}
