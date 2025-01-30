//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;

    function setUp() public{
        deployer = new DeployDSC();
        //Our DeployDSC.s.sol script returns (dsc, engine) objects

        (dsc,engine) = deployer.run();
        //.run() function belongs to the DeployDSC objects and that is how we acces (dsc,engine)
    }

}