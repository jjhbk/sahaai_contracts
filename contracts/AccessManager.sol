// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract AccessManager is Ownable {
    address public aiAgent;
    bool private paused;

    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event AIAgentUpdated(address indexed oldAgent, address indexed newAgent);

    modifier onlyAIAgentOrOwner() {
        require(
            msg.sender == aiAgent || msg.sender == owner(),
            "Not authorized"
        );
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor(address _aiAgent) Ownable(msg.sender) {
        require(_aiAgent != address(0), "AI Agent address cannot be zero");
        aiAgent = _aiAgent;
    }

    function setAIAgent(address newAgent) external onlyOwner {
        require(newAgent != address(0), "Invalid AI Agent address");
        emit AIAgentUpdated(aiAgent, newAgent);
        aiAgent = newAgent;
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function isPaused() external view returns (bool) {
        return paused;
    }

    // Prevent fallback calls to the contract
    fallback() external payable {
        revert("Fallback not supported");
    }

    receive() external payable {
        revert("Direct payments not supported");
    }
}
