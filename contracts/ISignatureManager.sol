// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISignatureManager {
    function verifySignature(
        address user,
        string memory message_hash,
        bytes memory signature
    ) external view returns (bool);

    function setAIAgent(address newAgent) external;
}
