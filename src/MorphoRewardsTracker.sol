// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.13;

import {ILens} from "@morpho-dao/morpho-core-v1/contracts/compound/interfaces/ILens.sol";

contract MorphoRewardsTracker {
    address public constant CDAI = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643;

    address public constant LENS = 0x930f1b46e1D081Ec1524efD95752bE3eCe51EF67;

    function getUnclaimedComp() external view returns (uint256) {
        address[] memory markets = new address[](1);
        markets[0] = CDAI; // the DAI market, represented by the cDAI ERC20 token

        return
            ILens(LENS).getUserUnclaimedRewards(
                markets, // the markets to query unclaimed COMP rewards on
                address(this) // the address of the user you want to query unclaimed COMP rewards of
            );
    }
}
