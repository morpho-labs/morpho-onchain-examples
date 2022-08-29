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

contract MorphoAaveV2Supplier {
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

    /// @notice Returns the distribution of WBTC supplied by this contract through Morpho-AaveV2.
    /// @return suppliedOnPool The amount of WBTC supplied on AaveV2's pool (with 8 decimals, the number of decimals of WBTC).
    /// @return suppliedP2P The amount of WBTC supplied peer-to-peer through Morpho-AaveV2 (with 8 decimals, the number of decimals of WBTC).
    function getWBTCSupplyBalance()
        public
        view
        returns (uint256 suppliedOnPool, uint256 suppliedP2P)
    {
        (suppliedOnPool, suppliedP2P, ) = ILens(LENS)
            .getCurrentSupplyBalanceInOf(
                AWBTC, // the WBTC market, represented by the aWBTC ERC20 token
                address(this) // the address of the user you want to know the supply of
            );
    }

    /// @notice Returns the distribution of WBTC supplied by this contract through Morpho-AaveV2.
    /// @return suppliedOnPoolDAI The DAI amount of WBTC supplied on AaveV2's pool (with 18 decimals, the number of decimals of DAI).
    /// @return suppliedP2PDAI The DAI amount of WBTC supplied peer-to-peer through Morpho-AaveV2 (with 18 decimals, the number of decimals of DAI).
    function getWBTCSupplyBalanceDAI()
        public
        view
        returns (uint256 suppliedOnPoolDAI, uint256 suppliedP2PDAI)
    {
        (uint256 suppliedOnPool, uint256 suppliedP2P) = getWBTCSupplyBalance();

        uint256 oraclePrice = ORACLE.getAssetPrice(DAI); // with 18 decimals, whatever the market

        suppliedOnPoolDAI = suppliedOnPool.wadMul(oraclePrice); // with 18 decimals, the number of decimals of DAI
        suppliedP2PDAI = suppliedP2P.wadMul(oraclePrice); // with 18 decimals, the number of decimals of DAI
    }

    /// @notice Returns the average supply APR experienced on the DAI market.
    /// @dev The supply rate experienced on a market is specific to each user,
    ///      dependending on how their supply is matched peer-to-peer or supplied to the AaveV2 pool.
    /// @return The APR at which supply interests are accrued on average on the DAI market (with 27 decimals).
    function getDAIAvgSupplyAPR() public view returns (uint256) {
        return
            ILens(LENS).getAverageSupplyRatePerYear(
                ADAI // the DAI market, represented by the aDAI ERC20 token
            );
    }

    /// @notice Returns the supply APR this contract experiences on the WBTC market.
    /// @dev The supply rate experienced on a market is specific to each user,
    ///      dependending on how their supply is matched peer-to-peer or supplied to the AaveV2 pool.
    /// @return The APR at which supply interests are accrued by this contract on the WBTC market (with 27 decimals).
    function getWBTCSupplyAPR() public view returns (uint256) {
        return
            ILens(LENS).getCurrentUserSupplyRatePerYear(
                AWBTC, // the WBTC market, represented by the aWBTC ERC20 token
                address(this) // the address of the user you want to know the supply rate of
            );
    }

    /// @notice Returns the supply APR this contract will experience (at minimum) if it supplies the given amount on the WBTC market.
    /// @dev The supply rate experienced on a market is specific to each user,
    ///      dependending on how their supply is matched peer-to-peer or supplied to the AaveV2 pool.
    /// @return nextSupplyAPR The APR at which supply interests would be accrued by this contract on the WBTC market (with 27 decimals).
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

    /// @notice Returns the expected amount of supply interests accrued by this contract, on the WBTC market, after `_nbSeconds`.
    /// @return The expected amount of WBTC supply interests accrued (with 8 decimals, the number of decimals of WBTC).
    function getWBTCExpectedAccruedInterests(uint256 _nbSeconds)
        public
        view
        returns (uint256)
    {
        (uint256 suppliedOnPool, uint256 suppliedP2P) = getWBTCSupplyBalance();
        uint256 supplyRatePerYear = getWBTCSupplyAPR();

        return
            ((suppliedOnPool + suppliedP2P).rayMul(supplyRatePerYear) *
                _nbSeconds) / 365.25 days;
    }

    /// SUPPLY ///

    function _supplyERC20(
        address _aToken,
        address _underlying,
        uint256 _amount
    ) internal {
        IERC20(_underlying).approve(MORPHO, _amount);
        IMorpho(MORPHO).supply(
            _aToken,
            address(this), // the address of the user you want to supply on behalf of
            _amount
        );
    }

    function supplyDAI(uint256 _amount) public {
        _supplyERC20(
            ADAI, // the DAI market, represented by the aDAI ERC20 token
            DAI,
            _amount
        );
    }

    function supplyETH() public payable {
        // first wrap ETH into WETH
        IWETH9(WETH).deposit{value: msg.value}();

        _supplyERC20(
            AWETH, // the WETH market, represented by the aWETH ERC20 token
            WETH,
            msg.value
        );
    }

    /// WITHDRAW ///

    function _withdrawERC20(address _aToken, uint256 _amount) internal {
        IMorpho(MORPHO).withdraw(_aToken, _amount);
    }

    function withdrawERC20(uint256 _amount) public {
        _withdrawERC20(
            ADAI, // the DAI market, represented by the aDAI ERC20 token
            _amount
        );
        // this contract now has _amount DAI: IERC20(DAI).balanceOf(address(this)) == _amount
    }

    function withdrawETH(uint256 _amount) public {
        _withdrawERC20(
            AWETH, // the ETH market, represented by the aWETH ERC20 token
            _amount
        );
        // this contract now has _amount WETH: IERC20(WETH).balanceOf(address(this)) == _amount
        IWETH9(WETH).withdraw(_amount);
        // this contract now has _amount ETH: address(this).balance == _amount
    }
}
