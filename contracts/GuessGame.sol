// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./interfaces/IGuessGame.sol";
import "./interfaces/IGuessGameFactory.sol";

contract GuessGame is Initializable, ReentrancyGuardUpgradeable, IGuessGame {
    using Strings for uint256;

    IGuessGameFactory public factory;

    struct Operation {
        uint256 number;
        uint256 timestamp;
        uint256 amount;
        uint256 shares;
        uint256 day;
    }

    address public TOKEN_ADDRESS;
    IERC20 public UNDERLYING_TOKEN;
    uint256 public START_TIME;
    uint256 public END_TIME;
    uint256 public INTERVAL;
    uint256 public INTERVAL_NUMS;
    uint256 public TOTAL_SHARE;
    uint256[] public INTERVAL_WEIGHTS;
    uint256 public REWARD_POOL;
    // uint256 public 
    mapping(address => Operation[]) public userOperationHistory;
    mapping(address => mapping(uint256 => uint256)) public userStakedAmountPerNumber;
    mapping(address => mapping(uint256 => uint256)) public userStakedSharePerNumber;
    mapping(address => uint256[]) public userChosenNumbers;
    

    event ChooseAndStake(address staker, uint256 chosenNumber, uint256 amount, uint256 day, uint256 shares);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier onlyFactory() {
        require(msg.sender == address(factory), "GuessGame: UNAUTHORIZED");
        _;
    }

    function setIntervalWeight(uint256[] memory weights) external onlyFactory {
        require(weights.length == INTERVAL_NUMS, "GuessGame: INVALID_WEIGHTS_LENGTH");
        INTERVAL_WEIGHTS = weights;
    }

    function initialize(address _factory, address _tokenAddress, uint256 _startTime, uint256 _interval, uint256 _interval_nums) public initializer {
        __ReentrancyGuard_init();
        factory = IGuessGameFactory(_factory);
        START_TIME = _startTime;
        END_TIME = _startTime + _interval * _interval_nums;
        INTERVAL = _interval;
        INTERVAL_NUMS = _interval_nums;
        TOKEN_ADDRESS = _tokenAddress;
        UNDERLYING_TOKEN = IERC20(_tokenAddress);
        INTERVAL_WEIGHTS = [100];
    }

    // _number from 1 to 1000, maxAmount = 100000 * 1e18
    function chooseNumberAndStake(uint256 _number, uint256 _tokenAmount) public {
        require(INTERVAL_WEIGHTS.length == INTERVAL_NUMS, "GuessGame: please set interval weights first");
        require(_tokenAmount > 0 && _tokenAmount <= 100000 * 1e18, "GuessGame: INVALID_TOKEN_AMOUNT");
        require(userChosenNumbers[msg.sender].length < 3, "GuessGame: EXCEED_MAX_STAKED_NUMBER");
        require(block.timestamp >= START_TIME && block.timestamp <= END_TIME, "GuessGame: NOT_IN_STAKING_TIME");
        require(_number >= 1 && _number <= 1000, "GuessGame: INVALID_NUMBER");
        require(UNDERLYING_TOKEN.balanceOf(msg.sender) >= _tokenAmount, "GuessGame: INSUFFICIENT_BALANCE");

        UNDERLYING_TOKEN.transferFrom(msg.sender, address(this), _tokenAmount);
        uint256 day = (block.timestamp - START_TIME) / INTERVAL;
        uint256 shares = _tokenAmount * INTERVAL_WEIGHTS[day];
        TOTAL_SHARE += shares;
        REWARD_POOL += _tokenAmount;
        userOperationHistory[msg.sender].push(Operation({
            number: _number,
            timestamp: block.timestamp,
            amount: _tokenAmount,
            shares: shares,
            day: day
        }));
        userStakedAmountPerNumber[msg.sender][_number] += _tokenAmount;
        userStakedSharePerNumber[msg.sender][_number] += shares;
        userChosenNumbers[msg.sender].push(_number);
        emit ChooseAndStake(msg.sender, _number,  _tokenAmount, day, shares);
    }

    function withdraw(uint256 _number) external onlyFactory {
        require(block.timestamp > END_TIME, "GuessGame: NOT_IN_WITHDRAW_TIME");
        
        UNDERLYING_TOKEN.transfer(msg.sender, _number);
        REWARD_POOL -= _number;
    }
}
