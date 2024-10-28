// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RewardToken is ERC20 {

    constructor() ERC20("RewardToken", "RT") {}

    // TODO: Define tokenBatch struct that stores token amount and expiry date

    // TODO: store balances of each user as mapping address -> tokenBatch

    // TODO: modifier to burn tokens using _burn function
    // should loop the user's tokenBatch and burn the tokens that have expired
    // this modifier should be called before any transfer or view balance functions

    // TODO: Override transfer method to restrict transfer of tokens b/w customers

}