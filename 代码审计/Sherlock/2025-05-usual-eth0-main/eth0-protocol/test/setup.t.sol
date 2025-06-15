// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IERC20Permit} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Permit.sol";

import {Eth0} from "src/token/Eth0.sol";

import {TokenMapping} from "src/TokenMapping.sol";

import {RegistryAccess} from "src/registry/RegistryAccess.sol";
import {IRegistryContract} from "src/interfaces/registry/IRegistryContract.sol";
import {RegistryContract} from "src/registry/RegistryContract.sol";

import {ClassicalOracle} from "src/oracles/ClassicalOracle.sol";
import {DataPublisher} from "src/mock/dataPublisher.sol";
import {MockAggregator} from "src/mock/MockAggregator.sol";
import {IOracle} from "src/interfaces/oracles/IOracle.sol";

import {SigUtils} from "test/utils/sigUtils.sol";

import {DaoCollateral} from "src/daoCollateral/DaoCollateral.sol";

import {ERC20Whitelist} from "src/mock/ERC20Whitelist.sol";
import {USDC} from "src/mock/constants.sol";
import {IRwaMock} from "src/interfaces/token/IRwaMock.sol";
import {ERC4626Mock} from "openzeppelin-contracts/mocks/token/ERC4626Mock.sol";
import {ERC20Mock} from "openzeppelin-contracts/mocks/token/ERC20Mock.sol";
import {SigUtils} from "test/utils/sigUtils.sol";
import {DealTokens} from "test/utils/dealTokens.sol";
import {ChainlinkMock} from "src/mock/ChainlinkMock.sol";

import {ChainlinkMockLido} from "src/mock/ChainlinkMockLido.sol";
import {
    CONTRACT_REGISTRY_ACCESS,
    ETH0_MINT,
    DAO_COLLATERAL,
    CONTRACT_DAO_COLLATERAL,
    CONTRACT_ORACLE,
    CONTRACT_DATA_PUBLISHER,
    CONTRACT_TREASURY,
    CONTRACT_YIELD_TREASURY,
    CONTRACT_TOKEN_MAPPING,
    CONTRACT_ETH0,
    CONTRACT_REGISTRY_ACCESS,
    ONE_WEEK,
    PAUSING_CONTRACTS_ROLE,
    UNPAUSING_CONTRACTS_ROLE,
    DAO_REDEMPTION_ROLE,
    DEFAULT_ADMIN_ROLE,
    BLACKLIST_ROLE,
    MINT_CAP_OPERATOR,
    UNPAUSING_CONTRACTS_ROLE,
    ETH0_MINT,
    ETH0_BURN,
    UNPAUSING_CONTRACTS_ROLE
} from "src/constants.sol";
import {
    DETERMINISTIC_DEPLOYMENT_PROXY,
    CONTRACT_RWA_FACTORY,
    ORACLE_UPDATER,
    REGISTRY_SALT,
    ETH0Symbol,
    ETH0Name,
    REDEEM_FEE
} from "src/mock/constants.sol";

import {RwaFactoryMock} from "src/mock/rwaFactoryMock.sol";
import {Normalize} from "src/utils/normalize.sol";
import {LidoProxyWstETHPriceFeed} from "src/oracles/LidoWstEthOracle.sol";

// solhint-disable-next-line max-states-count

