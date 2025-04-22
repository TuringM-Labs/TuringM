// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {LibDiamond} from "../diamond/LibDiamond.sol";
import "./AppStorageFacet.sol";

contract EIP712Facet is AppStorageFacet {
    function setEIP712Config(string memory name, string memory version) external {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setEIP712Config(name, version);
    }
}
