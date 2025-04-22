// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {LibDiamond} from "../diamond/LibDiamond.sol";
import "./AppStorageFacet.sol";
import "../diamond/facets/ERC20/Interface.sol";
import "../diamond/facets/ERC1155/StorageFacet.sol";
import "hardhat/console.sol";

contract MatchOrderSelfFacet is AppStorageFacet, ERC1155StorageFacet {
    function matchOrderSelf(OrderSelf memory order) external {
        LibDiamond.lock();
        LibDiamond.isNotPaused();
        LibDiamond.enforceHasPermission(PERMISSION_MATCH_ORDERS, msg.sender);

        // Ensure market is not ended or blocked
        if (s.marketIsEndedMap[order.marketId] || s.marketIsBlockedMap[order.marketId]) revert MarketIsEndedOrBlocked(order.marketId, order.salt);
        if (s.marketIdMap[order.marketId].length == 0) revert MarketIdNotExist(order.marketId, order.salt);
        uint256 nftId1 = s.marketIdMap[order.marketId][0];
        uint256 nftId2 = s.marketIdMap[order.marketId][1];

        bytes32 digest = LibDiamond.getDigest(
            keccak256(
                abi.encode(
                    TYPEHASH_ORDER_SELF,
                    order.salt,
                    order.maker,
                    order.marketId,
                    order.tradeType,
                    order.paymentTokenAmount,
                    order.paymentTokenAddress,
                    order.deadline,
                    order.feeTokenAddress
                )
            )
        );
        // Order already filled or cancelled
        if (s.orderIsFilledOrCancelledMap[digest]) revert OrderFilledOrCancelled(order.salt);
        s.orderIsFilledOrCancelledMap[digest] = true;

        // Validate signature
        address signer = LibDiamond.recoverSigner(digest, order.sig);
        if (order.maker != signer) revert InvalidSignature(order.salt, order.sig, order.maker, signer);

        // Check if payment token is allowed
        if (s.paymentAddressMap[order.paymentTokenAddress] == false) {
            revert InvalidPaymentToken(order.salt, order.paymentTokenAddress);
        }
        if (order.tradeType == 0) {
            // Split order: maker pays USDC
            bool paymentResult = IERC20(order.paymentTokenAddress).transferFrom(order.maker, address(this), order.paymentTokenAmount);
            if (!paymentResult)
                revert PaymentTransferFailed(order.salt, order.maker, address(this), order.paymentTokenAddress, order.paymentTokenAmount);

            _chargeAllFee(order);
            // Split order: mint two types of NFTs to maker
            _mint(order.maker, nftId1, order.paymentTokenAmount, "");
            _mint(order.maker, nftId2, order.paymentTokenAmount, "");
            s.marketVaultMap[order.marketId][order.paymentTokenAddress] += order.paymentTokenAmount;
        } else if (order.tradeType == 1) {
            // Merge order: burn maker's two NFTs
            _burn(order.maker, nftId1, order.paymentTokenAmount);
            _burn(order.maker, nftId2, order.paymentTokenAmount);

            // Merge order: transfer USDC from market vault to maker
            bool paymentResult = IERC20(order.paymentTokenAddress).transfer(order.maker, order.paymentTokenAmount);
            if (!paymentResult)
                revert PaymentTransferFailed(order.salt, order.maker, address(this), order.paymentTokenAddress, order.paymentTokenAmount);

            uint256 currentBalance = s.marketVaultMap[order.marketId][order.paymentTokenAddress];
            if (currentBalance < order.paymentTokenAmount) {
                revert MarketVaultBalanceInsufficient(currentBalance, order.paymentTokenAmount);
            }
            s.marketVaultMap[order.marketId][order.paymentTokenAddress] -= order.paymentTokenAmount;
        }

        LibDiamond.unLock();
    }

    function _chargeAllFee(OrderSelf memory order) private {
        uint256 totalFee = 0;
        totalFee += _chargeFee(order.salt, order.maker, order.fee1TokenAddress, order.fee1Amount);
        totalFee += _chargeFee(order.salt, order.maker, order.fee2TokenAddress, order.fee2Amount);
        // Check if total fee exceeds maximum allowed
        if (totalFee > (order.paymentTokenAmount * s.maxFeeRateBps) / 10000)
            revert MaxFeeExceeded(order.salt, order.paymentTokenAmount, s.maxFeeRateBps, totalFee);
    }

    function _chargeFee(uint256 orderSalt, address from, address feeTokenAddress, uint256 feeAmount) private returns (uint256 feeAmountUSDC) {
        if (feeTokenAddress == address(0) || feeAmount == 0) return 0;

        if (s.feeTokenAddressMap[feeTokenAddress] == false) revert InvalidFeeToken(orderSalt, feeTokenAddress);
        bool success = IERC20(feeTokenAddress).transferFrom(from, address(this), feeAmount);
        if (!success) revert ChargeFeeFailed(orderSalt, feeTokenAddress, feeAmount);

        s.feeVaultAmountMap[feeTokenAddress] += feeAmount;
        if (s.shouldBurnFeeTokenAddressMap[feeTokenAddress]) {
            IERC20Burn(feeTokenAddress).burn(feeAmount);
        }

        uint256 decimals = 10 ** IERC20(feeTokenAddress).decimals();
        return (s.feeTokenPriceUSDCMap[feeTokenAddress] * feeAmount) / decimals;
    }
}
