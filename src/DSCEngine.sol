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

contract DSCEngine {

    //////////////////////Errors/////////////////////

    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();

    ///////////////////////State Variables//////////////// 
    mapping (address token  => address priceFeed) private s_priceFeeds; //allowedtokenToPriceFeed
    DecentralizedStableCoin private immutable i_dsc;

    ///////////////////////Modifiers//////////////// 



    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        //
        
    }

    ///////////////Functions////////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress){
        //USD price Feeds
        if(tokenAddresses.length != priceFeedAddresses.length){
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
        }

        i_dsc = DecentralizedStableCoin(dscAddress);

        //console.log("i_dsc " + i_dsc);

        //For example ETH/USD, BTC/USD, MKR/USD etc
    }

    //////////////External Functions/////////
    function depositCollateralAndMintDsc() external {}

    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral) external moreThanZero(amountCollateral){}

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    function burnDsc() external {}

    function mintDsc() external{}

    function liquidate() external {}

    function getHealthFactor() external view{}
    
}