// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AirdropCDFi is Ownable {
    using SafeERC20 for IERC20;

    bool private distributed;
    IERC20 private token;

    constructor(address _tokenAddress, address _owner) Ownable(_owner) {
        token = IERC20(_tokenAddress);
    }

    function distributeTokens(address[] memory recipients, uint256[] memory amounts) external onlyOwner {
        require(recipients.length == amounts.length, "Mismatched arrays");
        require(!distributed, "Distribution allowed only once!");
        distributed = true;
        
        for (uint256 i = 0; i < recipients.length; i++) {
            token.safeTransfer(recipients[i], amounts[i]);
        }
    }
}
