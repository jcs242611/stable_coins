// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

contract DecentralizedStableCoin {
    address private owner;
    uint256 private totalSupply;
    mapping(address => uint256) private balances;

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        require(_to != address(0), "Mint to the zero address");

        totalSupply += _amount;
        balances[_to] += _amount;
    }

    function burn(address _from, uint256 _amount) public onlyOwner {
        require(_from != address(0), "Burn from the zero address");
        require(balances[_from] >= _amount, "Burn amount exceeds balance");

        balances[_from] -= _amount;
        totalSupply -= _amount;
    }
}
