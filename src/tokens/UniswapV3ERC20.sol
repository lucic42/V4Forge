// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract UniswapV3ERC20 is ERC20 {
    address public immutable creator;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply
    ) ERC20(_name, _symbol) {
        creator = msg.sender;
        _mint(msg.sender, _initialSupply);
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == creator, "Only creator can mint");
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
