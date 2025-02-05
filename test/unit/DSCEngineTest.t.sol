//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;

    address ethUsdPriceFeed; //fetch from HelperConfig
    address btcUsdPriceFeed;
    address weth; // fetch from HelperConfig

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployDSC();
        //Our DeployDSC.s.sol script returns (dsc, engine) objects

        (dsc, engine, config) = deployer.run();
        //.run() function belongs to the DeployDSC objects and that is how we acces (dsc,engine)
        (ethUsdPriceFeed,btcUsdPriceFeed, weth,,) = config.activeNetworkConfig(); //The empty spaces are for the things we dont need like the wbtcUsedPRice, deployerKey etc
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    ///////////////Constructor Tests/////// 

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertIfTokenLengthDoesntMatchPriceFeeds() public{
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses,priceFeedAddresses,address(dsc));

    }

    ///////////////Price Tests/////////////

    //Remove view at some point
    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;

        uint256 expectedUsd = 30000e18;
        //OR 15e18(ethAmount) *2000USD/ETH (Price set in the MockAggregator) = 30000e18
        uint256 actualUsd = engine.getUsdValue(weth, ethAmount);

        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public view{
        uint256 usdAmount = 100 ether;

        //$2,000 / ETH, $100
        uint256 expectedWeth = 0.05 ether;

        uint256 actualWeth = engine.getTokenAmountFromUsd(weth,usdAmount);
        assertEq(expectedWeth,actualWeth);
    }


    /////////////////////depositeCollateralTests///////////////////////

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsc), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.depositCollateral(weth, 0);

        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public{
        //Create a radom mock token
        ERC20Mock randToken = new ERC20Mock("RAND","RAND", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowToken.selector);
        engine.depositCollateral(address(randToken),AMOUNT_COLLATERAL);
        vm.stopPrank();

    }
}
