// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

interface IGuessGame {
    function initialize(address _factory, address _tokenAddress, uint256 _startTime, uint256 _interval, uint256 _interval_nums) external;

    // _number from 1 to 1000, maxAmount = 100000 * 1e18
    function chooseNumberAndStake(uint256 _number, uint256 _tokenAmount) external;

    function setIntervalWeight(uint256[] memory weights) external;

    function setFinalNumber() external;

    function setRewardForUsers(address[] memory users, uint256[] memory rewards) external;

    function withdraw(uint256 _number) external;


    // function raiseBet(uint256 _number, uint256 _tokenAmount) external;

    // function unstake(uint256 _number, uint256 _tokenAmount) external;
}
