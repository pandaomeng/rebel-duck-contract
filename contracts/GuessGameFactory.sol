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

    function createGame(address _tokenAddress, uint256 _startTime, uint256 _endTime) external onlyAdmin returns (address guessGameAddress) {
        address proxyAdmin = address(this);
        require(gameImplementation != address(0), "GuessGameFactory: Invalid GuessGame implementation");
        bytes memory proxyData;
        CustomTransparentUpgradeableProxy proxy = new CustomTransparentUpgradeableProxy(
            gameImplementation,
            proxyAdmin,
            proxyData
        );
        guessGameAddress = address(proxy);

        IGuessGame(guessGameAddress).initialize(address(this), _tokenAddress, _startTime, _endTime);

        guessGameAddresses.push(guessGameAddress);

        emit GuessGameCreated(_tokenAddress, guessGameAddress);
    }
}
