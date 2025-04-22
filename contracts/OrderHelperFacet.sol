// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {LibDiamond} from "../diamond/LibDiamond.sol";
import "./AppStorageFacet.sol";
import "../diamond/facets/ERC20/Interface.sol";
import "../diamond/facets/ERC1155/StorageFacet.sol";

contract OrderHelperFacet is AppStorageFacet, ERC1155StorageFacet {
    function getRemainingAmount(Order memory order) external view returns (uint256)  {
        bytes32 digest = _hashOrder(order);
        return s.orderRemainingMap[digest];
    }

    function setMinimumOrderSalt(uint256 minimumOrderSalt_) external {
        LibDiamond.enforceIsContractOwner();
        s.minimumOrderSalt = minimumOrderSalt_;
    }

    function _hashOrder(Order memory order) private view returns (bytes32) {
        return
            LibDiamond.getDigest(
                keccak256(
                    abi.encode(
                        TYPEHASH_ORDER,
                        order.salt,
                        order.maker,
                        order.tokenId,
                        order.tokenAmount,
                        order.tokenPriceInPaymentToken,
                        order.paymentTokenAddress,
                        order.slippageBps,
                        order.deadline,
                        order.side,
                        order.feeTokenAddress
                    )
                )
            );
    }
}