contract SetupTest is Test, DealTokens {
    RegistryAccess public registryAccess;
    RegistryContract public registryContract;
    ChainlinkMock public chainlinkMock;
    LidoProxyWstETHPriceFeed public lidoProxyWstETHPriceFeed;
    ChainlinkMockLido public chainlinkMockLido;

    DaoCollateral public daoCollateral;
    RwaFactoryMock public rwaFactory;
    Eth0 public stbcToken;
    TokenMapping public tokenMapping;
    ClassicalOracle public classicalOracle;
    DataPublisher public dataPublisher;

    uint256 public constant ONE_BPS = 0.0001e18;
    uint256 public constant ONE_PERCENT = 0.01e18;
    uint256 public constant ONE_AND_HALF_PERCENT = 0.015e18;

    address payable public taker;
    address payable public seller;
    address public usualOrg;

    event Received(address, uint256);
    event Upgraded(address indexed implementation);
    event Initialized(uint8 version);

    error InvalidPrice();
    error AmountTooBig();
    error WrongTokenId();
    error NotEnoughCollateral();
    error NullContract();
    error NullAddress();
    error NotAuthorized();
    error ParameterError();
    error AmountIsZero();
    error IncorrectSetting();
    error InsufficientBalance();
    error IncorrectNFTType();
    error InvalidName();
    error InvalidSymbol();
    error Invalid();
    error AlreadyExist();
    error InvalidToken();
    error TokenNotFound();
    error NoCollateral();
    error DeadlineNotPassed();
    error InvalidMask();
    error InvalidIndex();
    error DeadlineNotSet();
    error DeadlineInPast();
    error WrongToken();
    error NotEnoughDeposit();
    error HaveNoRwaToken();
    error NotWhitelisted();
    error AlreadyWhitelisted();
    error NotNFTOwner();
    error InvalidId();
    error ZeroAddress();
    error Blacklisted();
    error SwapMustNotBePaused();

    uint256 public alicePrivKey = 0x1011;
    address public alice = vm.addr(alicePrivKey);
    uint256 public bobPrivKey = 0x2042;
    address public bob = vm.addr(bobPrivKey);
    uint256 public carolPrivKey = 0x3042;
    address public carol = vm.addr(carolPrivKey);
    uint256 public davidPrivKey = 0x4042;
    address public david = vm.addr(davidPrivKey);
    uint256 public jackPrivKey = 0x5042;
    address public jack = vm.addr(jackPrivKey);

    address public admin = vm.addr(0x30);
    address public pauser = vm.addr(0x90);

    address public usual = vm.addr(0x40);
    address public hashnote = vm.addr(0x50);
    address public treasury = vm.addr(0x60);
    address public usdInsurance = vm.addr(0x70);
    address public pegMaintainer = vm.addr(0x80);

    address public treasuryYield = vm.addr(0x1042);
    address public blacklistOperator = vm.addr(0x103);
    address public mintcapOperator = vm.addr(0x104);
    address public unpauser = vm.addr(0x105);
    address public daoredeemer = vm.addr(0x106);

    function setUp() public virtual {
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(carol, "carol");
        vm.label(jack, "jack");
        vm.label(admin, "admin");
        vm.label(pauser, "pauser");
        vm.label(usual, "usual");
        vm.label(treasury, "treasury");
        vm.label(treasuryYield, "treasuryYield");
        vm.label(usdInsurance, "usdInsurance");
        vm.label(hashnote, "hashnote");
        vm.label(blacklistOperator, "blacklistOperator");
        vm.label(mintcapOperator, "mintcapOperator");
        vm.label(unpauser, "unpauser");
        vm.label(daoredeemer, "daoredeemer");
        address computedRegAccessAddress =
            _computeAddress(REGISTRY_SALT, type(RegistryAccess).creationCode, address(admin));
        registryAccess = RegistryAccess(computedRegAccessAddress);

        // RegistryAccess
        if (computedRegAccessAddress.code.length == 0) {
            registryAccess = new RegistryAccess{salt: REGISTRY_SALT}();
            _resetInitializerImplementation(address(registryAccess));
            registryAccess.initialize(address(admin));
        }

        // RegistryAccess
        vm.startPrank(admin);
        address accessRegistry = address(registryAccess);

        address computedRegContractAddress =
            _computeAddress(REGISTRY_SALT, type(RegistryContract).creationCode, accessRegistry);
        registryContract = RegistryContract(computedRegContractAddress);

        // RegistryContract
        if (computedRegContractAddress.code.length == 0) {
            registryContract = new RegistryContract{salt: REGISTRY_SALT}();
            _resetInitializerImplementation(address(registryContract));
            registryContract.initialize(address(accessRegistry));
        }

        registryContract.setContract(CONTRACT_REGISTRY_ACCESS, address(registryAccess));

        // TokenMapping
        tokenMapping = new TokenMapping();
        _resetInitializerImplementation(address(tokenMapping));
        tokenMapping.initialize(address(registryAccess), address(registryContract));
        registryContract.setContract(CONTRACT_TOKEN_MAPPING, address(tokenMapping));

        // treasury
        registryContract.setContract(CONTRACT_TREASURY, treasury);
        registryContract.setContract(CONTRACT_YIELD_TREASURY, treasuryYield);

        // oracle
        classicalOracle = new ClassicalOracle();
        _resetInitializerImplementation(address(classicalOracle));
        classicalOracle.initialize(address(registryContract));
        registryContract.setContract(CONTRACT_ORACLE, address(classicalOracle));
        dataPublisher = new DataPublisher(address(registryContract));
        registryContract.setContract(CONTRACT_DATA_PUBLISHER, address(dataPublisher));

        // Eth0
        stbcToken = new Eth0();
        _resetInitializerImplementation(address(stbcToken));
        stbcToken.initialize(address(registryContract), ETH0Name, ETH0Symbol);
        registryContract.setContract(CONTRACT_ETH0, address(stbcToken));

        // DaoCollateral
        daoCollateral = new DaoCollateral();
        _resetInitializerImplementation(address(daoCollateral));
        daoCollateral.initialize(address(registryContract), REDEEM_FEE);
        registryContract.setContract(CONTRACT_DAO_COLLATERAL, address(daoCollateral));

        // rwa factory
        rwaFactory = new RwaFactoryMock(address(registryContract));
        registryContract.setContract(CONTRACT_RWA_FACTORY, address(rwaFactory));

        chainlinkMock = new ChainlinkMock();
        chainlinkMock.setRoundData(
            1, // roundId
            1e8, // answer
            block.timestamp, // startedAt
            block.timestamp, // updatedAt
            1 // answeredInRound
        );

        // add roles
        registryAccess.grantRole(DAO_COLLATERAL, address(daoCollateral));
        registryAccess.grantRole(ETH0_MINT, address(daoCollateral));
        registryAccess.grantRole(ETH0_MINT, treasury);
        registryAccess.grantRole(ETH0_BURN, address(daoCollateral));
        registryAccess.grantRole(PAUSING_CONTRACTS_ROLE, address(pauser));
        registryAccess.grantRole(BLACKLIST_ROLE, address(blacklistOperator));
        registryAccess.grantRole(MINT_CAP_OPERATOR, address(mintcapOperator));
        registryAccess.grantRole(UNPAUSING_CONTRACTS_ROLE, address(unpauser));
        registryAccess.grantRole(DAO_REDEMPTION_ROLE, address(daoredeemer));
        vm.stopPrank();

        vm.startPrank(mintcapOperator);
        stbcToken.setMintCap(type(uint256).max);
        vm.stopPrank();

        // Deploy and initialize ChainlinkMockLido
        chainlinkMockLido = new ChainlinkMockLido();
        chainlinkMockLido.setRoundData(
            1, // roundId
            1e18, // answer (1:1 ratio)
            block.timestamp, // startedAt
            block.timestamp, // updatedAt
            1 // answeredInRound
        );

        // Deploy LidoProxyWstETHPriceFeed with mock
        lidoProxyWstETHPriceFeed = new LidoProxyWstETHPriceFeed(address(chainlinkMockLido));
        vm.label(address(lidoProxyWstETHPriceFeed), "LidoProxyWstETHPriceFeed");
    }

    function _computeAddress(bytes32 salt, bytes memory _code, address _usual)
        internal
        pure
        returns (address addr)
    {
        bytes memory bytecode = abi.encodePacked(_code, abi.encode(_usual));
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff), DETERMINISTIC_DEPLOYMENT_PROXY, salt, keccak256(bytecode)
            )
        );
        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint256(hash)));
    }

    function _initializeOracleFeed(address caller, address token, int256 price) internal {
        vm.prank(caller);
        dataPublisher.publishData(token, price);
        skip(1);
        vm.prank(caller);
        dataPublisher.publishData(token, price);
        vm.prank(admin);
    }

    function whitelistPublisher(address rwa, address ETH0) public {
        vm.startPrank(admin);
        if (!dataPublisher.isWhitelistPublisher(rwa, hashnote)) {
            dataPublisher.addWhitelistPublisher(rwa, hashnote);
        }
        if (!dataPublisher.isWhitelistPublisher(ETH0, usual)) {
            dataPublisher.addWhitelistPublisher(ETH0, usual);
        }
        require(dataPublisher.isWhitelistPublisher(ETH0, usual), "not whitelisted");
        vm.stopPrank();
    }

    function testSetup() public view {
        assertEq(address(registryAccess), registryContract.getContract(CONTRACT_REGISTRY_ACCESS));
    }

    function _getNonce(address token, address owner) internal view returns (uint256) {
        return IERC20Permit(token).nonces(owner);
    }

    function _getSelfPermitData(
        address token,
        address owner,
        uint256 ownerPrivateKey,
        address spender,
        uint256 amount,
        uint256 deadline
    ) internal returns (uint8, bytes32, bytes32) {
        uint256 nonce = _getNonce(token, owner);
        return _signPermitData(
            token, _getPermitData(owner, spender, amount, deadline, nonce), ownerPrivateKey
        );
    }

    function _getPermitData(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint256 nonce
    ) internal pure returns (SigUtils.Permit memory permit) {
        permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: amount,
            nonce: nonce,
            deadline: deadline
        });
    }

    function _signPermitData(address token, SigUtils.Permit memory permit, uint256 ownerPrivateKey)
        internal
        returns (uint8, bytes32, bytes32)
    {
        IERC20Permit ercPermit = IERC20Permit(token);
        SigUtils sigUtils = new SigUtils(ercPermit.DOMAIN_SEPARATOR());
        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        return (v, r, s);
    }

    function _getSelfPermitData(
        address token,
        address owner,
        uint256 ownerPrivateKey,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint256 nonce
    ) internal returns (uint8, bytes32, bytes32) {
        return _signPermitData(
            token, _getPermitData(owner, spender, amount, deadline, nonce), ownerPrivateKey
        );
    }

    function _setOraclePrice(address token, uint256 amount) internal {
        MockAggregator dataSource = new MockAggregator(token, int256(amount), 1);

        vm.prank(admin);
        classicalOracle.initializeTokenOracle(token, address(dataSource), ONE_WEEK, false);

        amount = Normalize.tokenAmountToWad(amount, uint8(dataSource.decimals()));
        assertEq(classicalOracle.getPrice(address(token)), amount);
    }

    function _getTenPercent(uint256 amount) internal pure returns (uint256) {
        return amount * 1000 / 10_000;
    }

    function _getDotFivePercent(uint256 amount) internal pure returns (uint256) {
        return amount * 500 / 100_000;
    }

    function _getDotOnePercent(uint256 amount) internal pure returns (uint256) {
        return amount * 100 / 100_000;
    }

    function _getAmountMinusFeeInUSD(uint256 amount, address collateralToken)
        internal
        view
        returns (uint256)
    {
        // get amount in USD
        uint256 amountInUSD = classicalOracle.getQuote(collateralToken, amount);

        // take 0.1% fee on USD
        uint256 fee = _getDotOnePercent(amountInUSD);

        return amount - fee;
    }

    function _resetInitializerImplementation(address implementation) internal {
        // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
        bytes32 INITIALIZABLE_STORAGE =
            0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;
        // Set the storage slot to uninitialized
        vm.store(address(implementation), INITIALIZABLE_STORAGE, 0);
    }

    function _whitelistRWA(address rwa, address user) internal {
        vm.startPrank(address(admin));
        // check if user is whitelisted
        if (!ERC20Whitelist(rwa).isWhitelisted(user)) {
            // user needs to be whitelisted
            ERC20Whitelist(rwa).whitelist(user);
        }
        vm.stopPrank();
    }

    function _setupBucket(address rwa, address ETH0) internal {
        vm.startPrank(address(admin));
        registryAccess.grantRole(ORACLE_UPDATER, usual);
        registryAccess.grantRole(ORACLE_UPDATER, hashnote);
        vm.stopPrank();
        _initializeOracleFeed(usual, address(ETH0), 1e18);

        if (!tokenMapping.isEth0Collateral(rwa)) {
            vm.prank(admin);
            tokenMapping.addEth0CollateralToken(rwa);
        }
        // treasury allow max uint256 to daoCollateral
        vm.prank(treasury);
        ERC20(rwa).approve(address(daoCollateral), type(uint256).max);
    }

    function _setupBucket(address rwa) internal {
        _setupBucket(rwa, address(stbcToken));
    }

    function _linkSTBCToRwa(IRwaMock rwa) internal {
        if (!tokenMapping.isEth0Collateral(address(rwa))) {
            vm.prank(admin);
            tokenMapping.addEth0CollateralToken(address(rwa));
        }
    }
}
