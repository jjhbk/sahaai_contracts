// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IAccessManager.sol";

contract TokenManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    mapping(address => uint256) public ethBalances;
    mapping(address => mapping(address => uint256)) public tokenBalances;
    mapping(address => address[]) private userTokenList;
    IAccessManager public accessManager;

    uint256 public platformFeePercent = 1;
    uint256 public maxTokenListSize = 50;
    address public authorizedSpender; // Authorized contract to spend on behalf of users
    address public feeRecipient;
    event DepositETH(address indexed user, uint256 amount);
    event DepositToken(
        address indexed user,
        address indexed token,
        uint256 amount
    );
    event WithdrawETH(address indexed user, uint256 amount);
    event WithdrawToken(
        address indexed user,
        address indexed token,
        uint256 amount
    );
    event SpenderAuthorized(address indexed newSpender);
    event PlatformConfigurationUpdated(
        uint256 oldFeePercent,
        uint256 newFeePercent,
        address oldRecipient,
        address newRecipient
    );
    modifier onlyAuthorizedSpender() {
        require(msg.sender == authorizedSpender, "Not authorized to spend");
        _;
    }

    constructor(
        address _feeRecipient,
        address accessManagerAddress
    ) Ownable(msg.sender) ReentrancyGuard() {
        require(
            _feeRecipient != address(0),
            "Fee recipient cannot be zero address"
        );
        feeRecipient = _feeRecipient;
        accessManager = IAccessManager(accessManagerAddress);
    }

    function authorizeSpender(address newSpender) external onlyOwner {
        require(newSpender != address(0), "Invalid spender address");
        authorizedSpender = newSpender;
        emit SpenderAuthorized(newSpender);
    }

    function depositETH(address user) external payable {
        ethBalances[user] += msg.value;
        emit DepositETH(user, msg.value);
    }

    function depositToken(
        address user,
        address token,
        uint256 amount
    ) external {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than zero");

        uint256 allowance = IERC20(token).allowance(user, address(this));
        require(allowance >= amount, "Insufficient token allowance");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        if (tokenBalances[msg.sender][token] == 0) {
            require(
                userTokenList[msg.sender].length < maxTokenListSize,
                "Token list limit reached"
            );
            userTokenList[msg.sender].push(token);
        }
        tokenBalances[msg.sender][token] += amount;

        emit DepositToken(msg.sender, token, amount);
    }

    function withdrawETH(
        address user,
        address recipient,
        uint256 amount
    ) external onlyAuthorizedSpender nonReentrant {
        uint256 fee = (amount * platformFeePercent) / 100;
        uint256 netAmount = amount - fee;
        require(user != address(0));
        require(recipient != address(0));
        require(ethBalances[user] >= amount, "Insufficient ETH balance");
        ethBalances[user] -= amount;
        payable(recipient).transfer(netAmount);
        ethBalances[feeRecipient] += fee;
        emit WithdrawETH(user, amount);
    }

    function withdrawToken(
        address user,
        address recipient,
        address token,
        uint256 amount
    ) external onlyAuthorizedSpender nonReentrant {
        require(token != address(0), "Invalid token address");
        require(user != address(0));
        require(recipient != address(0));
        uint256 fee = (amount * platformFeePercent) / 100;
        uint256 netAmount = amount - fee;
        require(
            tokenBalances[user][token] >= amount,
            "Insufficient token balance"
        );

        tokenBalances[user][token] -= amount;
        tokenBalances[feeRecipient][token] += fee;
        IERC20(token).safeTransfer(msg.sender, netAmount);
        emit WithdrawToken(user, token, amount);
    }

    function calculateFee(uint256 amount) external view returns (uint256) {
        return (amount * platformFeePercent) / 100;
    }

    function updatePlatformConfiguration(
        uint256 newFeePercent,
        address newRecipient
    ) external {
        require(
            msg.sender == accessManager.owner(),
            "Only owner can update configuration"
        );
        require(newFeePercent <= 100, "Fee percent cannot exceed 100");
        require(newRecipient != address(0), "Invalid recipient address");

        uint256 oldFeePercent = platformFeePercent;
        address oldRecipient = feeRecipient;

        platformFeePercent = newFeePercent;
        feeRecipient = newRecipient;

        emit PlatformConfigurationUpdated(
            oldFeePercent,
            newFeePercent,
            oldRecipient,
            newRecipient
        );
    }
}
