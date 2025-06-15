// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {ICurveFactory} from "shared/interfaces/curve/ICurveFactory.sol";
import {
    DAO_COLLATERAL,
    ETH0_MINT,
    ETH0_BURN,
    WSTETH,
    LIDO_STETH_ORACLE_MAINNET,
    MINT_CAP_OPERATOR
} from "src/constants.sol";
import {LidoProxyWstETHPriceFeed} from "src/oracles/LidoWstEthOracle.sol";
import {WSTETH} from "src/constants.sol";
import {ContractScript} from "scripts/deployment/Contracts.s.sol";

import {console} from "forge-std/console.sol";

// solhint-disable-next-line no-console
contract FinalConfigScript is ContractScript {
    function run() public virtual override {
        super.run();

        vm.startBroadcast(usualPrivateKey);

        // add roles
        registryAccess.grantRole(DAO_COLLATERAL, address(daoCollateral));
        registryAccess.grantRole(MINT_CAP_OPERATOR, address(mintcapOperator));
        registryAccess.grantRole(ETH0_MINT, address(daoCollateral));
        registryAccess.grantRole(ETH0_BURN, address(daoCollateral));
        // add rwa to registry if it is not already added
        if (!tokenMapping.isEth0Collateral(WSTETH)) {
            tokenMapping.addEth0CollateralToken(WSTETH);
        }
        console.log("daoCollateral address:", address(daoCollateral));
        console.log("registryContract address:", address(registryContract));
        console.log("registryAccess address:", address(registryAccess));

        // Deploy Lido Oracle
        LidoProxyWstETHPriceFeed lidoOracle = new LidoProxyWstETHPriceFeed(address(WSTETH));
        classicalOracle.initializeTokenOracle(WSTETH, address(lidoOracle), 4 days, false);
        vm.stopBroadcast();
        uint256 price = classicalOracle.getPrice(WSTETH);
        console.log("WSTETH price", uint256(price));
    }
}
