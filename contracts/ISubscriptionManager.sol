// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISubscriptionManager {
    function subscribe(address user, uint256 plan) external payable;

    function upgradePlan(address user, uint256 newPlan) external payable;

    function unsubscribe(address user) external;

    function getPlanPrice(uint256 plan) external view returns (uint256);
}
