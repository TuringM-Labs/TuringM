// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {LibDiamond} from "../diamond/LibDiamond.sol";
import "./AppStorageFacet.sol";

contract PermissionFacet is AppStorageFacet {
    function hasPermission(bytes32 permissionName, address userAddress) external view returns (bool isEnabled){
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        isEnabled = ds.permissionsMap[permissionName][userAddress];
    }

    function setPermission(bytes32 permissionName, address userAddress, bool isEnabled) external {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.permissionsMap[permissionName][userAddress] = isEnabled;
    }

    function checkIsPaused() external view returns (bool isPaused) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.isPaused;
    }

    function setPaused(bool isPaused) external {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setPaused(isPaused);
    }
}
