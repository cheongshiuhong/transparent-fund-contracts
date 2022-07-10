// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockedWETH is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public payable {
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
    
    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }
}
