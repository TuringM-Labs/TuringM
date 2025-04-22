// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract TuringCoin is ERC20, ERC20Permit {
    uint8 private constant _DECIMALS = 18;
    
    constructor() 
        ERC20("Turing Coin", "TuringCoin")
        ERC20Permit("Turing Coin")
    {
        _mint(msg.sender, 10 ** 9 * 10 ** uint256(_DECIMALS));
    }
    
    function decimals() public pure override returns (uint8) {
        return _DECIMALS;
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
}
