// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "../LErc20.sol";
import "../LToken.sol";
import "../PriceOracle.sol";
import "../EIP20Interface.sol";
import "../Governance/GovernorAlpha.sol";
import "../Governance/Lend.sol";

interface LendtrollerLensInterface {
    function markets(address) external view returns (bool, uint256);
    function oracle() external view returns (PriceOracle);
    function getAccountLiquidity(address) external view returns (uint256, uint256, uint256);
    function getAssetsIn(address) external view returns (LToken[] memory);
    function claimLend(address) external;
    function lendAccrued(address) external view returns (uint256);
    function lendSpeeds(address) external view returns (uint256);
    function lendSupplySpeeds(address) external view returns (uint256);
    function lendBorrowSpeeds(address) external view returns (uint256);
    function borrowCaps(address) external view returns (uint256);
}

interface GovernorBravoInterface {
    struct Receipt {
        bool hasVoted;
        uint8 support;
        uint96 votes;
    }

    struct Proposal {
        uint256 id;
        address proposer;
        uint256 eta;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool canceled;
        bool executed;
    }

    function getActions(uint256 proposalId)
        external
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        );
    function proposals(uint256 proposalId) external view returns (Proposal memory);
    function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory);
}

contract CompoundLens {
    struct LTokenMetadata {
        address lToken;
        uint256 exchangeRateCurrent;
        uint256 supplyRatePerBlock;
        uint256 borrowRatePerBlock;
        uint256 reserveFactorMantissa;
        uint256 totalBorrows;
        uint256 totalReserves;
        uint256 totalSupply;
        uint256 totalCash;
        bool isListed;
        uint256 collateralFactorMantissa;
        address underlyingAssetAddress;
        uint256 cTokenDecimals;
        uint256 underlyingDecimals;
        uint256 compSupplySpeed;
        uint256 compBorrowSpeed;
        uint256 borrowCap;
    }

    function getCompSpeeds(LendtrollerLensInterface lendtroller, LToken lToken) internal returns (uint256, uint256) {
        // Getting lend speeds is gnarly due to not every network having the
        // split lend speeds from Proposal 62 and other networks don't even
        // have lend speeds.
        uint256 compSupplySpeed = 0;
        (bool compSupplySpeedSuccess, bytes memory compSupplySpeedReturnData) = address(lendtroller).call(
            abi.encodePacked(lendtroller.lendSupplySpeeds.selector, abi.encode(address(lToken)))
        );
        if (compSupplySpeedSuccess) {
            compSupplySpeed = abi.decode(compSupplySpeedReturnData, (uint256));
        }

        uint256 compBorrowSpeed = 0;
        (bool compBorrowSpeedSuccess, bytes memory compBorrowSpeedReturnData) = address(lendtroller).call(
            abi.encodePacked(lendtroller.lendBorrowSpeeds.selector, abi.encode(address(lToken)))
        );
        if (compBorrowSpeedSuccess) {
            compBorrowSpeed = abi.decode(compBorrowSpeedReturnData, (uint256));
        }

        // If the split lend speeds call doesn't work, try the  oldest non-spit version.
        if (!compSupplySpeedSuccess || !compBorrowSpeedSuccess) {
            (bool lendSpeedSuccess, bytes memory lendSpeedReturnData) = address(lendtroller).call(
                abi.encodePacked(lendtroller.lendSpeeds.selector, abi.encode(address(lToken)))
            );
            if (lendSpeedSuccess) {
                compSupplySpeed = compBorrowSpeed = abi.decode(lendSpeedReturnData, (uint256));
            }
        }
        return (compSupplySpeed, compBorrowSpeed);
    }

    function cTokenMetadata(LToken lToken) public returns (LTokenMetadata memory) {
        uint256 exchangeRateCurrent = lToken.exchangeRateCurrent();
        LendtrollerLensInterface lendtroller = LendtrollerLensInterface(address(lToken.lendtroller()));
        (bool isListed, uint256 collateralFactorMantissa) = lendtroller.markets(address(lToken));
        address underlyingAssetAddress;
        uint256 underlyingDecimals;

        if (compareStrings(lToken.symbol(), "lETH")) {
            underlyingAssetAddress = address(0);
            underlyingDecimals = 18;
        } else {
            LErc20 cErc20 = LErc20(address(lToken));
            underlyingAssetAddress = cErc20.underlying();
            underlyingDecimals = EIP20Interface(cErc20.underlying()).decimals();
        }

        (uint256 compSupplySpeed, uint256 compBorrowSpeed) = getCompSpeeds(lendtroller, lToken);

        uint256 borrowCap = 0;
        (bool borrowCapSuccess, bytes memory borrowCapReturnData) =
            address(lendtroller).call(abi.encodePacked(lendtroller.borrowCaps.selector, abi.encode(address(lToken))));
        if (borrowCapSuccess) {
            borrowCap = abi.decode(borrowCapReturnData, (uint256));
        }

        return LTokenMetadata({
            lToken: address(lToken),
            exchangeRateCurrent: exchangeRateCurrent,
            supplyRatePerBlock: lToken.supplyRatePerBlock(),
            borrowRatePerBlock: lToken.borrowRatePerBlock(),
            reserveFactorMantissa: lToken.reserveFactorMantissa(),
            totalBorrows: lToken.totalBorrows(),
            totalReserves: lToken.totalReserves(),
            totalSupply: lToken.totalSupply(),
            totalCash: lToken.getCash(),
            isListed: isListed,
            collateralFactorMantissa: collateralFactorMantissa,
            underlyingAssetAddress: underlyingAssetAddress,
            cTokenDecimals: lToken.decimals(),
            underlyingDecimals: underlyingDecimals,
            compSupplySpeed: compSupplySpeed,
            compBorrowSpeed: compBorrowSpeed,
            borrowCap: borrowCap
        });
    }

    function cTokenMetadataAll(LToken[] calldata lTokens) external returns (LTokenMetadata[] memory) {
        uint256 cTokenCount = lTokens.length;
        LTokenMetadata[] memory res = new LTokenMetadata[](cTokenCount);
        for (uint256 i = 0; i < cTokenCount; i++) {
            res[i] = cTokenMetadata(lTokens[i]);
        }
        return res;
    }

    struct LTokenBalances {
        address lToken;
        uint256 balanceOf;
        uint256 borrowBalanceCurrent;
        uint256 balanceOfUnderlying;
        uint256 tokenBalance;
        uint256 tokenAllowance;
    }

    function lTokenBalances(LToken lToken, address payable account) public returns (LTokenBalances memory) {
        uint256 balanceOf = lToken.balanceOf(account);
        uint256 borrowBalanceCurrent = lToken.borrowBalanceCurrent(account);
        uint256 balanceOfUnderlying = lToken.balanceOfUnderlying(account);
        uint256 tokenBalance;
        uint256 tokenAllowance;

        if (compareStrings(lToken.symbol(), "lETH")) {
            tokenBalance = account.balance;
            tokenAllowance = account.balance;
        } else {
            LErc20 cErc20 = LErc20(address(lToken));
            EIP20Interface underlying = EIP20Interface(cErc20.underlying());
            tokenBalance = underlying.balanceOf(account);
            tokenAllowance = underlying.allowance(account, address(lToken));
        }

        return LTokenBalances({
            lToken: address(lToken),
            balanceOf: balanceOf,
            borrowBalanceCurrent: borrowBalanceCurrent,
            balanceOfUnderlying: balanceOfUnderlying,
            tokenBalance: tokenBalance,
            tokenAllowance: tokenAllowance
        });
    }

    function lTokenBalancesAll(LToken[] calldata lTokens, address payable account)
        external
        returns (LTokenBalances[] memory)
    {
        uint256 cTokenCount = lTokens.length;
        LTokenBalances[] memory res = new LTokenBalances[](cTokenCount);
        for (uint256 i = 0; i < cTokenCount; i++) {
            res[i] = lTokenBalances(lTokens[i], account);
        }
        return res;
    }

    struct LTokenUnderlyingPrice {
        address lToken;
        uint256 underlyingPrice;
    }

    function cTokenUnderlyingPrice(LToken lToken) public returns (LTokenUnderlyingPrice memory) {
        LendtrollerLensInterface lendtroller = LendtrollerLensInterface(address(lToken.lendtroller()));
        PriceOracle priceOracle = lendtroller.oracle();

        return LTokenUnderlyingPrice({lToken: address(lToken), underlyingPrice: priceOracle.getUnderlyingPrice(lToken)});
    }

    function cTokenUnderlyingPriceAll(LToken[] calldata lTokens) external returns (LTokenUnderlyingPrice[] memory) {
        uint256 cTokenCount = lTokens.length;
        LTokenUnderlyingPrice[] memory res = new LTokenUnderlyingPrice[](cTokenCount);
        for (uint256 i = 0; i < cTokenCount; i++) {
            res[i] = cTokenUnderlyingPrice(lTokens[i]);
        }
        return res;
    }

    struct AccountLimits {
        LToken[] markets;
        uint256 liquidity;
        uint256 shortfall;
    }

    function getAccountLimits(LendtrollerLensInterface lendtroller, address account)
        public
        returns (AccountLimits memory)
    {
        (uint256 errorCode, uint256 liquidity, uint256 shortfall) = lendtroller.getAccountLiquidity(account);
        require(errorCode == 0);

        return AccountLimits({markets: lendtroller.getAssetsIn(account), liquidity: liquidity, shortfall: shortfall});
    }

    struct GovReceipt {
        uint256 proposalId;
        bool hasVoted;
        bool support;
        uint96 votes;
    }

    function getGovReceipts(GovernorAlpha governor, address voter, uint256[] memory proposalIds)
        public
        view
        returns (GovReceipt[] memory)
    {
        uint256 proposalCount = proposalIds.length;
        GovReceipt[] memory res = new GovReceipt[](proposalCount);
        for (uint256 i = 0; i < proposalCount; i++) {
            GovernorAlpha.Receipt memory receipt = governor.getReceipt(proposalIds[i], voter);
            res[i] = GovReceipt({
                proposalId: proposalIds[i],
                hasVoted: receipt.hasVoted,
                support: receipt.support,
                votes: receipt.votes
            });
        }
        return res;
    }

    struct GovBravoReceipt {
        uint256 proposalId;
        bool hasVoted;
        uint8 support;
        uint96 votes;
    }

    function getGovBravoReceipts(GovernorBravoInterface governor, address voter, uint256[] memory proposalIds)
        public
        view
        returns (GovBravoReceipt[] memory)
    {
        uint256 proposalCount = proposalIds.length;
        GovBravoReceipt[] memory res = new GovBravoReceipt[](proposalCount);
        for (uint256 i = 0; i < proposalCount; i++) {
            GovernorBravoInterface.Receipt memory receipt = governor.getReceipt(proposalIds[i], voter);
            res[i] = GovBravoReceipt({
                proposalId: proposalIds[i],
                hasVoted: receipt.hasVoted,
                support: receipt.support,
                votes: receipt.votes
            });
        }
        return res;
    }

    struct GovProposal {
        uint256 proposalId;
        address proposer;
        uint256 eta;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        bool canceled;
        bool executed;
    }

    function setProposal(GovProposal memory res, GovernorAlpha governor, uint256 proposalId) internal view {
        (
            ,
            address proposer,
            uint256 eta,
            uint256 startBlock,
            uint256 endBlock,
            uint256 forVotes,
            uint256 againstVotes,
            bool canceled,
            bool executed
        ) = governor.proposals(proposalId);
        res.proposalId = proposalId;
        res.proposer = proposer;
        res.eta = eta;
        res.startBlock = startBlock;
        res.endBlock = endBlock;
        res.forVotes = forVotes;
        res.againstVotes = againstVotes;
        res.canceled = canceled;
        res.executed = executed;
    }

    function getGovProposals(GovernorAlpha governor, uint256[] calldata proposalIds)
        external
        view
        returns (GovProposal[] memory)
    {
        GovProposal[] memory res = new GovProposal[](proposalIds.length);
        for (uint256 i = 0; i < proposalIds.length; i++) {
            (address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory calldatas) =
                governor.getActions(proposalIds[i]);
            res[i] = GovProposal({
                proposalId: 0,
                proposer: address(0),
                eta: 0,
                targets: targets,
                values: values,
                signatures: signatures,
                calldatas: calldatas,
                startBlock: 0,
                endBlock: 0,
                forVotes: 0,
                againstVotes: 0,
                canceled: false,
                executed: false
            });
            setProposal(res[i], governor, proposalIds[i]);
        }
        return res;
    }

    struct GovBravoProposal {
        uint256 proposalId;
        address proposer;
        uint256 eta;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool canceled;
        bool executed;
    }

    function setBravoProposal(GovBravoProposal memory res, GovernorBravoInterface governor, uint256 proposalId)
        internal
        view
    {
        GovernorBravoInterface.Proposal memory p = governor.proposals(proposalId);

        res.proposalId = proposalId;
        res.proposer = p.proposer;
        res.eta = p.eta;
        res.startBlock = p.startBlock;
        res.endBlock = p.endBlock;
        res.forVotes = p.forVotes;
        res.againstVotes = p.againstVotes;
        res.abstainVotes = p.abstainVotes;
        res.canceled = p.canceled;
        res.executed = p.executed;
    }

    function getGovBravoProposals(GovernorBravoInterface governor, uint256[] calldata proposalIds)
        external
        view
        returns (GovBravoProposal[] memory)
    {
        GovBravoProposal[] memory res = new GovBravoProposal[](proposalIds.length);
        for (uint256 i = 0; i < proposalIds.length; i++) {
            (address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory calldatas) =
                governor.getActions(proposalIds[i]);
            res[i] = GovBravoProposal({
                proposalId: 0,
                proposer: address(0),
                eta: 0,
                targets: targets,
                values: values,
                signatures: signatures,
                calldatas: calldatas,
                startBlock: 0,
                endBlock: 0,
                forVotes: 0,
                againstVotes: 0,
                abstainVotes: 0,
                canceled: false,
                executed: false
            });
            setBravoProposal(res[i], governor, proposalIds[i]);
        }
        return res;
    }

    struct CompBalanceMetadata {
        uint256 balance;
        uint256 votes;
        address delegate;
    }

    function getCompBalanceMetadata(Lend lend, address account) external view returns (CompBalanceMetadata memory) {
        return CompBalanceMetadata({
            balance: lend.balanceOf(account),
            votes: uint256(lend.getCurrentVotes(account)),
            delegate: lend.delegates(account)
        });
    }

    struct CompBalanceMetadataExt {
        uint256 balance;
        uint256 votes;
        address delegate;
        uint256 allocated;
    }

    function getCompBalanceMetadataExt(Lend lend, LendtrollerLensInterface lendtroller, address account)
        external
        returns (CompBalanceMetadataExt memory)
    {
        uint256 balance = lend.balanceOf(account);
        lendtroller.claimLend(account);
        uint256 newBalance = lend.balanceOf(account);
        uint256 accrued = lendtroller.lendAccrued(account);
        uint256 total = add(accrued, newBalance, "sum lend total");
        uint256 allocated = sub(total, balance, "sub allocated");

        return CompBalanceMetadataExt({
            balance: balance,
            votes: uint256(lend.getCurrentVotes(account)),
            delegate: lend.delegates(account),
            allocated: allocated
        });
    }

    struct CompVotes {
        uint256 blockNumber;
        uint256 votes;
    }

    function getCompVotes(Lend lend, address account, uint32[] calldata blockNumbers)
        external
        view
        returns (CompVotes[] memory)
    {
        CompVotes[] memory res = new CompVotes[](blockNumbers.length);
        for (uint256 i = 0; i < blockNumbers.length; i++) {
            res[i] = CompVotes({
                blockNumber: uint256(blockNumbers[i]),
                votes: uint256(lend.getPriorVotes(account, blockNumbers[i]))
            });
        }
        return res;
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function add(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, errorMessage);
        return c;
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }
}
