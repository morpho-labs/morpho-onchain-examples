// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.13;

import {ILens} from "./interfaces/ILens.sol";
import {IMorpho} from "./interfaces/IMorpho.sol";
import {IPriceOracleGetter} from "./interfaces/aave/IPriceOracleGetter.sol";
import {IERC20} from "@openzeppelin/contracts/contracts/token/ERC20/IERC20.sol";

import {WadRayMath} from "@morpho-dao/morpho-utils/src/math/WadRayMath.sol";

interface IWETH9 {
    function deposit() external payable;

    function withdraw(uint256) external;
}

contract MorphoAaveV2Borrower {
    using WadRayMath for uint256;

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address public constant AWETH = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e;
    address public constant ADAI = 0x028171bCA77440897B824Ca71D1c56caC55b68A3;
    address public constant AWBTC = 0x9ff58f4fFB29fA2266Ab25e75e2A8b3503311656;

    address public constant LENS = 0x507fA343d0A90786d86C7cd885f5C49263A91FF4;
    address public constant MORPHO = 0x777777c9898D384F785Ee44Acfe945efDFf5f3E0;

    IPriceOracleGetter public immutable ORACLE;

    constructor() {
        ORACLE = IPriceOracleGetter(
            IMorpho(MORPHO).addressesProvider().getPriceOracle()
        );
    }

    /// QUERY ///

    /// @notice Returns the distribution of WBTC borrowed by this contract through Morpho-AaveV2.
    /// @return borrowedOnPool The amount of WBTC borrowed on AaveV2's pool (with 8 decimals, the number of decimals of WBTC).
    /// @return borrowedP2P The amount of WBTC borrowed peer-to-peer through Morpho-AaveV2 (with 8 decimals, the number of decimals of WBTC).
    function getWBTCBorrowBalance()
        public
        view
        returns (uint256 borrowedOnPool, uint256 borrowedP2P)
    {
        (borrowedOnPool, borrowedP2P, ) = ILens(LENS)
            .getCurrentBorrowBalanceInOf(
                AWBTC, // the WBTC market, represented by the aWBTC ERC20 token
                address(this) // the address of the user you want to know the borrow of
            );
    }

    /// @notice Returns the distribution of WBTC borrowed by this contract through Morpho-AaveV2.
    /// @return borrowedOnPoolDAI The DAI amount of WBTC borrowed on AaveV2's pool (with 18 decimals, the number of decimals of DAI).
    /// @return borrowedP2PDAI The DAI amount of WBTC borrowed peer-to-peer through Morpho-AaveV2 (with 18 decimals, the number of decimals of DAI).
    function getWBTCBorrowBalanceDAI()
        public
        view
        returns (uint256 borrowedOnPoolDAI, uint256 borrowedP2PDAI)
    {
        (uint256 borrowedOnPool, uint256 borrowedP2P) = getWBTCBorrowBalance();

        uint256 oraclePrice = ORACLE.getAssetPrice(DAI); // with 18 decimals, whatever the asset

        borrowedOnPoolDAI = borrowedOnPool.wadMul(oraclePrice); // with 18 decimals, the number of decimals of DAI
        borrowedP2PDAI = borrowedP2P.wadMul(oraclePrice); // with 18 decimals, the number of decimals of DAI
    }

    /// @notice Returns the average borrow APR experienced on the DAI market.
    /// @dev The borrow rate experienced on a market is specific to each user,
    ///      dependending on how their borrow is matched peer-to-peer or supplied to the AaveV2 pool.
    /// @return The APR at which borrow interests are accumulated on average on the DAI market (with 27 decimals).
    function getDAIAvgBorrowAPR() public view returns (uint256) {
        return
            ILens(LENS).getAverageBorrowRatePerYear(
                ADAI // the DAI market, represented by the cDAI ERC20 token
            );
    }

    /// @notice Returns the expected APR at which borrow interests are accrued by this contract, on the WBTC market.
    /// @dev The borrow rate experienced on a market is specific to each user,
    ///      dependending on how their borrow is matched peer-to-peer or supplied to the AaveV2 pool.
    /// @return The APR at which WBTC borrow interests are accrued (with 27 decimals).
    function getWBTCBorrowAPR() public view returns (uint256) {
        return
            ILens(LENS).getCurrentUserBorrowRatePerYear(
                AWBTC, // the WBTC market, represented by the aWBTC ERC20 token
                address(this) // the address of the user you want to know the borrow rate of
            );
    }

    /// @notice Returns the borrow APR this contract will experience (at maximum) if it borrows the given amount from the WBTC market.
    /// @dev The borrow rate experienced on a market is specific to each user,
    ///      dependending on how their borrow is matched peer-to-peer or supplied to the AaveV2 pool.
    /// @return nextSupplyAPR The APR at which borrow interests are accrued by this contract on the WBTC market (with 27 decimals).
    function getWBTCNextSupplyAPR(uint256 _amount)
        public
        view
        returns (uint256 nextSupplyAPR)
    {
        (nextSupplyAPR, , , ) = ILens(LENS).getNextUserSupplyRatePerYear(
            AWBTC, // the WBTC market, represented by the aWBTC ERC20 token
            address(this), // the address of the user you want to know the next supply rate of
            _amount
        );
    }

    /// @notice Returns the expected amount of borrow interests accrued by this contract, on the WBTC market, after `_nbSeconds`.
    /// @return The expected amount of WBTC borrow interests accrued (in 8 decimals, the number of decimals of WBTC).
    function getWBTCExpectedAccruedInterests(uint256 _nbSeconds)
        public
        view
        returns (uint256)
    {
        (uint256 borrowedOnPool, uint256 borrowedP2P) = getWBTCBorrowBalance();
        uint256 borrowRatePerYear = getWBTCBorrowAPR();

        return
            ((borrowedOnPool + borrowedP2P).rayMul(borrowRatePerYear) *
                _nbSeconds) / 365.25 days;
    }

    /// @notice Returns whether this contract is near liquidation (with a 5% threshold) on the WBTC market.
    /// @dev The markets borrowed (in this example, WBTC only) need to be virtually updated to compute the correct health factor.
    function isApproxLiquidatable() public view returns (bool) {
        return
            ILens(LENS).getUserHealthFactor(
                address(this) // the address of the user you want to know the health factor of
            ) <= 1.05e18;
    }

    /// BORROW ///

    function _borrowERC20(address _aToken, uint256 _amount) internal {
        IMorpho(MORPHO).borrow(_aToken, _amount);
    }

    function borrowDAI(uint256 _amount) public {
        _borrowERC20(
            ADAI, // the DAI market, represented by the aDAI ERC20 token
            _amount
        );
        // this contract now has _amount DAI: IERC20(DAI).balanceOf(address(this)) == _amount
    }

    function borrowETH(uint256 _amount) public {
        _borrowERC20(
            AWETH, // the ETH market, represented by the aWETH ERC20 token
            _amount
        );
        // this contract now has _amount WETH: IERC20(WETH).balanceOf(address(this)) == _amount
        IWETH9(WETH).withdraw(_amount);
        // this contract now has _amount ETH: address(this).balance == _amount
    }

    /// REPAY ///

    function _repayERC20(
        address _aToken,
        address _underlying,
        uint256 _amount
    ) internal {
        IERC20(_underlying).approve(MORPHO, _amount);
        IMorpho(MORPHO).repay(
            _aToken,
            address(this), // the address of the user you want to repay on behalf of
            _amount
        );
    }

    function repayDAI(uint256 _amount) public {
        _repayERC20(
            ADAI, // the DAI market, represented by the aDAI ERC20 token
            DAI,
            _amount
        );
    }

    function repayETH() public payable {
        // first wrap ETH into WETH
        IWETH9(WETH).deposit{value: msg.value}();

        _repayERC20(
            AWETH, // the WETH market, represented by the aWETH ERC20 token
            WETH,
            msg.value
        );
    }
}
