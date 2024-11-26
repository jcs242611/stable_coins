// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "./DecentralisedStableCoin.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract DSCEngine {
    struct AccountInfo {
        uint256 totalCollateralUSD;
        uint256 mintedStableCoin;
    }

    DecentralizedStableCoin private stableCoin;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant USD_DECIMALS = 1e18;

    address[] private acceptedCollateralTokens;
    mapping(address => AggregatorV3Interface) private priceFeeds;
    mapping(address => mapping(address => uint256)) private collateralBalances;
    mapping(address => AccountInfo) private accountInfo;

    constructor(
        address _stableCoin,
        address[] memory _collateralTokens,
        address[] memory _priceFeedAddresses
    ) {
        require(
            _collateralTokens.length == _priceFeedAddresses.length,
            "Mismatched inputs"
        );
        stableCoin = DecentralizedStableCoin(_stableCoin);

        for (uint256 i = 0; i < _collateralTokens.length; i++) {
            acceptedCollateralTokens.push(_collateralTokens[i]);
            priceFeeds[_collateralTokens[i]] = AggregatorV3Interface(
                _priceFeedAddresses[i]
            );
        }
    }

    function depositCollateralAndMint(
        address _collateralToken,
        uint256 _collateralAmount,
        uint256 _stableCoinAmount
    ) external {
        require(
            isAcceptedCollateral(_collateralToken) == true,
            "[ERROR] Invalid collateral token"
        );
        require(
            _collateralAmount > 0 && _stableCoinAmount > 0,
            "[ERROR] Invalid amounts"
        );

        IERC20(_collateralToken).transferFrom(
            msg.sender,
            address(this),
            _collateralAmount
        );

        uint256 collateralValueInUSD = getCollateralValue(
            _collateralToken,
            _collateralAmount
        );
        uint256 newTotalCollateral = accountInfo[msg.sender]
            .totalCollateralUSD + collateralValueInUSD;
        uint256 newMintedStableCoin = accountInfo[msg.sender].mintedStableCoin +
            _stableCoinAmount;

        collateralBalances[msg.sender][_collateralToken] += _collateralAmount;
        require(
            calculateHealthFactor(msg.sender, newMintedStableCoin) >=
                MIN_HEALTH_FACTOR,
            "[WARNING] Health factor too low"
        );

        accountInfo[msg.sender].totalCollateralUSD = newTotalCollateral;
        accountInfo[msg.sender].mintedStableCoin = newMintedStableCoin;

        stableCoin.mint(msg.sender, _stableCoinAmount);
    }

    function redeemCollateralForStableCoin(
        address _collateralToken,
        uint256 _collateralAmount,
        uint256 _stableCoinAmount
    ) external {
        require(
            collateralBalances[msg.sender][_collateralToken] >=
                _collateralAmount,
            "[ERROR] Insufficient collateral amount"
        );
        require(
            accountInfo[msg.sender].mintedStableCoin >= _stableCoinAmount,
            "[ERROR] Insufficient stable coins"
        );

        uint256 collateralValueInUSD = getCollateralValue(
            _collateralToken,
            _collateralAmount
        );
        uint256 newTotalCollateral = accountInfo[msg.sender]
            .totalCollateralUSD - collateralValueInUSD;
        uint256 newMintedStableCoin = accountInfo[msg.sender].mintedStableCoin -
            _stableCoinAmount;

        require(
            calculateHealthFactor(msg.sender, newMintedStableCoin) >=
                MIN_HEALTH_FACTOR,
            "[WARNING] Health factor too low"
        );

        collateralBalances[msg.sender][_collateralToken] -= _collateralAmount;
        accountInfo[msg.sender].totalCollateralUSD = newTotalCollateral;
        accountInfo[msg.sender].mintedStableCoin = newMintedStableCoin;

        stableCoin.burn(msg.sender, _stableCoinAmount);
        IERC20(_collateralToken).transfer(msg.sender, _collateralAmount);
    }

    function liquidate(address _user) external {
        AccountInfo memory userAccountInfo = accountInfo[_user];
        require(
            calculateHealthFactor(_user, userAccountInfo.mintedStableCoin) <
                MIN_HEALTH_FACTOR,
            "[ERROR] Health factor sufficient"
        );

        uint256 stableCoinToBurn = userAccountInfo.mintedStableCoin;
        accountInfo[_user].mintedStableCoin = 0;
        accountInfo[_user].totalCollateralUSD = 0;

        for (uint256 i = 0; i < acceptedCollateralTokens.length; i++) {
            address token = acceptedCollateralTokens[i];
            uint256 collateralAmount = collateralBalances[_user][token];
            if (collateralAmount > 0) {
                collateralBalances[_user][token] = 0;
                IERC20(token).transfer(msg.sender, collateralAmount);
            }
        }

        stableCoin.burn(_user, stableCoinToBurn);
    }

    function isAcceptedCollateral(address token) private view returns (bool) {
        for (uint256 i = 0; i < acceptedCollateralTokens.length; i++)
            if (acceptedCollateralTokens[i] == token) return true;

        return false;
    }

    function calculateHealthFactor(
        address _user,
        uint256 _mintedStableCoin
    ) public view returns (uint256) {
        if (_mintedStableCoin == 0) return type(uint256).max;

        uint256 totalCollateralUSD = 0;
        for (uint256 i = 0; i < acceptedCollateralTokens.length; i++) {
            address token = acceptedCollateralTokens[i];
            totalCollateralUSD += getCollateralValue(
                token,
                collateralBalances[_user][token]
            );
        }

        return (totalCollateralUSD * USD_DECIMALS) / _mintedStableCoin;
    }

    function getCollateralValue(
        address _collateralToken,
        uint256 _collateralAmount
    ) public view returns (uint256) {
        (, int256 price, , , ) = priceFeeds[_collateralToken].latestRoundData();
        require(price > 0, "[ERROR] Invalid price");

        uint256 adjustedPrice = uint256(price) *
            10 ** (18 - priceFeeds[_collateralToken].decimals());
        return (_collateralAmount * adjustedPrice) / 1e18;
    }

    function getTokenAmountFromUSD(
        address _collateralToken,
        uint256 _USDAmount
    ) public view returns (uint256) {
        (, int256 price, , , ) = priceFeeds[_collateralToken].latestRoundData();
        require(price > 0, "[ERROR] Invalid price");
        uint256 adjustedPrice = uint256(price) *
            10 ** (18 - priceFeeds[_collateralToken].decimals());
        return (_USDAmount * 1e18) / adjustedPrice;
    }

    function getCollateralBalanceOfUser(
        address _user,
        address _collateralToken
    ) public view returns (uint256) {
        return collateralBalances[_user][_collateralToken];
    }

    function getAccountInformation(
        address _user
    ) public view returns (uint256, uint256) {
        return (
            accountInfo[_user].totalCollateralUSD,
            accountInfo[_user].mintedStableCoin
        );
    }

    function getMinHealthFactor() public pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getUSDDecimals() public pure returns (uint256) {
        return USD_DECIMALS;
    }
}
