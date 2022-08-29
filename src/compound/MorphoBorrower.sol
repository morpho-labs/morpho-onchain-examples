// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.13;

import {ILens} from "@morpho-dao/morpho-core-v1/contracts/compound/interfaces/ILens.sol";
import {IMorpho, ICompoundOracle} from "@morpho-dao/morpho-core-v1/contracts/compound/interfaces/IMorpho.sol";
import {IERC20} from "@openzeppelin/contracts/contracts/token/ERC20/IERC20.sol";

import {CompoundMath} from "@morpho-dao/morpho-utils/src/math/CompoundMath.sol";

interface IWETH9 {
    function deposit() external payable;

    function withdraw(uint256) external;
}

contract MorphoCompoundBorrower {
    using CompoundMath for uint256;

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address public constant CETH = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    address public constant CDAI = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643;
    address public constant CWBTC2 = 0xccF4429DB6322D5C611ee964527D42E5d685DD6a;

    address public constant LENS = 0x930f1b46e1D081Ec1524efD95752bE3eCe51EF67;
    address public constant MORPHO = 0x8888882f8f843896699869179fB6E4f7e3B58888;

    uint256 public constant BLOCKS_PER_YEAR = 4 * 60 * 24 * 365.25 days;

    ICompoundOracle public immutable ORACLE;

    constructor() {
        ORACLE = ICompoundOracle(IMorpho(MORPHO).comptroller().oracle());
    }

    /// QUERY ///

    /// @notice Returns the distribution of WBTC borrowed by this contract through Morpho-Compound.
    /// @return borrowedOnPool The amount of WBTC borrowed on Compound's pool (with 8 decimals, the number of decimals of WBTC).
    /// @return borrowedP2P The amount of WBTC borrowed peer-to-peer through Morpho-Compound (with 8 decimals, the number of decimals of WBTC).
    function getWBTCBorrowBalance()
        public
        view
        returns (uint256 borrowedOnPool, uint256 borrowedP2P)
    {
        (borrowedOnPool, borrowedP2P, ) = ILens(LENS)
            .getCurrentBorrowBalanceInOf(
                CWBTC2, // the WBTC market, represented by the cWBTC2 ERC20 token
                address(this) // the address of the user you want to know the borrow of
            );
    }

    /// @notice Returns the distribution of WBTC borrowed by this contract through Morpho-Compound.
    /// @return borrowedOnPoolUSD The USD value of the amount of WBTC borrowed on Compound's pool (with 18 decimals, whatever the market).
    /// @return borrowedP2PUSD The USD value of the amount of WBTC borrowed peer-to-peer through Morpho-Compound (with 18 decimals, whatever the market).
    function getWBTCBorrowBalanceUSD()
        public
        view
        returns (uint256 borrowedOnPoolUSD, uint256 borrowedP2PUSD)
    {
        (uint256 borrowedOnPool, uint256 borrowedP2P) = getWBTCBorrowBalance();

        uint256 oraclePrice = ORACLE.getUnderlyingPrice(CWBTC2); // with (36 - nb decimals of WBTC = 30) decimals

        borrowedOnPoolUSD = borrowedOnPool.mul(oraclePrice); // with 18 decimals, whatever the underlying token
        borrowedP2PUSD = borrowedP2P.mul(oraclePrice); // with 18 decimals, whatever the underlying token
    }

    /// @notice Returns the average borrow rate per block experienced on the DAI market.
    /// @dev The borrow rate experienced on a market is specific to each user,
    ///      dependending on how their borrow is matched peer-to-peer or borrowed to the Compound pool.
    /// @return The rate per block at which borrow interests are accrued on average on the DAI market (with 18 decimals, whatever the market).
    function getDAIAvgBorrowRatePerBlock() public view returns (uint256) {
        return
            ILens(LENS).getAverageBorrowRatePerBlock(
                CDAI // the DAI market, represented by the cDAI ERC20 token
            );
    }

    /// @notice Returns the average borrow APR experienced on the DAI market.
    /// @dev The borrow rate experienced on a market is specific to each user,
    ///      dependending on how their borrow is matched peer-to-peer or supplied to the Compound pool.
    /// @return The APR at which borrow interests are accrued on average on the DAI market (with 18 decimals, whatever the market).
    function getDAIAvgBorrowAPR() public view returns (uint256) {
        return getDAIAvgBorrowRatePerBlock() * BLOCKS_PER_YEAR;
    }

    /// @notice Returns the borrow rate per block this contract experiences on the WBTC market.
    /// @dev The borrow rate experienced on a market is specific to each user,
    ///      dependending on how their borrow is matched peer-to-peer or supplied to the Compound pool.
    /// @return The rate per block at which borrow interests are accrued by this contract on the WBTC market (with 18 decimals).
    function getWBTCBorrowRatePerBlock() public view returns (uint256) {
        return
            ILens(LENS).getCurrentUserBorrowRatePerBlock(
                CWBTC2, // the WBTC market, represented by the cWBTC2 ERC20 token
                address(this) // the address of the user you want to know the borrow rate of
            );
    }

    /// @notice Returns the expected APR at which borrow interests are accrued by this contract, on the WBTC market.
    /// @dev The borrow rate experienced on a market is specific to each user,
    ///      dependending on how their borrow is matched peer-to-peer or supplied to the AaveV2 pool.
    /// @return The APR at which WBTC borrow interests are accrued (with 18 decimals, whatever the market).
    function getWBTCBorrowAPR() public view returns (uint256) {
        uint256 borrowRatePerBlock = getWBTCBorrowRatePerBlock();

        return borrowRatePerBlock * BLOCKS_PER_YEAR;
    }

    /// @notice Returns the borrow APR this contract will experience (at maximum) if it borrows the given amount from the WBTC market.
    /// @dev The borrow rate experienced on a market is specific to each user,
    ///      dependending on how their borrow is matched peer-to-peer or supplied to the Compound pool.
    /// @return The APR at which borrow interests would be accrued by this contract on the WBTC market (with 18 decimals).
    function getWBTCNextSupplyAPR(uint256 _amount)
        public
        view
        returns (uint256)
    {
        (uint256 nextSupplyRatePerBlock, , , ) = ILens(LENS)
            .getNextUserSupplyRatePerBlock(
                CWBTC2, // the WBTC market, represented by the cWBTC2 ERC20 token
                address(this), // the address of the user you want to know the next supply rate of
                _amount
            );

        return nextSupplyRatePerBlock * BLOCKS_PER_YEAR;
    }

    /// @notice Returns the expected amount of borrow interests accrued by this contract, on the WBTC market, after `_nbBlocks`.
    /// @return The expected amount of WBTC borrow interests accrued (in 8 decimals, the number of decimals of WBTC).
    function getWBTCExpectedAccruedInterests(uint256 _nbBlocks)
        public
        view
        returns (uint256)
    {
        (uint256 borrowedOnPool, uint256 borrowedP2P) = getWBTCBorrowBalance();
        uint256 borrowRatePerBlock = getWBTCBorrowRatePerBlock();

        return
            (borrowedOnPool + borrowedP2P).mul(borrowRatePerBlock) * _nbBlocks;
    }

    /// @notice Returns whether this contract is near liquidation (with a 5% threshold) on the WBTC market.
    /// @dev The markets borrowed (in this example, WBTC only) need to be virtually updated to compute the correct health factor.
    function isApproxLiquidatable() public view returns (bool) {
        return
            ILens(LENS).getUserHealthFactor(
                address(this), // the address of the user you want to know the health factor of
                ILens(LENS).getEnteredMarkets(address(this)) // the markets entered by the user, to make sure the health factor accounts for interests accrued
            ) <= 1.05e18;
    }

    /// BORROW ///

    function _borrowERC20(address _cToken, uint256 _amount) internal {
        IMorpho(MORPHO).borrow(_cToken, _amount);
    }

    function borrowDAI(uint256 _amount) public {
        _borrowERC20(
            CDAI, // the DAI market, represented by the cDAI ERC20 token
            _amount
        );
        // this contract now has _amount DAI: IERC20(DAI).balanceOf(address(this)) == _amount
    }

    function borrowETH(uint256 _amount) public {
        _borrowERC20(
            CETH, // the ETH market, represented by the cETH ERC20 token
            _amount
        );
        // this contract now has _amount WETH: IERC20(WETH).balanceOf(address(this)) == _amount
        IWETH9(WETH).withdraw(_amount);
        // this contract now has _amount ETH: address(this).balance == _amount
    }

    /// REPAY ///

    function _repayERC20(
        address _cToken,
        address _underlying,
        uint256 _amount
    ) internal {
        IERC20(_underlying).approve(MORPHO, _amount);
        IMorpho(MORPHO).repay(
            _cToken,
            address(this), // the address of the user you want to repay on behalf of
            _amount
        );
    }

    function repayDAI(uint256 _amount) public {
        _repayERC20(
            CDAI, // the DAI market, represented by the cDAI ERC20 token
            DAI,
            _amount
        );
    }

    function repayETH() public payable {
        // first wrap ETH into WETH
        IWETH9(WETH).deposit{value: msg.value}();

        _repayERC20(
            CETH, // the WETH market, represented by the cETH ERC20 token
            WETH,
            msg.value
        );
    }
}
