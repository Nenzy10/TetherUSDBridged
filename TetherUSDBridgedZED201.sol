// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// TELEGRAM CONTACT FOR ENQUIRIES: @NenzyBrown
// GITHUB USERNAME: @Nenzy10

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * @title TokenBridge
 * @dev A simple token bridge contract for locking and unlocking tokens across chains.
 */
contract TokenBridge {
    mapping(uint256 => uint256) public balanceOnThisChain;

    struct CrossChainBalanceInfo {
        address recipient;
        uint256 amount;
        bytes32 identifier;
    }

    event TokensLockedEvent(address indexed recipient, uint256 tokenID, uint256 amount);
    event TokensUnlockedEvent(address indexed recipient, uint256 tokenID);

    function lockTokensForCrossChain(
        uint256 _tokenID,
        address payable _senderAddress,
        CrossChainBalanceInfo calldata crossChainRecipient
    ) public {
        require(balanceOnThisChain[_tokenID] >= 0, "Invalid token ID");
        uint256 lockedAmount = _lockTokens(_senderAddress, crossChainRecipient.amount);
        if (lockedAmount > 0) {
            balanceOnThisChain[_tokenID] += lockedAmount;
            emit TokensLockedEvent(crossChainRecipient.recipient, _tokenID, lockedAmount);
        }
    }

    function unlockTokensForCrossChain(uint256 _tokenID, address payable senderAddress) public {
        require(balanceOnThisChain[_tokenID] >= 0, "Invalid token ID");
        emit TokensUnlockedEvent(senderAddress, _tokenID);
        uint256 unlockedAmount = unlockTokens(senderAddress, balanceOnThisChain[_tokenID]);
        if (unlockedAmount > 0) {
            balanceOnThisChain[_tokenID] -= unlockedAmount;
        }
    }
function _lockTokens(address payable senderAddress, uint256 amountToLock) internal returns (uint256) {
    return amountToLock;
}

function unlockTokens(address payable senderAddress, uint256 _amountUnlocked) internal returns (uint256) {
    return _amountUnlocked;
}

}

/**
 * @title Tether USD Bridged ZED20
 * @author @NenzyBrown
 * @notice This contract is a modified version of the ERC20 standard,
 *         allowing for cross-chain transfers, liquidity management, and governance.
 */
