// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";
import {IDiamond} from "Commons/Diamond/interfaces/IDiamond.sol";
import {DiamondCutFacet} from "Commons/Diamond/facets/DiamondCutFacet.sol";
import {InitLib, BurveFacets} from "../../src/multi/InitLib.sol";
import {SimplexDiamond} from "../../src/multi/Diamond.sol";
import {SimplexFacet} from "../../src/multi/facets/SimplexFacet.sol";
import {LockFacet} from "../../src/multi/facets/LockFacet.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockERC4626} from "../mocks/MockERC4626.sol";
import {StoreManipulatorFacet} from "./StoreManipulatorFacet.u.sol";
import {SwapFacet} from "../../src/multi/facets/SwapFacet.sol";
import {ValueFacet} from "../../src/multi/facets/ValueFacet.sol";
import {ValueTokenFacet} from "../../src/multi/facets/ValueTokenFacet.sol";
import {VaultFacet} from "../../src/multi/facets/VaultFacet.sol";
import {VaultType} from "../../src/multi/vertex/VaultProxy.sol";
import {IBGTExchanger, BGTExchanger} from "../../src/integrations/BGTExchange/BGTExchanger.sol";

contract MultiSetupTest is Test {
    // Note: removed the constant tag so we can override INITAL_VALUE in interiting tests
    uint256 public INITIAL_MINT_AMOUNT = 1e30;
    uint128 public INITIAL_VALUE = 1_000_000e18;

    /* Diamond */
    address public diamond;
    ValueFacet public valueFacet;
    ValueTokenFacet public valueTokenFacet;
    VaultFacet public vaultFacet;
    SimplexFacet public simplexFacet;
    SwapFacet public swapFacet;
    LockFacet public lockFacet;
    StoreManipulatorFacet public storeManipulatorFacet; // testing only

    uint16 public closureId;

    /* Integrations */
    IBGTExchanger public bgtEx;
    MockERC20 ibgt;

    /* Test Tokens */
    /// Two mock erc20s for convenience. These are guaranteed to be sorted.
    MockERC20 public token0;
    MockERC20 public token1;
    address[] public tokens;
    IERC4626[] public vaults;

    /* Some Test accounts */
    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    /// Deploy the diamond and facets
    function _newDiamond() internal {
        BurveFacets memory bFacets = InitLib.deployFacets();
        diamond = address(new SimplexDiamond(bFacets, "ValueToken", "BVT"));

        valueFacet = ValueFacet(diamond);
        valueTokenFacet = ValueTokenFacet(diamond);
        vaultFacet = VaultFacet(diamond);
        simplexFacet = SimplexFacet(diamond);
        swapFacet = SwapFacet(diamond);
        lockFacet = LockFacet(diamond);

        _cutStoreManipulatorFacet();
        storeManipulatorFacet = StoreManipulatorFacet(diamond);
    }

    function _cutStoreManipulatorFacet() public {
        IDiamond.FacetCut[] memory cuts = new IDiamond.FacetCut[](1);

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = StoreManipulatorFacet.setClosureValue.selector;
        selectors[1] = StoreManipulatorFacet.setClosureFees.selector;
        selectors[2] = StoreManipulatorFacet.setProtocolEarnings.selector;
        selectors[3] = StoreManipulatorFacet.getVertex.selector;

        cuts[0] = (
            IDiamond.FacetCut({
                facetAddress: address(new StoreManipulatorFacet()),
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: selectors
            })
        );

        DiamondCutFacet cutFacet = DiamondCutFacet(diamond);
        cutFacet.diamondCut(cuts, address(0), "");
    }

    /// Deploy tokens and install them as vertices in the diamond with an edge.
    function _newTokens(uint8 numTokens) public {
        // Setup test tokens
        for (uint8 i = 0; i < numTokens; ++i) {
            string memory idx = Strings.toString(i);
            tokens.push(
                address(
                    new MockERC20(
                        string.concat("Test Token ", idx),
                        string.concat("TEST", idx),
                        18
                    )
                )
            );
        }

        // Ensure token0 address is less than token1
        if (tokens[0] > tokens[1])
            (tokens[0], tokens[1]) = (tokens[1], tokens[0]);

        token0 = MockERC20(tokens[0]);
        token1 = MockERC20(tokens[1]);

        // Add vaults and vertices
        for (uint256 i = 0; i < tokens.length; ++i) {
            string memory idx = Strings.toString(i);
            // Have to setup vaults here in case the token order changed.
            vaults.push(
                IERC4626(
                    address(
                        new MockERC4626(
                            ERC20(tokens[i]),
                            string.concat("Vault ", idx),
                            string.concat("V", idx)
                        )
                    )
                )
            );
            simplexFacet.addVertex(
                tokens[i],
                address(vaults[i]),
                VaultType.E4626
            );
        }

        // Check integrations
        // If a bgt ex already exists, we'll have to add ourselves to the rates.
        if (address(bgtEx) != address(0)) {
            for (uint256 i = 0; i < tokens.length; ++i) {
                bgtEx.setRate(tokens[i], 1 << 128);
            }
        }
    }

    /// Initalize a zero fee closure with the default initial value amount.
    function _initializeClosure(uint16 cid) internal {
        _initializeClosure(cid, INITIAL_VALUE);
    }

    /// Initalize a zero fee closure with the initial value amount.
    function _initializeClosure(uint16 cid, uint128 initValue) internal {
        // Mint ourselves enough to fund the initial target of the pool.
        for (uint256 i = 0; i < tokens.length; ++i) {
            if ((1 << i) & cid > 0) {
                MockERC20(tokens[i]).mint(owner, initValue);
                MockERC20(tokens[i]).approve(
                    address(diamond),
                    type(uint256).max
                );
            }
        }
        simplexFacet.addClosure(cid, initValue, 0, 0);
    }

    /// Initalize a zero fee closure with the initial value amount.
    function _initializeClosure(
        uint16 _cid,
        uint128 startingTarget,
        uint128 baseFeeX128,
        uint128 protocolTakeX128
    ) internal {
        // Mint ourselves enough to fund the initial target of the pool.
        for (uint256 i = 0; i < tokens.length; ++i) {
            if ((1 << i) & _cid > 0) {
                MockERC20(tokens[i]).mint(owner, startingTarget);
                MockERC20(tokens[i]).approve(
                    address(diamond),
                    type(uint256).max
                );
            }
        }
        simplexFacet.addClosure(
            _cid,
            startingTarget,
            baseFeeX128,
            protocolTakeX128
        );
    }

    /// Creates a bgt token, funds the initial mint to the bgtexchanger, sets the rates at 1 to 1,
    /// and installs it onto the diamond.
    /// Feel free to use the owner to set the rate however you'd like.
    function _installBGTExchanger() internal {
        ibgt = new MockERC20("TestBGT", "iBGT", 18);
        bgtEx = new BGTExchanger(address(ibgt));
        ibgt.mint(owner, INITIAL_MINT_AMOUNT);
        ibgt.approve(address(bgtEx), type(uint256).max);
        bgtEx.fund(INITIAL_MINT_AMOUNT);
        bgtEx.addExchanger(diamond);
        for (uint256 i = 0; i < tokens.length; ++i) {
            bgtEx.setRate(tokens[i], 1 << 128);
        }

        simplexFacet.setBGTExchanger(address(bgtEx));
    }

    /// Call this last since it messes with prank.
    function _fundAccount(address account) internal {
        for (uint256 i = 0; i < tokens.length; ++i) {
            MockERC20(tokens[i]).mint(account, INITIAL_MINT_AMOUNT);
        }

        // Approve diamond for all test accounts
        vm.startPrank(account);
        for (uint256 i = 0; i < tokens.length; ++i) {
            MockERC20(tokens[i]).approve(address(diamond), type(uint256).max);
        }
        vm.stopPrank();
    }
}
