// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
/**
 * @title DSCEngine
 * @author George Karumbi
 * This system is designed to be as minimal as possible, and have the tokens a 1:1 peg to the USD
 * This stablecoint has the properties:
 * -Exogenous Collateral
 * -Dollar Pegged
 * -Algorithmically Stable
 *
 * Our DSC system should always be "overcollateralized". At no poiint, should the value of all collateral <= the $ backed-value of all the DSC
 *
 * It is similar to DAT if DAI has no governaence, no fees and was only backed by wETH and wBTC.
 * @notice This contract is the core of the DSC System. It handles all the logic for the minting and redeeming DSC, as well as depositing & withdrawing collateral.
 *  @notice This contract is VERY loosly based on the MakerDAO DSS(DAI) system.
 */

contract DSCEngine is ReentrancyGuard {
    //////////////////////Errors/////////////////////

    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__NotAllowToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorOk();

    ///////////////////////State Variables////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // Needs to be 200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10;// means 10% bonus

    mapping(address token => address priceFeed) private s_priceFeeds; //allowedtokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    address[] private s_collateralTokens;
    DecentralizedStableCoin private immutable i_dsc;

    ///////////////////Events ///////////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed user, address indexed token, uint256 indexed amount);
    ///////////////////////Modifiers////////////////

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowToken();
        }
        _;
    }

    ///////////////Functions////////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        //USD price Feeds
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_dsc = DecentralizedStableCoin(dscAddress);

        //console.log("i_dsc " + i_dsc);

        //For example ETH/USD, BTC/USD, MKR/USD etc
    }

    //////////////External Functions/////////
    /**
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     * @param amountDscToMint The amount of DecentralizedStableCoin to min
     * @notice this function will deposityour collateral and mintDSC in one transaction  
     */

    function depositCollateralAndMintDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToMint) external {
        depositCollateral(tokenCollateralAddress,amountCollateral);
        mintDsc(amountDscToMint);
    }

    /**
     *
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral  The amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /**
     * 
     * @param tokenCollateralAddress  The address of the collateral
     * @param amountCollateral The amount of collateral to redee,
     * @param amountDscToBurn  The amount of DSC to burn
     * This function burns DSC and redeems underlying collateral in one transaction
     */

    function redeemCollateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn) external {
        burnDsc(amountDscToBurn);
        redeemCollateral(tokenCollateralAddress,amountCollateral);
        //redeemCollateral aleady checks health facyor
    }

    //Follow CEI
    function redeemCollateral(address tokenCollateralAddress,uint256 amountCollateral) public moreThanZero(amountCollateral) nonReentrant {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(msg.sender, tokenCollateralAddress, amountCollateral);
        bool sucess = IERC20(tokenCollateralAddress).transfer(msg.sender,amountCollateral);
        if (!sucess) {
            revert DSCEngine__TransferFailed();
        }

        _revertIfHealthFactorIsBroken(msg.sender);
    }

    //Once we redeed our collateral, we need to burn some DSC f equal amount
    function burnDsc(uint256 amount) public {
        s_DSCMinted[msg.sender] -= amount;
        bool success = i_dsc.transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amount);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice follow CEI
     * @param amountDscToMint  The amount of Decentralized Stable Coin to mint
     * @notice they must have more collateral value than the minimum threshold
     */
    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    //If someone is almost undercollateralized, will pay you to liquidate them - gamified!!
    //E.g 75USD in ETH backing 50USD in DSC
    //Liquidator takes $75 backing and burns of the $50 DSC
    //How can I prevent liquidation by automatically adding collateral to prevent liquidation

    /**
     * 
     * @param collateral The ERC20 collateral address to liquidate from the user
     * @param user The user who has broken the health factor. Their _healthFactor should be below MIN_HEALTH_FACTOR
     * @param debtToCover The amount of DSC you want to burn to improve the users healthFactor
     * @notice You will partially liquidate user
     * @notice You will get a liquidation bonus for taking the users funds
     * @notice This function working assumes the protocol will be roughly 
     * 200% overcollateralized 
     * @notice A known bug would be if the protocol were 100% or less collateralize and tehn we wouldnt be able to incentivize
     * the liquidators
     * For example, id the price of the collateral plummented before anyone could be liquidated
     * Follow :CEI
     */
    function liquidate(address collateral, address user, uint256 debtToCover) external moreThanZero(debtToCover) nonReentrant{
        //need to check health factor of the user
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOk();
        }
        //We want to burn their DSC "debt"
        // And take their collateral
        //Bad Indebt user: $140 ETH, $100 DSC
        // debtToCover = $100
        //$100 of DSC == ??? ETH?
        // 0.05 ETH

        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral,debtToCover);
        //And give the a 10% bonus
        //So we are giving the liquidator some $110 WETH for 100 DSC
        //We should implement a feature to liquidate in the event the protocol is insolvent
        //And sweep extra amounts into a treasury
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) /
        LIQUIDATION_PRECISION;
        // 0.05 * 0.1(10%) = 0.005 getting 0.055
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
        

    }

    function getHealthFactor() external view {} 

    ///////////////Private & Internal View Functions///////

    /**
     * @notice Returns how close to liquidation a user is: if the user
     * goes below 1, then they can get liquidated
     *
     * To calculate healthFactor we need 2 things
     * total Dsc Minted
     * total collated VALUE
     *
     */
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        /**
         * A liquidation threshold of 50 just means you need at minimum always overcollateralized by 50%
         * Or the amount of collateral should always be double the amount of DSC held at any given time and
         * it cannot go below that
         * So if you have 1000 ETH as collateral at any one time you can only hold 500 DSC
         * 1000 ETH *50(LIQUIDATION THRESHOLD) = 50000/ 100(LIQUIDATION PRECISION) 500 DSC (50000/100)
         * You get a health factor of 500 which is more that enough
         * However if the price of ETH falls and value of your ETH falls to 750
         * while you only hold 500 DSC
         * 750 ETH *50 (LIQUIDATION THRESHOLD) = 37500 / 100 (LIQUIDATION PRECISION) = 375 DSC
         * You get a health 750 ETH /500 DSC 0.75 (UNDER COLLATERALIZED!!)
         *   *
         */
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    //////////Public and External View Functions//////////

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns(uint256){
        //So how do we get token amount from the USD value
        // Eg. Price of ETH is 2000$ per ETH
        // There for to get the tokenAmount
        //OR amount in ETH from its dollar value
        //Given token amoount of 1000 USD
        //1000/2000 = 0.5 ETH

        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (,int256 price,,,) = priceFeed.latestRoundData();

        //Remember the rules 1. Multiply before adding
        //2. our "price" return and 8 decimal point so we need to multiple by 1e10
        //For feed precision

        return(usdAmountInWei*PRECISION) / (uint256(price)) * ADDITIONAL_FEED_PRECISION;
        // EX. ($10e18 * 1e18) / ($2000e8 * 1e10) = 5e18 or 0.005 ETH
    }

    function getAccountCollateralValue(address user) public view returns (uint256 tokenCollateralValueInUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            tokenCollateralValueInUsd += getUsdValue(token, amount);
        }
        return tokenCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }
}
