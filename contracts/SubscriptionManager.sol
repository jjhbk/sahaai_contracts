// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract SubscriptionManager is Ownable {
    enum Plan {
        Basic,
        Pro,
        Enterprise
    }

    uint256 public basicPrice;
    uint256 public proPrice;
    uint256 public enterprisePrice;
    uint256 public subscriptionDuration;

    struct Subscription {
        uint256 expiry; // Timestamp of subscription expiry
        Plan planId;
        bool active; // Subscription plan ID
    }

    mapping(address => Subscription) public activeSubscriptions; // Tracks active subscriptions for each user
    event FundsWithdrawn(address indexed owner, uint256 amount);
    event Subscribed(address indexed user, Plan plan, uint256 expiry);
    event PlanUpgraded(
        address indexed user,
        Plan oldPlan,
        Plan newPlan,
        uint256 expiry
    );
    event PlanDowngraded(
        address indexed user,
        Plan oldPlan,
        Plan newPlan,
        uint256 expiry
    );
    event Unsubscribed(address indexed user);
    event PriceUpdated(
        uint256 basicPrice,
        uint256 proPrice,
        uint256 enterprisePrice
    );

    constructor(
        uint256 _basicPrice,
        uint256 _proPrice,
        uint256 _enterprisePrice,
        uint256 _subscriptionDuration
    ) Ownable(msg.sender) {
        basicPrice = _basicPrice;
        proPrice = _proPrice;
        enterprisePrice = _enterprisePrice;
        subscriptionDuration = _subscriptionDuration;
    }

    modifier isSubscribed(address user) {
        require(
            activeSubscriptions[user].expiry > block.timestamp,
            "Err:sub-expired"
        );
        _;
    }

    function subscribe(Plan _plan) external payable {
        uint256 price = getPlanPrice(_plan);
        require(msg.value == price, "Err:Sub-fee");

        uint256 newExpiry = block.timestamp + subscriptionDuration;

        if (activeSubscriptions[msg.sender].expiry < block.timestamp) {
            activeSubscriptions[msg.sender].planId = _plan;
        } else {
            require(
                newExpiry > activeSubscriptions[msg.sender].expiry,
                "Err:Expiry overflow"
            );
        }

        activeSubscriptions[msg.sender].expiry = newExpiry;
        activeSubscriptions[msg.sender].active = true;
        emit Subscribed(msg.sender, _plan, newExpiry);
    }

    function upgradePlan(
        Plan _newPlan
    ) external payable isSubscribed(msg.sender) {
        Plan currentPlan = activeSubscriptions[msg.sender].planId;
        require(_newPlan > currentPlan, "Err: upgrade-onlyHigh");

        uint256 additionalCost = getPlanPrice(_newPlan) -
            getPlanPrice(currentPlan);
        require(msg.value == additionalCost, "Err:Upgrade-incorrect value");

        activeSubscriptions[msg.sender].planId = _newPlan;
        uint256 newExpiry = activeSubscriptions[msg.sender].expiry +
            subscriptionDuration;
        require(
            newExpiry > activeSubscriptions[msg.sender].expiry,
            "Err:Expiry overflow"
        );

        activeSubscriptions[msg.sender].expiry = newExpiry;
        activeSubscriptions[msg.sender].active = true;

        emit PlanUpgraded(
            msg.sender,
            currentPlan,
            _newPlan,
            activeSubscriptions[msg.sender].expiry
        );
    }

    function unsubscribe() external isSubscribed(msg.sender) {
        activeSubscriptions[msg.sender].active = false;
        emit Unsubscribed(msg.sender);
    }

    function getPlanPrice(Plan _plan) public view returns (uint256) {
        if (_plan == Plan.Basic) return basicPrice;
        if (_plan == Plan.Pro) return proPrice;
        if (_plan == Plan.Enterprise) return enterprisePrice;
        revert("Invalid plan");
    }

    function setPrices(
        uint256 _basicPrice,
        uint256 _proPrice,
        uint256 _enterprisePrice
    ) external onlyOwner {
        basicPrice = _basicPrice;
        proPrice = _proPrice;
        enterprisePrice = _enterprisePrice;
        emit PriceUpdated(_basicPrice, _proPrice, _enterprisePrice);
    }

    function setSubscriptionDuration(uint256 _duration) external onlyOwner {
        subscriptionDuration = _duration;
    }

    function issUserSubscribed(address user) external view returns (bool) {
        return activeSubscriptions[user].expiry > block.timestamp;
    }

    function withdrawFunds(uint256 amount) external onlyOwner {
        require(
            address(this).balance >= amount,
            "Insufficient contract balance"
        );
        payable(owner()).transfer(amount);
        emit FundsWithdrawn(owner(), amount);
    }
}
