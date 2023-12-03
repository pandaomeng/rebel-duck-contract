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

    address public TOKEN_ADDRESS;
    IERC20 public UNDERLYING_TOKEN;
    uint256 public START_TIME;
    uint256 public END_TIME;
    mapping(address => mapping(uint256 => uint256)) public userStakedTimePerNumber;
    mapping(address => mapping(uint256 => uint256)) public userStakedAmountPerNumber;
    mapping(address => uint256[]) public userChosenNumbers;
    

    event ChooseAndStake(address staker, uint256 chosenNumber, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier onlyFactory() {
        require(msg.sender == address(factory), "GuessGame: UNAUTHORIZED");
        _;
    }

    function initialize(address _factory, address _tokenAddress, uint256 _startTime, uint256 _endTime) public initializer {
        __ReentrancyGuard_init();
        factory = IGuessGameFactory(_factory);
        START_TIME = _startTime;
        END_TIME = _endTime;
        TOKEN_ADDRESS = _tokenAddress;
        UNDERLYING_TOKEN = IERC20(_tokenAddress);
    }

    // _number from 1 to 1000, maxAmount = 100000 * 1e18
    function chooseNumberAndStake(uint256 _number, uint256 _tokenAmount) public {
        require(_number > 0 && _number <= 1000, "GuessGame: INVALID_NUMBER");
        require(_tokenAmount > 0 && _tokenAmount <= 100000 * 1e18, "GuessGame: INVALID_TOKEN_AMOUNT");
        require(userStakedTimePerNumber[msg.sender][_number] == 0, "GuessGame: ALREADY_STAKED");
        // can only stake 3 numbers per address
        require(userChosenNumbers[msg.sender].length < 3, "GuessGame: EXCEED_MAX_STAKED_NUMBER");
        require(block.timestamp >= START_TIME && block.timestamp <= END_TIME, "GuessGame: NOT_IN_STAKING_TIME");
        UNDERLYING_TOKEN.transferFrom(msg.sender, address(this), _tokenAmount);
        userStakedTimePerNumber[msg.sender][_number] = block.timestamp;
        userStakedAmountPerNumber[msg.sender][_number] = _tokenAmount;
        userChosenNumbers[msg.sender].push(_number);
        emit ChooseAndStake(msg.sender, _number,  _tokenAmount);
    }

    // function raiseBet(uint256 _number, uint256 _tokenAmount) external;
}
