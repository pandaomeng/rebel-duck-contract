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

    struct NumberUserShareInfo {
        uint256 number;
        address staker;
        uint256 share;
    }

    struct StakedNumberInfo {
        uint256 number;
        uint256 totalStakedShare;
        address[] stakers;
        NumberUserShareInfo[] stakerShareInfos;
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

    // user infos
    mapping(address => Operation[]) public userOperationHistory;
    // user => number => amount
    mapping(address => mapping(uint256 => uint256)) public userStakedAmountPerNumber;
    // user => number => share
    mapping(address => mapping(uint256 => uint256)) public userStakedSharePerNumber;
    // user => number[]
    mapping(address => uint256[]) public userChosenNumbers;

    // number => user => share
    mapping(uint256 => mapping(address => uint256)) numberUserShareMapping;
    // number => user[]
    mapping(uint256 => address[]) public numberUsers;

    // all infos
    // number => shares
    mapping(uint256 => uint256) public totalStakedSharePerNumber;
    // all staked numbers, number[]
    uint256[] public stakedNumbers;

    // 开奖号码 
    uint256 public AVERAGE_NUMBER;
    uint256 public FINAL_NUMBER;

    event ChooseAndStake(address staker, uint256 chosenNumber, uint256 amount, uint256 day, uint256 shares);
    event FinalNumberSet(uint256 finalNumber, uint256 averageNumber, uint256 random);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier onlyFactory() {
        require(msg.sender == address(factory), "GuessGame: UNAUTHORIZED");
        _;
    }

    // get stakedNumber info List in stakedNumbers
    function getStakedNumberInfos() public view returns (StakedNumberInfo[] memory) {
        uint256[] memory numbers = stakedNumbers;
        StakedNumberInfo[] memory infos = new StakedNumberInfo[](numbers.length);
        for (uint256 i = 0; i < numbers.length; i++) {
            uint256 number = numbers[i];

            // set NumberUserShareInfo for infos[i]
            NumberUserShareInfo[] memory shareInfos = new NumberUserShareInfo[](numberUsers[number].length);
            for (uint256 j = 0; j < numberUsers[number].length; j++) {
                address user = numberUsers[number][j];
                shareInfos[j] = NumberUserShareInfo({
                    number: number,
                    staker: user,
                    share: numberUserShareMapping[number][user]
                });
            }


            infos[i] = StakedNumberInfo({
                number: number,
                totalStakedShare: totalStakedSharePerNumber[number],
                stakers: numberUsers[number],
                stakerShareInfos: shareInfos
            });
        }
        return infos;
    }
    

    function getAverageNumber() public view returns (uint256) {
        uint256 day = (block.timestamp - START_TIME) / INTERVAL;
        // day should more than INTERVAL_NUMS
        require(day >= INTERVAL_NUMS, "GuessGame: NOT_IN_OPEN_TIME");

        uint256[] memory numbers = stakedNumbers;
        uint256 sharedSum = 0;
        uint256 weightedAccumulation = 0;
        for (uint256 i = 0; i < numbers.length; i++) {
            uint256 number = numbers[i];
            uint256 totalStakedShare = totalStakedSharePerNumber[number];
            sharedSum += totalStakedShare;
            weightedAccumulation += totalStakedShare * number;
        }
        uint256 averageNumber = weightedAccumulation / sharedSum;

        return averageNumber;
    }

    function generateRandomNumber() public view returns (uint256) {
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, blockhash(block.number - 1))));
        return seed % 201; // Modulo 201 to get a number in the range [0, 200]
    }

    function setFinalNumber() external onlyFactory {
        uint256 day = (block.timestamp - START_TIME) / INTERVAL;
        // day should more than INTERVAL_NUMS
        require(day >= INTERVAL_NUMS, "GuessGame: NOT_IN_OPEN_TIME");

        uint256[] memory numbers = stakedNumbers;
        uint256 sharedSum = 0;
        uint256 weightedAccumulation = 0;
        for (uint256 i = 0; i < numbers.length; i++) {
            uint256 number = numbers[i];
            uint256 totalStakedShare = totalStakedSharePerNumber[number];
            sharedSum += totalStakedShare;
            weightedAccumulation += totalStakedShare * number;
        }
        uint256 averageNumber = weightedAccumulation / sharedSum;
        AVERAGE_NUMBER = averageNumber;
        uint256 finalNumber = averageNumber;

        // final number is averageNumber add [0, 200]
        uint256 random = generateRandomNumber();
        if (finalNumber + random > 1100) {
            finalNumber = 1100;
        } else if (finalNumber + random < 101) {
            finalNumber = 101;
        } else {
            finalNumber += random;
        }
        finalNumber -= 100;
        FINAL_NUMBER = finalNumber;
        emit FinalNumberSet(finalNumber, averageNumber, random);
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
        require(block.timestamp >= START_TIME && block.timestamp <= END_TIME, "GuessGame: NOT_IN_STAKING_TIME");
        require(_number >= 1 && _number <= 1000, "GuessGame: INVALID_NUMBER");
        require(UNDERLYING_TOKEN.balanceOf(msg.sender) >= _tokenAmount, "GuessGame: INSUFFICIENT_BALANCE");

        require(userChosenNumbers[msg.sender].length < 3, "GuessGame: EXCEED_MAX_STAKED_NUMBER");

        if (userChosenNumbers[msg.sender].length == 3) {
            bool flag = false;
            for (uint256 i = 0; i < userChosenNumbers[msg.sender].length; i++) {
                if (userChosenNumbers[msg.sender][i] == _number) {
                    flag = true;
                    break;
                }
            }
            if (flag == false) {
                revert("GuessGame: EXCEED_MAX_STAKED_NUMBER");
            }
        }
        require(_tokenAmount + userStakedAmountPerNumber[msg.sender][_number] <= 100000 * 1e18, "GuessGame: EXCEED_MAX_STAKED_AMOUNT");

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

        if (numberUserShareMapping[_number][msg.sender] == 0) {
            numberUsers[_number].push(msg.sender);
        }
        numberUserShareMapping[_number][msg.sender] += shares;
        if (totalStakedSharePerNumber[_number] == 0) {
            stakedNumbers.push(_number);
        }
        totalStakedSharePerNumber[_number] += shares;
        emit ChooseAndStake(msg.sender, _number,  _tokenAmount, day, shares);
    }

    function withdraw(uint256 _number) external onlyFactory {
        require(block.timestamp > END_TIME, "GuessGame: NOT_IN_WITHDRAW_TIME");
        
        UNDERLYING_TOKEN.transfer(msg.sender, _number);
        REWARD_POOL -= _number;
    }

    function getUserOperationHistories(address _user) public view returns (Operation[] memory) {
        Operation[] memory operations = userOperationHistory[_user];

        return operations;
    }

    function getUserChosenNumber(address _user) public view returns (uint256[] memory) {
        return userChosenNumbers[_user];
    }
}
