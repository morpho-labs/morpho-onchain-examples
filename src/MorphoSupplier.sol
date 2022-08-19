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

contract MorphoSupplier {
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

    /// @notice Returns the distribution of WBTC supplied by this contract through Morpho-Compound.
    /// @return suppliedOnPool The amount of WBTC supplied on Compound's pool (with 8 decimals, the number of decimals of WBTC).
    /// @return suppliedP2P The amount of WBTC supplied peer-to-peer through Morpho-Compound (with 8 decimals, the number of decimals of WBTC).
    function getWBTCSupplyBalance()
        public
        view
        returns (uint256 suppliedOnPool, uint256 suppliedP2P)
    {
        (suppliedOnPool, suppliedP2P, ) = ILens(LENS)
            .getCurrentSupplyBalanceInOf(
                CWBTC2, // the WBTC market, represented by the cWBTC2 ERC20 token
                address(this) // the address of the user you want to know the supply of
            );
    }

    /// @notice Returns the distribution of WBTC supplied by this contract through Morpho-Compound.
    /// @return suppliedOnPoolUSD The USD value of the amount of WBTC supplied on Compound's pool (with 18 decimals, whatever the market).
    /// @return suppliedP2PUSD The USD value of the amount of WBTC supplied peer-to-peer through Morpho-Compound (with 18 decimals, whatever the market).
    function getWBTCSupplyBalanceUSD()
        public
        view
        returns (uint256 suppliedOnPoolUSD, uint256 suppliedP2PUSD)
    {
        (uint256 suppliedOnPool, uint256 suppliedP2P) = getWBTCSupplyBalance();

        uint256 oraclePrice = ORACLE.getUnderlyingPrice(CWBTC2); // in (36 - nb decimals of WBTC = 28) decimals

        suppliedOnPoolUSD = suppliedOnPool.mul(oraclePrice); // in 18 decimals, whatever the underlying token
        suppliedP2PUSD = suppliedP2P.mul(oraclePrice); // in 18 decimals, whatever the underlying token
    }

    /// @notice Returns the average supply rate per block experienced on the DAI market.
    /// @dev The supply rate experienced on a market is specific to each user,
    ///      dependending on how their supply is matched peer-to-peer or supplied to the Compound pool.
    /// @return The rate per block at which supply interests are accumulated on average on the DAI market.
    function getDAIAvgSupplyRatePerBlock() public view returns (uint256) {
        return
            ILens(LENS).getAverageSupplyRatePerBlock(
                CDAI // the DAI market, represented by the cDAI ERC20 token
            );
    }

    /// @notice Returns the average supply APR experienced on the DAI market.
    /// @dev The supply rate experienced on a market is specific to each user,
    ///      dependending on how their supply is matched peer-to-peer or supplied to the Compound pool.
    /// @return The APR at which supply interests are accumulated on average on the DAI market.
    function getDAIAvgSupplyAPR() public view returns (uint256) {
        return getDAIAvgSupplyRatePerBlock() * BLOCKS_PER_YEAR;
    }

    /// @notice Returns the supply rate per block this contract experiences on the WBTC market.
    /// @dev The supply rate experienced on a market is specific to each user,
    ///      dependending on how their supply is matched peer-to-peer or supplied to the Compound pool.
    /// @return The rate per block at which supply interests are accumulated by this contract on the WBTC market.
    function getWBTCSupplyRatePerBlock() public view returns (uint256) {
        return
            ILens(LENS).getCurrentUserSupplyRatePerBlock(
                CWBTC2, // the WBTC market, represented by the cWBTC2 ERC20 token
                address(this) // the address of the user you want to know the supply rate of
            );
    }

    /// @notice Returns the supply rate per block this contract experiences on the WBTC market.
    /// @dev The supply rate experienced on a market is specific to each user,
    ///      dependending on how their supply is matched peer-to-peer or supplied to the Compound pool.
    /// @return The rate per block at which supply interests are accumulated by this contract on the WBTC market.
    function getWBTCNextSupplyRatePerBlock(uint256 _amount)
        public
        view
        returns (uint256)
    {
        return
            ILens(LENS).getNextUserSupplyRatePerBlock(
                CWBTC2, // the WBTC market, represented by the cWBTC2 ERC20 token
                address(this), // the address of the user you want to know the next supply rate of
                _amount
            );
    }

    /// @notice Returns the expected amount of supply interests accrued by this contract, on the WBTC market, after `_nbBlocks`.
    /// @return The expected amount of WBTC supply interests accrued (in 8 decimals, the number of decimals of WBTC).
    function getWBTCExpectedAccruedInterests(uint256 _nbBlocks)
        public
        view
        returns (uint256)
    {
        (uint256 suppliedOnPool, uint256 suppliedP2P) = getWBTCSupplyBalance();
        uint256 supplyRatePerBlock = getWBTCSupplyRatePerBlock();

        return
            (suppliedOnPool + suppliedP2P).mul(supplyRatePerBlock) * _nbBlocks;
    }

    /// @notice Returns the expected APR at which supply interests are accrued by this contract, on the WBTC market.
    /// @return The APR at which WBTC supply interests are accrued (in 18 decimals, whatever the market).
    function getWBTCSupplyAPR() public view returns (uint256) {
        uint256 supplyRatePerBlock = getWBTCSupplyRatePerBlock();

        return supplyRatePerBlock * BLOCKS_PER_YEAR;
    }

    /// SUPPLY ///

    function _supplyERC20(
        address _cToken,
        address _underlying,
        uint256 _amount
    ) internal {
        IERC20(_underlying).approve(MORPHO, _amount);
        IMorpho(MORPHO).supply(
            _cToken,
            address(this), // the address of the user you want to supply on behalf of
            _amount
        );
    }

    function supplyDAI(uint256 _amount) public {
        _supplyERC20(
            CDAI, // the DAI market, represented by the cDAI ERC20 token
            DAI,
            _amount
        );
    }

    function supplyETH() public payable {
        // first wrap ETH into WETH
        IWETH9(WETH).deposit{value: msg.value}();

        _supplyERC20(
            CETH, // the WETH market, represented by the cETH ERC20 token
            WETH,
            msg.value
        );
    }

    /// WITHDRAW ///

    function _withdrawERC20(address _cToken, uint256 _amount) internal {
        IMorpho(MORPHO).withdraw(_cToken, _amount);
    }

    function withdrawERC20(uint256 _amount) public {
        _withdrawERC20(
            CDAI, // the DAI market, represented by the cDAI ERC20 token
            _amount
        );
        // this contract now has _amount DAI: IERC20(DAI).balanceOf(address(this)) == _amount
    }

    function withdrawETH(uint256 _amount) public {
        _withdrawERC20(
            CETH, // the ETH market, represented by the cETH ERC20 token
            _amount
        );
        // this contract now has _amount WETH: IERC20(WETH).balanceOf(address(this)) == _amount
        IWETH9(WETH).withdraw(_amount);
        // this contract now has _amount ETH: address(this).balance == _amount
    }
}
