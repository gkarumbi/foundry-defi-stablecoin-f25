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

pragma solidity ^0.8.18 ;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
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

    ///////////////////////State Variables//////////////// 
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;

    mapping (address token  => address priceFeed) private s_priceFeeds; //allowedtokenToPriceFeed
    mapping(address user => mapping (address token => uint256 amount)) private s_collateralDeposited;
    mapping (address user => uint256) private s_DSCMinted;
    address[] private s_collateralTokens;
    DecentralizedStableCoin private immutable i_dsc;


    ///////////////////Events /////////////////////// 
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
  

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
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress){
        //USD price Feeds
        if(tokenAddresses.length != priceFeedAddresses.length){
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
    function depositCollateralAndMintDsc() external {}

    /**
     * 
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral  The amount of collateral to deposit
     */

    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral) external moreThanZero(amountCollateral) isAllowedToken(tokenCollateralAddress) nonReentrant{
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender,address(this), amountCollateral);
        if(!success){
            revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    function burnDsc() external {}

    function mintDsc() external{}

    function liquidate() external {}

    function getHealthFactor() external view{}

    ///////////////Private & Internal View Functions///////
    function _getAccountInformation(address user) private view returns(uint256 totalDscMinted, uint256 collateralValueInUsd){
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    //////////Public and External View Functions//////////

    function getAccountCollateralValue(address user) public view returns(uint256 tokenCollateralValueInUsd){
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            tokenCollateralValueInUsd += getUsdValue(token, amount);
            
        }
        return tokenCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns(uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[toke]);
        (,int256 price,,,) = priceFeed.latestRoundData();

        return((uint256(price)* ADDITIONAL_FEED_PRECISION)*amount) / PRECISION;
    }
    
}