contract TetherUSDBridgedZED20 is ERC20, Ownable, ReentrancyGuard, Pausable, Initializable {
    using SafeERC20 for IERC20;

    // Address of the cross-chain bridge contract
    TokenBridge public bridgeContract;

    // Address of the liquidity pool
    address public liquidityPool;

    // Address of the deployer wallet
    address public deployerWallet;

    // Address of the stablecoin (e.g., USDC, DAI)
    address public stableToken;

    // Fee on liquidity removal (0.7%)
    uint256 public liquidityFeeOnRemove = 7;

    // Mapping of user liquidity
    mapping(address => uint256) public userLiquidity;

    // Governance variables
    struct Proposal {
        string description; // Description of the proposal
        uint256 voteCount; // Number of votes received
        mapping(address => bool) voters; // Track who has voted
        bool executed; // Whether the proposal has been executed
        address target; // Target address for governance actions
        bytes data; // Data for governance actions
    }

    // Array of proposals
    Proposal[] public proposals;

    // Staking variables
    mapping(address => uint256) public stakedAmount; // Amount staked by each user
    mapping(address => uint256) public rewards; // Rewards for each user
    uint256 public immutable rewardRate; // Reward rate per block (customizable)
    mapping(address => uint256) public lastRewardTimestamp; // Last reward timestamp for each user

    // Events
    event TokensLocked(address indexed user, uint256 amount, uint256 targetChainId);
    event TokensUnlocked(address indexed user, uint256 amount, uint256 sourceChainId);
    event LiquidityAdded(address indexed user, uint256 amount, address token);
    event LiquidityRemoved(address indexed user, uint256 amount, address token);
    event TokensPurchased(address indexed user, uint256 amountIn, uint256 amountOut);
    event BridgeContractUpdated(address indexed newBridgeContract);
    event LiquidityPoolUpdated(address indexed newLiquidityPool);
    event ProposalCreated(uint256 proposalId, string description);
    event Voted(uint256 proposalId, address indexed voter);
    event ProposalExecuted(uint256 proposalId);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardWithdrawn(address indexed user, uint256 amount);
    event ReceivedBNB(address indexed sender, uint256 amount);
    event DepositedERC20(address indexed sender, address indexed tokenAddress, uint256 amount);
    event WithdrawnERC20(address indexed sender, address indexed tokenAddress, uint256 amount);
    event WithdrawnBNB(address indexed sender, uint256 amount);
    event FallbackCalled(address indexed sender, uint256 amount);

    /**
     * @notice Constructor function to initialize the contract.
     * @param _stableToken Address of the stablecoin (e.g., USDC, DAI)
     * @param _deployerWallet Address of the deployer wallet
     * @param _rewardRate Reward rate per block
     * @param _bridgeContract Address of the TokenBridge contract
     */
    constructor(address _stableToken, address _deployerWallet, uint256 _rewardRate, address _bridgeContract)
    ERC20("Tether USD Bridged ZED20", "USDT.z") 
    Ownable(msg.sender) { // Pass the deployer's address to the Ownable constructor
    require(_stableToken != address(0), "Invalid stable token address");
    require(_deployerWallet != address(0), "Invalid deployer wallet address");
    require(_bridgeContract != address(0), "Invalid bridge contract address");

    stableToken = _stableToken;
    deployerWallet = _deployerWallet;
    rewardRate = _rewardRate;
    bridgeContract = TokenBridge(_bridgeContract);

    // Initial minting of 985 tokens with 63 total digits (45 zeros + 18 decimals)
    uint256 initialSupply = 985 * 1e60; // 985 followed by 60 zeros
    _mint(deployerWallet, (initialSupply * 70) / 100); // 70% to deployer wallet
    _mint(address(this), (initialSupply * 30) / 100); // 30% to the contract
}


    // Initialize function for upgradable contracts
    function initialize(address _stableToken, address _deployerWallet, address _bridgeContract) external initializer {
        require(_stableToken != address(0), "Invalid stable token address");
        require(_deployerWallet != address(0), "Invalid deployer wallet address");
        require(_bridgeContract != address(0), "Invalid bridge contract address");

        stableToken = _stableToken;
        deployerWallet = _deployerWallet;
        bridgeContract = TokenBridge(_bridgeContract);
    }

    /**
     * @notice Function to receive Ether (BNB).
     */
    receive() external payable {
        emit ReceivedBNB(msg.sender, msg.value);
    }

    /**
     * @notice Fallback function for unexpected transfers.
     */
    fallback() external payable {
        emit FallbackCalled(msg.sender, msg.value);
    }

    /**
     * @notice Function to deposit ERC20/BEP20 tokens into the contract.
     * @param tokenAddress Address of the token to deposit
     * @param amount Amount of tokens to deposit
     */
    function depositERC20(address tokenAddress, uint256 amount) external nonReentrant whenNotPaused {
        require(tokenAddress != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than zero");

        // Transfer tokens from the user to this contract
        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amount);

        emit DepositedERC20(msg.sender, tokenAddress, amount);
    }

    /**
     * @notice Function to withdraw ERC20/BEP20 tokens from the contract (Admin only).
     * @param tokenAddress Address of the token to withdraw
     * @param amount Amount of tokens to withdraw
     */
    function withdrawERC20(address tokenAddress, uint256 amount) external nonReentrant onlyOwner {
        require(tokenAddress != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than zero");

        // Transfer tokens from the contract to the owner
        IERC20(tokenAddress).safeTransfer(msg.sender, amount);

        emit WithdrawnERC20(msg.sender, tokenAddress, amount);
    }

    /**
     * @notice Function to withdraw BNB from the contract (Admin only).
     * @param amount Amount of BNB to withdraw
     */
    function withdrawBNB(uint256 amount) external nonReentrant onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        require(address(this).balance >= amount, "Insufficient BNB balance");

        // Transfer BNB to the owner
        payable(msg.sender).transfer(amount);

        emit WithdrawnBNB(msg.sender, amount);
    }

    /**
     * @notice Function to get the balance of a specific user.
     * @param user Address of the user
     * @return Balance of the user
     */
    function getBalance(address user) external view returns (uint256) {
        return balanceOf(user);
    }

    /**
     * @notice Function to get the total liquidity of a user.
     * @param user Address of the user
     * @return Total liquidity of the user
     */
    function getUserLiquidity(address user) external view returns (uint256) {

        return userLiquidity[user];
    }

    /**
     * @notice Function to set the cross-chain bridge contract address.
     * @param _bridgeContract Address of the cross-chain bridge contract
     * @dev Only the owner can set the bridge contract address.
     */
    function setBridgeContract(address _bridgeContract) external onlyOwner {
        require(_bridgeContract != address(0), "Invalid bridge contract address");
        bridgeContract = TokenBridge(_bridgeContract);
        emit BridgeContractUpdated(_bridgeContract);
    }

    /**
     * @notice Function to set the liquidity pool address.
     * @param _liquidityPool Address of the liquidity pool
     * @dev Only the owner can set the liquidity pool address.
     */
    function setLiquidityPool(address _liquidityPool) external onlyOwner {
        require(_liquidityPool != address(0), "Invalid liquidity pool address");
        liquidityPool = _liquidityPool;
        emit LiquidityPoolUpdated(_liquidityPool);
    }

    /**
     * @notice Function to lock tokens for cross-chain transfer.
     * @param _tokenID Token ID of the tokens being locked
     * @param amount Amount of tokens to lock
     * @param recipient Address of the recipient on the target chain
     */
    function lockTokensForCrossChain(uint256 _tokenID, uint256 amount, address recipient) external nonReentrant whenNotPaused {
        require(bridgeContract != TokenBridge(address(0)), "Bridge contract not set"); // Updated this line
        require(IERC20(stableToken).balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        // Transfer tokens to this contract
        IERC20(stableToken).safeTransferFrom(msg.sender, address(this), amount);
        
        // Prepare cross-chain recipient info
        TokenBridge.CrossChainBalanceInfo memory crossChainRecipient = TokenBridge.CrossChainBalanceInfo({
            recipient: recipient,
            amount: amount,
            identifier: keccak256(abi.encodePacked(msg.sender, amount, block.timestamp)) // Unique identifier
        });

        // Call the bridge contract to lock tokens
        bridgeContract.lockTokensForCrossChain(_tokenID, payable(msg.sender), crossChainRecipient);
        emit TokensLocked(msg.sender, amount, block.chainid);
    }

    /**
     * @notice Function to unlock tokens (Admin only).
     * @param _tokenID Token ID of the tokens being unlocked
     * @param amount Amount of tokens to unlock
     * @param recipient Address of the recipient
     * @dev Only the owner can unlock tokens.
     */
    function unlockTokens(uint256 _tokenID, uint256 amount, address recipient) external onlyOwner {
        require(recipient != address(0), "Invalid recipient address");
        require(amount > 0, "Amount must be greater than zero");
        
        // Call the bridge contract to unlock tokens
        bridgeContract.unlockTokensForCrossChain(_tokenID, payable(recipient));
        emit TokensUnlocked(recipient, amount, block.chainid);
    }

    /**
     * @notice Function to mint new tokens (Admin only).
     * @param to Address of the recipient
     * @param amount Amount of tokens to mint
     * @dev Only the owner can mint new tokens.
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
        emit Transfer(address(0), to, amount); // Emit Transfer event for minting
    }

    /**
     * @notice Function to burn tokens (Admin only).
     * @param amount Amount of tokens to burn
     * @dev Only the owner can burn tokens.
     */
    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
        emit Transfer(msg.sender, address(0), amount); // Emit Transfer event for burning
    }

    /**
     * @notice Function to add liquidity (Free of charge).
     * @param token Address of the token
     * @param amount Amount of tokens to add
     */
    function addLiquidity(address token, uint256 amount) external nonReentrant whenNotPaused {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than zero");
        require(liquidityPool != address(0), "Liquidity pool not set");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        userLiquidity[msg.sender] += amount;

        emit LiquidityAdded(msg.sender, amount, token);
    }

    /**
     * @notice Function to remove liquidity with a fee.
     * @param token Address of the token
     * @param amount Amount of tokens to remove
     */
    function removeLiquidity(address token, uint256 amount) external nonReentrant whenNotPaused {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than zero");
        require(userLiquidity[msg.sender] >= amount, "Insufficient liquidity");

        uint256 feeAmount = (amount * liquidityFeeOnRemove) / 1000; // 0.7% fee
        uint256 netAmount = amount - feeAmount;

        userLiquidity[msg.sender] -= amount;
        IERC20(token).safeTransfer(msg.sender, netAmount);

        // Transfer the fee to the deployer wallet
        IERC20(token).safeTransfer(deployerWallet, feeAmount);

        emit LiquidityRemoved(msg.sender, netAmount, token);
    }

    /**
     * @notice Function to purchase tokens at a 1:1 ratio with stablecoin.
     * @param amountIn Amount of stablecoin to purchase with
     */
    function purchaseTokens(uint256 amountIn) external nonReentrant whenNotPaused {
        require(amountIn > 0, "Amount must be greater than zero");
        require(IERC20(stableToken).balanceOf(msg.sender) >= amountIn, "Insufficient stablecoin balance");

        // Calculate the amount of tokens to mint (1:1 ratio)
        uint256 tokensToMint = amountIn;

        // Transfer stablecoin from user to contract
        IERC20(stableToken).safeTransferFrom(msg.sender, address(this), amountIn);

        // Mint new tokens to the user
        _mint(msg.sender, tokensToMint);

        emit TokensPurchased(msg.sender, amountIn, tokensToMint);
    }

    /**
     * @notice Function to stake tokens for rewards.
     * @param amount Amount of tokens to stake
     */
    function stakeTokens(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be greater than zero");
        _transfer(msg.sender, address(this), amount);
        stakedAmount[msg.sender] += amount;
        _distributeRewards(msg.sender); // Distribute rewards before updating staked amount
        lastRewardTimestamp[msg.sender] = block.timestamp;

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Function to unstake tokens.
     * @param amount Amount of tokens to unstake
     */
    function unstakeTokens(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be greater than zero");
        require(stakedAmount[msg.sender] >= amount, "Insufficient staked amount");

        _distributeRewards(msg.sender); // Distribute rewards before unstaking
        stakedAmount[msg.sender] -= amount;
        _transfer(address(this), msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    /**
     * @notice Internal function to calculate and distribute staking rewards.
     * @param user Address of the user
     */
    function _distributeRewards(address user) private {
        uint256 reward = (stakedAmount[user] * rewardRate * (block.timestamp - lastRewardTimestamp[user])) / 1e18;
        rewards[user] += reward;
        lastRewardTimestamp[user] = block.timestamp;
    }

    /**
     * @notice Function to withdraw rewards.
     */
    function withdrawRewards() external nonReentrant whenNotPaused {
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "No rewards to withdraw");

        rewards[msg.sender] = 0;
        _mint(msg.sender, reward); // Mint rewards to the user

        emit RewardWithdrawn(msg.sender, reward);
    }

    /**
     * @notice Function to create a new proposal for governance.
     * @param description Description of the proposal
     * @param target Target address for governance actions
     * @param data Data for governance actions
     * @dev Only the owner can create proposals.
     */
    function createProposal(string memory description, address target, bytes memory data) external onlyOwner {
        require(target != address(0), "Invalid target address");
        require(data.length > 0, "Invalid data");

        Proposal storage newProposal = proposals.push();
        newProposal.description = description;
        newProposal.voteCount = 0;
        newProposal.executed = false;
        newProposal.target = target;
        newProposal.data = data;

        emit ProposalCreated(proposals.length - 1, description);
    }

    /**
     * @notice Function to vote on a proposal.
     * @param proposalId ID of the proposal to vote on
     */
    function voteOnProposal(uint256 proposalId) external {
        require(proposalId < proposals.length, "Invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.voters[msg.sender], "You have already voted");

        // Voting power based on token balance
        uint256 votingPower = balanceOf(msg.sender);
        require(votingPower > 0, "No voting power");

        proposal.voters[msg.sender] = true;
        proposal.voteCount += votingPower;

        emit Voted(proposalId, msg.sender);
    }

    /**
     * @notice Function to execute a proposal.
     * @param proposalId ID of the proposal to execute
     * @dev Only the owner can execute proposals.
     */
    function executeProposal(uint256 proposalId) external onlyOwner {
        require(proposalId < proposals.length, "Invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(proposal.voteCount > (totalSupply() / 2), "Insufficient votes"); // Majority vote required

        // Validate target address and data
        require(proposal.target != address(0), "Invalid target address");
        require(proposal.data.length > 0, "Invalid data");

        (bool success, ) = proposal.target.call(proposal.data);
        require(success, "Proposal execution failed");

        proposal.executed = true;
        emit ProposalExecuted(proposalId);
    }
}