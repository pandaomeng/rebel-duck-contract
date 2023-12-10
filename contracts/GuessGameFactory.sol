// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./interfaces/IGuessGame.sol";
import "./interfaces/IGuessGameFactory.sol";
import "./libs/Adminable.sol";
import "./libs/CustomTransparentUpgradeableProxy.sol";

contract GuessGameFactory is IGuessGameFactory, Initializable, Adminable {
    address[] public guessGameAddresses;
    address public gameImplementation;

    event GuessGameImplementationUpdated(address implementation, address previousImplementation);
    event GuessGameCreated(address tokenAddress, address guessGameAddress);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin_) public initializer {
        _setAdmin(admin_);
    }

    function setImplementation(address impl_, bool upgradeDeployed_) external onlyAdmin {
        emit GuessGameImplementationUpdated(impl_, gameImplementation);
        gameImplementation = impl_;
        if (!upgradeDeployed_) {
            return;
        }
        for (uint256 i = 0; i < guessGameAddresses.length; i++) {
            CustomTransparentUpgradeableProxy(payable(guessGameAddresses[i])).upgradeTo(impl_);
        }
    }

    function createGame(address _tokenAddress, uint256 _startTime, uint256 _interval, uint256 _interval_nums) external onlyAdmin returns (address guessGameAddress) {
        address proxyAdmin = address(this);
        require(gameImplementation != address(0), "GuessGameFactory: Invalid GuessGame implementation");
        bytes memory proxyData;
        CustomTransparentUpgradeableProxy proxy = new CustomTransparentUpgradeableProxy(
            gameImplementation,
            proxyAdmin,
            proxyData
        );
        guessGameAddress = address(proxy);

        IGuessGame(guessGameAddress).initialize(address(this), _tokenAddress, _startTime, _interval, _interval_nums);

        guessGameAddresses.push(guessGameAddress);

        emit GuessGameCreated(_tokenAddress, guessGameAddress);
    }

    function setWeightsForGame(address _gameAddress, uint256[] memory weights) external onlyAdmin {
        IGuessGame(_gameAddress).setIntervalWeight(weights);
    }

    function withdrawToken(address _gameAddress, uint256 _amount) external onlyAdmin {
        IGuessGame(_gameAddress).withdraw(_amount);
    }

    function setFinalNumber(address _gameAddress) external onlyAdmin {
        IGuessGame(_gameAddress).setFinalNumber();
    }

    function setRewardForUsers(address _gameAddress, address[] memory users, uint256[] memory rewards) external onlyAdmin {
        IGuessGame(_gameAddress).setRewardForUsers(users, rewards);
    }
}
