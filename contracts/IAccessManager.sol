// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAccessManager {
    function setAIAgent(address newAgent) external;

    function pause() external;

    function unpause() external;

    function isPaused() external view returns (bool);

    function aiAgent() external view returns (address);

    function owner() external view returns (address);
}
