// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ISubscriptionManager.sol";
import "./ISignatureManager.sol";
import "./ITokenManager.sol";
import "./IAccessManager.sol";

contract AIAgentWalletWithSubscriptions is ERC721, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    ISubscriptionManager public subscriptionManager;
    ISignatureManager public signatureManager;
    ITokenManager public tokenManager;
    IAccessManager public accessManager;
    // If ratelimit needed for users
    //uint256 public cooldownPeriod = 1 hours;
    uint256 public mintFee = 0.0001 ether;
    uint256 private nextTokenId;
    uint256 private accumulatedFees;
    // Events for logging
    event SpendETH(
        address indexed user,
        address indexed recipient,
        uint256 amount
    );
    event SpendToken(
        address indexed user,
        address indexed token,
        address indexed recipient,
        uint256 amount
    );
    event FundsWithdrawn(address indexed owner, uint256 amount);

    mapping(address => uint256) private lastOperationTime;
    modifier onlyAIAgent() {
        require(msg.sender == accessManager.aiAgent(), "Only AI Agent allowed");
        _;
    }

    modifier whenNotPaused() {
        require(!accessManager.isPaused(), "Contract is paused");
        _;
    }

    //    modifier cooldown(address user) {
    //        require(
    //            block.timestamp >= lastOperationTime[user] + cooldownPeriod,
    //            "Operation on cooldown"
    //        );
    //        _;
    //        lastOperationTime[user] = block.timestamp;
    //    }

    constructor(
        string memory name,
        string memory symbol,
        address subscriptionManagerAddress,
        address signatureManagerAddress,
        address tokenManagerAddress,
        address accessManagerAddress
    ) ERC721(name, symbol) Ownable(msg.sender) {
        subscriptionManager = ISubscriptionManager(subscriptionManagerAddress);
        signatureManager = ISignatureManager(signatureManagerAddress);
        tokenManager = ITokenManager(tokenManagerAddress);
        accessManager = IAccessManager(accessManagerAddress);
    }

    // ====== Wallet Functionality ======

    function mintNFT(
        address recipient
    ) external payable onlyAIAgent nonReentrant {
        require(recipient != address(0), "Invalid recipient");
        require(msg.value == mintFee, "Incorrect mint fee");
        uint256 tokenId = nextTokenId++;
        _mint(recipient, tokenId);
        payable(address(this)).transfer(msg.value);
    }

    function spendETH(
        address user,
        address recipient,
        uint256 amount
    ) external onlyAIAgent whenNotPaused nonReentrant {
        require(
            tokenManager.ethBalances(user) >= amount,
            "Insufficient ETH balance"
        );
        // Deduct total amount and transfer
        tokenManager.withdrawETH(user, recipient, amount);

        emit SpendETH(user, recipient, amount);
    }

    function spendToken(
        address user,
        address token,
        address recipient,
        uint256 amount
    ) external onlyAIAgent whenNotPaused nonReentrant {
        require(
            tokenManager.tokenBalances(user, token) >= amount,
            "Insufficient token balance"
        );

        // Deduct total amount and transfer
        tokenManager.withdrawToken(user, recipient, token, amount);

        emit SpendToken(user, token, recipient, amount);
    }

    function emergencyWithdraw() external whenNotPaused nonReentrant {
        uint256 userEthBalance = tokenManager.ethBalances(msg.sender);
        if (userEthBalance > 0) {
            tokenManager.withdrawETH(msg.sender, msg.sender, userEthBalance);
        }

        address[] memory tokens = tokenManager.getUserTokenList(msg.sender);
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 tokenBalance = tokenManager.tokenBalances(
                msg.sender,
                tokens[i]
            );
            if (tokenBalance > 0) {
                tokenManager.withdrawToken(
                    msg.sender,
                    msg.sender,
                    tokens[i],
                    tokenBalance
                );
            }
        }
    }

    function executeTransaction(
        address user,
        address token,
        address recipient,
        uint256 amount,
        string memory message_hash,
        bytes memory signature
    ) external onlyAIAgent whenNotPaused nonReentrant {
        //cooldown(user)
        require(
            signatureManager.verifySignature(user, message_hash, signature),
            "Invalid signature"
        );

        if (token == address(0)) {
            require(
                tokenManager.ethBalances(user) >= amount,
                "Insufficient ETH balance"
            );
            tokenManager.withdrawETH(user, recipient, amount);
        } else {
            require(
                tokenManager.tokenBalances(user, token) >= amount,
                "Insufficient token balance"
            );
            tokenManager.withdrawToken(user, recipient, token, amount);
        }
    }

    function withdrawFunds(uint256 amount) external onlyOwner {
        require(
            address(this).balance >= amount,
            "Insufficient contract balance"
        );
        payable(owner()).transfer(amount);
        emit FundsWithdrawn(owner(), amount);
    }

    // ====== Admin Functions ======

    receive() external payable whenNotPaused {
        tokenManager.depositETH{value: msg.value}();
    }

    fallback() external payable {
        revert("Fallback not supported");
    }
}
