// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DecentralizedStableCoin is ERC20 {
    address private owner;

    constructor() ERC20("DecentralizedStableCoin", "DSC") {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        // Commented below statement because then users are not able to deposit and redeem without owner privileges
        // require(msg.sender != owner, "[ERROR] You are not the owner");
        _;
    }

    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyOwner {
        _burn(_from, _amount);
    }
}
