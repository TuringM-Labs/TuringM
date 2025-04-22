// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {LibDiamond} from "../diamond/LibDiamond.sol";
import "./AppStorageFacet.sol";
import "../diamond/facets/ERC20/Interface.sol";

contract FeeTokenFacet is AppStorageFacet {
    event FeeTokenPayout(address indexed feeTokenAddress, address indexed to, uint256 amount, PayoutType payoutType, uint256 nonce);
    event FeeTokenUpdated(address indexed feeTokenAddress, uint256 feeTokenPriceUSDC, bool isEnabled);

    function getFeeTokenInfo(address val) external view returns (FeeTokenInfo memory) {
        return
            FeeTokenInfo({
                vaultAmount: s.feeVaultAmountMap[val],
                payoutAmount: s.feeVaultPayoutAmountMap[val],
                isEnabled: s.feeTokenAddressMap[val],
                priceUSDC: s.feeTokenPriceUSDCMap[val],
                shouldBurn: s.shouldBurnFeeTokenAddressMap[val],
                decimals: IERC20(val).decimals()
            });
    }

    function getFeeTokenPrice(address val) external view returns (uint256 priceUSDC) {
        return s.feeTokenPriceUSDCMap[val];
    }

    function setFeeToken(address val, uint256 feeTokenPriceUSDC, bool isEnabled) external {
        LibDiamond.enforceIsContractOwner();
        s.feeTokenAddressMap[val] = isEnabled;
        s.feeTokenPriceUSDCMap[val] = feeTokenPriceUSDC;
        emit  FeeTokenUpdated(val, feeTokenPriceUSDC, isEnabled);
    }

    function setShouldBurnFeeToken(address val, bool isEnabled) external {
        LibDiamond.enforceIsContractOwner();
        s.shouldBurnFeeTokenAddressMap[val] = isEnabled;
    }

    function setMaxFeeRateBps(uint256 val) external {
        LibDiamond.enforceIsContractOwner();
        s.maxFeeRateBps = val;
    }

    function getMaxFeeRateBps() external view returns (uint256 maxFeeRateBps) {
        return s.maxFeeRateBps;
    }

    function payout(address to, address feeTokenAddress, uint256 amount, PayoutType payoutType, uint256 nonce, bytes memory sig) external {
        LibDiamond.lock();
        LibDiamond.isNotPaused();
        LibDiamond.enforceHasPermission(PERMISSION_PAYOUT, msg.sender);

        require(s.feeTokenAddressMap[feeTokenAddress], "Fee token not enabled");
        require(amount > 0, "Amount must be greater than 0");

        require(s.feeVaultAmountMap[feeTokenAddress] >= (s.feeVaultPayoutAmountMap[feeTokenAddress] + amount), "Insufficient fee vault balance");
        s.feeVaultPayoutAmountMap[feeTokenAddress] += amount;

        bytes32 digest = LibDiamond.getDigest(keccak256(abi.encode(TYPEHASH_PAYOUT, to, feeTokenAddress, amount, payoutType, nonce)));
        address signer = LibDiamond.recoverSigner(digest, sig);
        if (to != signer) revert InvalidSignature(nonce, sig, to, signer);

        require(IERC20(feeTokenAddress).transfer(to, amount), "Transfer failed");
        emit FeeTokenPayout(feeTokenAddress, to, amount, payoutType, nonce); // Emit event for commission paid t

        LibDiamond.unLock();
    }
}