// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {LibDiamond} from "../diamond/LibDiamond.sol";
import "./AppStorageFacet.sol";
import "../diamond/facets/ERC20/Interface.sol";
import "../diamond/facets/ERC1155/StorageFacet.sol";

contract MarketManagerFacet is AppStorageFacet, ERC1155StorageFacet {
    event MarketCreated(uint256 indexed marketId, uint256 nftId1, uint256 nftId2);
    event MarketEnded(uint256 indexed marketId, uint256 winNftId);
    event MarketFinalized(uint256 indexed marketId, uint256 winNftId);
    event MarketBlocked(uint256 indexed marketId, bool isBlocked);
    event RewardClaimed(
        uint256 indexed marketId,
        uint256 nftId,
        address indexed user,
        address paymentTokenAddress,
        uint256 amount,
        uint256 paymentTokenFeeAmount
    );

    function claimReward(Reward memory reward) external {
        uint256 marketId = reward.marketId;
        uint256 nftId = reward.nftId;
        address user = reward.user;
        address paymentTokenAddress = reward.paymentTokenAddress;

        _requireNonZero(user);
        LibDiamond.lock();
        LibDiamond.isNotPaused();
        LibDiamond.enforceHasPermission(PERMISSION_CLAIM_REWARD, msg.sender);

        if (s.rewardClaimedNonceMap[reward.nonce]) revert NonceAlreadyUsed(reward.nonce);
        s.rewardClaimedNonceMap[reward.nonce] = true;
        if (!s.marketIsEndedMap[marketId] || !s.marketIsFinallizedMap[marketId]) revert MarketNotFinallized(marketId);
        if (nftId == 0 || s.marketWinNftIdMap[marketId] != nftId) revert NotWinningNft(marketId, nftId);
        // is user already claimed?
        if (s.claimedUserMapByMarketId[marketId][user]) revert RewardAlreadyClaimed(marketId, user);
        s.claimedUserMapByMarketId[marketId][user] = true;

        // Verify NFT ownership
        ERC1155FacetStorage storage _ds = erc1155Storage();
        uint256 amount = _ds._balances[nftId][user];
        if (amount == 0) revert NoNftOwned(nftId, user);

        // Check market vault balance
        if (s.marketWinnerPayAmountMap[marketId][paymentTokenAddress] > s.marketVaultMap[marketId][paymentTokenAddress])
            revert MarketVaultNotEnoughForPayReward(
                marketId,
                s.marketVaultMap[marketId][paymentTokenAddress],
                s.marketWinnerPayAmountMap[marketId][paymentTokenAddress],
                user,
                paymentTokenAddress
            );

        if (reward.feeAmount > (amount * s.maxFeeRateBps) / 10000)
            revert MaxFeeExceeded(reward.nonce, amount, reward.feeAmount, s.maxFeeRateBps);

        s.feeVaultAmountMap[paymentTokenAddress] += reward.feeAmount;
        bool paymentResult = IERC20(paymentTokenAddress).transfer(user, amount - reward.feeAmount);
        if (!paymentResult) revert RewardTransferFailed(reward, paymentTokenAddress, amount, reward.feeAmount);

        emit RewardClaimed(marketId, nftId, user, paymentTokenAddress, amount, reward.feeAmount);

        LibDiamond.unLock();
    }

    function toggleMarketBlocked(uint256 marketId, bool isBlocked) external {
        LibDiamond.lock();
        LibDiamond.isNotPaused();
        LibDiamond.enforceHasPermission(PERMISSION_BLOCK_MARKET, msg.sender);
        s.marketIsBlockedMap[marketId] = isBlocked;
        // Emit event to track market blocking timestamp
        emit MarketBlocked(marketId, isBlocked);
        LibDiamond.unLock();
    }

    function endMarket(uint256 marketId, uint256 winNftId) external {
        LibDiamond.lock();
        LibDiamond.isNotPaused();
        LibDiamond.enforceHasPermission(PERMISSION_END_MARKET, msg.sender);
        s.marketIsEndedMap[marketId] = true;
        s.marketWinNftIdMap[marketId] = winNftId;
        // Emit event to record market closure time
        emit MarketEnded(marketId, winNftId);
        LibDiamond.unLock();
    }

    function finalizeMarket(uint256 marketId, uint256 winNftId) external {
        if (s.marketIsFinallizedMap[marketId]) revert MarketAlreadyFinallized(marketId);
        LibDiamond.lock();
        LibDiamond.isNotPaused();
        LibDiamond.enforceHasPermission(PERMISSION_FINALIZE_MARKET, msg.sender);
        s.marketIsFinallizedMap[marketId] = true;
        s.marketWinNftIdMap[marketId] = winNftId;
        emit MarketFinalized(marketId, winNftId);
        LibDiamond.unLock();
    }

    function createMarket(uint256 marketId) external returns (uint256 nftId1, uint256 nftId2) {
        LibDiamond.lock();
        LibDiamond.isNotPaused();
        LibDiamond.enforceHasPermission(PERMISSION_CREATE_MARKET, msg.sender);

        if (s.marketIdMap[marketId].length != 0) revert MarketAlreadyExists();

        ERC1155FacetStorage storage _erc1155Storage = erc1155Storage();
        if (_erc1155Storage._idx >= MAX_ID) revert MaxMarketReached();

        nftId1 = ++_erc1155Storage._idx;
        nftId2 = ++_erc1155Storage._idx;
        s.marketIdMap[marketId] = [nftId1, nftId2];

        s.nftIdMapToMarketId[nftId1] = marketId;
        s.nftIdMapToMarketId[nftId2] = marketId;

        // enable market
        s.marketIsEndedMap[marketId] = false;

        emit MarketCreated(marketId, nftId1, nftId2);
        LibDiamond.unLock();
    }

    function getMarketInfo(uint256 marketId, address paymentTokenAddress) external view returns (MarketInfo memory) {
        return
            MarketInfo({
                marketId: marketId,
                nftId1: s.marketIdMap[marketId][0],
                nftId2: s.marketIdMap[marketId][1],
                vaultAmount: s.marketVaultMap[marketId][paymentTokenAddress],
                marketWinnerPayAmount: s.marketWinnerPayAmountMap[marketId][paymentTokenAddress],
                isEnded: s.marketIsEndedMap[marketId],
                isBlocked: s.marketIsBlockedMap[marketId],
                isFinallized: s.marketIsFinallizedMap[marketId],
                winNftId: s.marketWinNftIdMap[marketId]
            });
    }
}
