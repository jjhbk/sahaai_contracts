// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITokenManager {
    function depositETH() external payable;

    function depositToken(address token, uint256 amount) external;

    function withdrawETH(
        address user,
        address recipient,
        uint256 amount
    ) external;

    function withdrawToken(
        address user,
        address recipient,
        address token,
        uint256 amount
    ) external;

    function calculateFee(uint256 amount) external view returns (uint256);

    function updatePlatformFee(uint256 newFeePercent) external;

    function getUserTokenList(
        address user
    ) external view returns (address[] memory);

    function setMaxTokenListSize(uint256 newSize) external;

    // Add ethBalances function
    function ethBalances(address user) external view returns (uint256);

    // Add tokenBalances function
    function tokenBalances(
        address user,
        address token
    ) external view returns (uint256);

    // Add authorizeSpender function
    function authorizeSpender(address newSpender) external;
}
