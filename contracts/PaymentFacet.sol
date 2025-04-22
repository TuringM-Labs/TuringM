// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {LibDiamond} from "../diamond/LibDiamond.sol";
import "./AppStorageFacet.sol";
import "../diamond/facets/ERC20/Interface.sol";

contract PaymentFacet is AppStorageFacet {
    function isValidatePayment(address val) external view returns (bool) {
        return s.paymentAddressMap[val];
    }

    // Configure USDC or wrapped token addresses (fee calculation based on USDC standard)
    function setPayment(address val, bool isEnabled) external {
        LibDiamond.enforceIsContractOwner();
        s.paymentAddressMap[val] = isEnabled;
    }

    function setMaxSlippageBps(uint256 maxSlippageBps) external {
        LibDiamond.enforceIsContractOwner();
        s.maxSlippageBps = maxSlippageBps;
    }

    function getMaxSlippageBps() external view returns (uint256) {
        return s.maxSlippageBps;
    }
}
