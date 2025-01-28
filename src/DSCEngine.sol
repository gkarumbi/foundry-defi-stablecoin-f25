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

    function depositCollateralAndMintDsc() external {}

    function depositCollateral() external{}

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    function burnDsc() external {}

    function mintDsc() external{}

    function liquidate() external {}

    function getHealthFactor() external view{}
    
}