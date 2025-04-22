// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./AppStorage.sol";

contract AppStorageFacet {
    AppStorage internal s;

    function appStorage() internal pure returns (AppStorage storage ds){
      assembly {
        ds.slot := 0
      }
    }
}
