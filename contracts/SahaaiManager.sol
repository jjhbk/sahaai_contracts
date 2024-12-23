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

contract SahaaiManager is ERC721, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    mapping(uint256 => string) public tokenURIs;
    mapping(string => address) public identifiersToAddresses;
    mapping(address => string) public addressesToIdentifiers;
    mapping(string => address) public identifiersToToken;
    mapping(address => string) public tokenToIdentifiers;

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
    event NFTMinted(address indexed user, uint256 tokenId, string tokenURI);
    event IdentifierRegistered(address indexed user, string identifier);
    event TokenIdentifierRegistered(address indexed token, string identifier);

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
        address recipient,
        string memory uri
    ) external payable onlyAIAgent nonReentrant {
        require(recipient != address(0), "Invalid recipient");
        require(tokenManager.ethBalances(recipient) >= mintFee, "Err:Mint");
        _mint(recipient, nextTokenId);
        tokenURIs[nextTokenId] = uri;
        emit NFTMinted(recipient, nextTokenId, uri);
        nextTokenId++;
        tokenManager.withdrawETH(recipient, accessManager.aiAgent(), mintFee);
    }

    //query tokenURI
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(ownerOf(tokenId) != address(0), "Err:tokenURI");
        return tokenURIs[tokenId];
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
            require(tokenManager.ethBalances(user) >= amount, "Err:exec-eth");
            tokenManager.withdrawETH(user, recipient, amount);
        } else {
            require(
                tokenManager.tokenBalances(user, token) >= amount,
                "Err:exec-token"
            );
            tokenManager.withdrawToken(user, recipient, token, amount);
        }
    }

    // Register Identifier
    function registerIdentifier(string memory identifier) external {
        string memory _identifier = toLower(identifier);
        require(isIdentifierAvailable(_identifier), "Err:Id in use");
        identifiersToAddresses[toLower(_identifier)] = msg.sender;
        addressesToIdentifiers[msg.sender] = _identifier;
        emit IdentifierRegistered(msg.sender, _identifier);
    }

    // Check if Identifier is Available
    function isIdentifierAvailable(
        string memory identifier
    ) public view returns (bool) {
        return identifiersToAddresses[toLower(identifier)] == address(0);
    }

    function isTokenIdentifierAvailable(
        string memory name
    ) public view returns (bool) {
        return identifiersToToken[toLower(name)] == address(0);
    }

    function registerTokenIdentifier(
        string memory name,
        address token
    ) external onlyAIAgent {
        string memory _name = toLower(name);
        require(isTokenIdentifierAvailable(_name), "Err:Id unavail");
        require(
            keccak256(abi.encodePacked(tokenToIdentifiers[token])) ==
                keccak256(abi.encodePacked("")),
            "Err:duplicate-id"
        );
        tokenToIdentifiers[token] = _name;
        identifiersToToken[_name] = token;
        emit IdentifierRegistered(token, name);
    }

    //convert to lowercase

    function toLower(string memory str) public pure returns (string memory) {
        bytes memory bStr = bytes(str);
        for (uint256 i = 0; i < bStr.length; i++) {
            if (bStr[i] >= 0x41 && bStr[i] <= 0x5A) {
                // Convert uppercase A-Z to lowercase a-z
                bStr[i] = bytes1(uint8(bStr[i]) + 32);
            }
        }
        return string(bStr);
    }

    // ====== Admin Functions ======
    function withdrawFunds(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Err:Contract-eth");
        payable(owner()).transfer(amount);
        emit FundsWithdrawn(owner(), amount);
    }

    function DepositETH() external payable {}

    receive() external payable whenNotPaused {
        tokenManager.depositETH{value: msg.value}();
    }

    fallback() external payable {
        revert("Fallback not supported");
    }
}
