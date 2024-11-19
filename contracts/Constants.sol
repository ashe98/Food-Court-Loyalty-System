// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ConstantsContract {
    mapping(string => uint256) private integerConstants;

    constructor() {
        integerConstants["TOKEN_EXPIRY_MONTHS"] = 6;
        integerConstants["TOKEN_BONUS_TXN_COUNT"] = 20;
        integerConstants["TOKEN_BONUS_TOKEN_AMOUNT"] = 20;
        integerConstants["PEAK_HR_TOKENS"] = 5;
        integerConstants["NON_PEAK_HR_TOKENS"] = 10;
        integerConstants["PEAK_HR_START_1"] = 12;
        integerConstants["PEAK_HR_END_1"] = 14;
        integerConstants["PEAK_HR_START_2"] = 18;
        integerConstants["PEAK_HR_END_2"] = 20;
        integerConstants["MIN_DAYS_LAST_TXN"] = 30;
        integerConstants["BRONZE_REQ_TOKENS"] = 100;
        integerConstants["SILVER_REQ_TOKENS"] = 250;
        integerConstants["GOLD_REQ_TOKENS"] = 500;
        integerConstants["BRONZE_REQ_TXNS"] = 10;
        integerConstants["SILVER_REQ_TXNS"] = 20;
        integerConstants["GOLD_REQ_TXNS"] = 40;
    }

    function getIntegerConstant(
        string memory key
    ) public view returns (uint256) {
        return integerConstants[key];
    }
}
