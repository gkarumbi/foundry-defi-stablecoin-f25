//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSC is Script{
    function run() external returns(DecentralizedStableCoin, DSCEngine){
        
        HelperConfig config = new HelperConfig(); //constructor does not take anything
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey ) = config.activeNetworkConfig;
        vm.startBroadcast();
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
       // DSCEngine engine = new DSCEngine(); // Take in a couple of arguments
       vm.stopBroadcast();

    }
}
