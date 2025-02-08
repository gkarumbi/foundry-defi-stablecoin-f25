//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../../test/mocks/MockV3Aggregator.sol";

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
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = config.activeNetworkConfig(); //The empty spaces are for the things we dont need like the wbtcUsedPRice, deployerKey etc
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);

        //console.log("eth/usd",ethUsdPriceFeed);
    }

    ///////////////Constructor Tests///////

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
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

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;

        //$2,000 / ETH, $100
        uint256 expectedWeth = 0.05 ether;

        uint256 actualWeth = engine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    /////////////////////depositeCollateralTests///////////////////////

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsc), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.depositCollateral(weth, 0);

        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        //Create a radom mock token
        ERC20Mock randToken = new ERC20Mock("RAND", "RAND", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowToken.selector);
        engine.depositCollateral(address(randToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositedAmount = engine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositedAmount);
    }

    //TODO: Write more

    /* function testRevertsIfHealthFactorIsBroken_IsBelowMinimum() public{
        vm.startPrank(USER);
        //ERC20Mock(weth).approve(address(dsc), AMOUNT_COLLATERAL);
        engine.depositCollateral(address(weth), AMOUNT_COLLATERAL);
        engine.mintDsc(1000e18);

        //Simulate price drop
        //(ethUsdPriceFeed,, weth,,) = config.activeNetworkConfig(); //The empty spaces are for the things we dont need like the wbtcUsedPRice, deployerKey etc
        //ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
       //ethUsdPriceFeed.latestRoundData();
       MockV3Aggregator(ethUsdPriceFeed).updateAnswer(1000e8); //update feed price to $1000

        uint256 LIQUIDATION_THRESHOLD = 50; // Needs to be 200% overcollateralized
        uint256 LIQUIDATION_PRECISION = 100;

       //check heallth factor is now below the minimum
       (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);
       uint256 healthFactor = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / (LIQUIDATION_PRECISION *1e18) /totalDscMinted;
        assertEq(healthFactor,1e18, "Health factor should above mimimum");

         // Expect revert when checking health factor
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, healthFactor));
        //engine._revertIfHealthFactorIsBroken(USER); change function to public 
        vm.stopPrank();

    } */

    /*   function testRevertsIfHealthFactorIsBroken_IsBelowMinimum() public {
    vm.startPrank(USER);

    // Deposit collateral and mint DSC
    engine.depositCollateral(address(weth), AMOUNT_COLLATERAL);
    engine.mintDsc(1000e18);

    ERC20Mock(weth).approve(address(dsc), AMOUNT_COLLATERAL);

    // Simulate a price drop
    MockV3Aggregator(ethUsdPriceFeed).updateAnswer(1000e8); // Update feed price to $1000

    uint256 LIQUIDATION_THRESHOLD = 50; // 50% collateralized, needs to be more than 200% overcollateralized
    uint256 LIQUIDATION_PRECISION = 100;

    // Check the health factor is now below the minimum threshold
    (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);
    uint256 healthFactor = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / (LIQUIDATION_PRECISION * 1e18) / totalDscMinted;

    // Ensure the health factor is correctly calculated and assert that it is below the minimum allowed
    assert(healthFactor < 1e18);

    // Expect revert when the health factor is below the required threshold
    vm.expectRevert(
        abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, healthFactor)
    );

    // Call the function that will check if the health factor is broken and should revert
    engine.revertIfHealthFactorIsBroken(USER); // Ensure the function is callable and public

    vm.stopPrank();
    } */
    function testRevertsIfHealthFactorIsBroken_IsBelowMinimum() public {
        vm.startPrank(USER);

        // Approve the engine contract to spend the collateral (weth) on behalf of USER
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        // Deposit collateral and mint DSC
        engine.depositCollateral(address(weth), AMOUNT_COLLATERAL);
        engine.mintDsc(1000e18);

        // Simulate a price drop
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(1000e8); // Update feed price to $1000

        uint256 LIQUIDATION_THRESHOLD = 50; // 50% collateralized, needs to be more than 200% overcollateralized
        uint256 LIQUIDATION_PRECISION = 100;

        // Check the health factor is now below the minimum threshold
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);
        uint256 healthFactor =
            (collateralValueInUsd * LIQUIDATION_THRESHOLD) / (LIQUIDATION_PRECISION * 1e18) / totalDscMinted;

        // Ensure the health factor is correctly calculated and assert that it is below the minimum allowed
        assert(healthFactor < 1e18);

        // Expect revert when the health factor is below the required threshold
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, healthFactor));

        // Call the function that will check if the health factor is broken and should revert
        engine.revertIfHealthFactorIsBroken(USER); // Ensure the function is callable and public

        vm.stopPrank();
    }

    /* function testRevertsIfTransferFromFails() public{
    //Arrange -setup
    address owner = msg.sender;
    vm.prank(owner);

    MockFailedTrans
    }
    */

    function testCanDepositColateralWithoutMinting() public depositedCollateral {
        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, 0);
    }
}
