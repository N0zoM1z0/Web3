// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

/* Roles */
bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
bytes32 constant DAO_REDEMPTION_ROLE = keccak256("DAO_REDEMPTION_ROLE");
bytes32 constant PAUSING_CONTRACTS_ROLE = keccak256("PAUSING_CONTRACTS_ROLE");
bytes32 constant UNPAUSING_CONTRACTS_ROLE = keccak256("UNPAUSING_CONTRACTS_ROLE");
bytes32 constant BLACKLIST_ROLE = keccak256("BLACKLIST_ROLE");
bytes32 constant DAO_COLLATERAL = keccak256("DAO_COLLATERAL_CONTRACT");
bytes32 constant ETH0_MINT = keccak256("ETH0_MINT");
bytes32 constant ETH0_BURN = keccak256("ETH0_BURN");
bytes32 constant MINT_CAP_OPERATOR = keccak256("MINT_CAP_OPERATOR");
/* Contracts */
bytes32 constant CONTRACT_REGISTRY_ACCESS = keccak256("CONTRACT_REGISTRY_ACCESS");
bytes32 constant CONTRACT_DAO_COLLATERAL = keccak256("CONTRACT_DAO_COLLATERAL");
bytes32 constant CONTRACT_TOKEN_MAPPING = keccak256("CONTRACT_TOKEN_MAPPING");
bytes32 constant CONTRACT_ORACLE = keccak256("CONTRACT_ORACLE");
bytes32 constant CONTRACT_DATA_PUBLISHER = keccak256("CONTRACT_DATA_PUBLISHER");
bytes32 constant CONTRACT_TREASURY = keccak256("CONTRACT_TREASURY");
bytes32 constant CONTRACT_YIELD_TREASURY = keccak256("CONTRACT_YIELD_TREASURY");

/* Registry */
bytes32 constant CONTRACT_REGISTRY = keccak256("CONTRACT_REGISTRY"); // Not set on production

/* Contract tokens */
bytes32 constant CONTRACT_ETH0 = keccak256("CONTRACT_ETH0");

/* Token names and symbols */
string constant ETH0Symbol = "ETH0";
string constant ETH0Name = "Usual ETH";

/* Constants */
uint256 constant SCALAR_ONE = 1e18;

uint256 constant MAX_REDEEM_FEE = 2500;

uint256 constant BASIS_POINT_BASE = 10_000;

uint256 constant ONE_YEAR = 31_536_000; // 365 days
uint256 constant SIX_MONTHS = 15_768_000;
uint256 constant ONE_MONTH = 2_628_000; // ONE_YEAR / 12 = 30,4 days
uint64 constant ONE_WEEK = 604_800;
uint256 constant NUMBER_OF_MONTHS_IN_THREE_YEARS = 36;

uint256 constant REDEEM_FEE = 20; // 0.2% fee

/* Token Addresses */
address constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
address constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

/*
 * The maximum relative price difference between two oracle responses allowed in order for the PriceFeed
 * to return to using the Oracle oracle. 18-digit precision.
 */
uint256 constant INITIAL_MAX_DEPEG_THRESHOLD = 100;

/* Maximum number of RWA tokens that can be associated with ETH0 */
uint256 constant MAX_COLLATERAL_TOKEN_COUNT = 10;

/* Mainnet Usual Deployment */
address constant USUAL_MULTISIG_MAINNET = 0x6e9d65eC80D69b1f508560Bc7aeA5003db1f7FB7;
address constant USUAL_PROXY_ADMIN_MAINNET = 0xaaDa24358620d4638a2eE8788244c6F4b197Ca16;
address constant REGISTRY_CONTRACT_MAINNET = 0x0594cb5ca47eFE1Ff25C7B8B43E221683B4Db34c;
address constant TREASURY_MAINNET = 0x27F1d0DBb7A17b53f9B7d7C193eAD8Dec5452896;
address constant TREASURY_YIELD_MAINNET = 0x3B512A330bD4E899D37D61C80187Af49C3ad249A;

/* Oracle Addresses */

//chainlink oracle for stETH/ETH
address constant LIDO_STETH_ORACLE_MAINNET = 0x86392dC19c0b719886221c78AB11eb8Cf5c52812;
