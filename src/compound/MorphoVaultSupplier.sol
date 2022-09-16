// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ISupplyVault} from "@morpho-dao/morpho-tokenized-vaults/src/compound/interfaces/ISupplyVault.sol";
import {ISupplyHarvestVault} from "@morpho-dao/morpho-tokenized-vaults/src/compound/interfaces/ISupplyHarvestVault.sol";

contract MorphoCompoundVaultSupplier {
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address public constant MC_DAI = 0xd99D793B8FDaE42C1867293C172b9CBBD3ea49FF;
    address public constant MCH_DAI =
        0x5CBead740564A2173983E48f94F36357C1954EAE;

    /// QUERY ///

    /// @notice Returns the total balance of DAI this contract has supplied and accrued through the vault.
    /// @return The total balance of DAI this contract has supplied and accrued through the vault.
    function getDAIBalance() public view returns (uint256) {
        return
            ISupplyVault(MC_DAI).convertToAssets(
                ISupplyVault(MC_DAI).balanceOf(address(this))
            );
    }

    /// @notice Returns the amount of rewards this contract accrued through the vault.
    /// @return unclaimed The amount of COMP rewards this contract accrued through the vault.
    function getUnclaimedRewards() public view returns (uint256 unclaimed) {
        (, unclaimed) = ISupplyVault(MC_DAI).userRewards(address(this));
    }

    /// SUPPLY ///

    function deposit(uint256 _amount) internal {
        IERC20(DAI).approve(MC_DAI, _amount);
        ISupplyVault(MC_DAI).deposit(
            _amount,
            address(this) // the address of the user you want to supply on behalf of
        );
    }

    function depositHarvest(uint256 _amount) internal {
        IERC20(DAI).approve(MCH_DAI, _amount);
        ISupplyHarvestVault(MCH_DAI).deposit(
            _amount,
            address(this) // the address of the user you want to supply on behalf of
        );
    }

    /// WITHDRAW ///

    function withdraw(uint256 _amount) internal {
        ISupplyVault(MC_DAI).withdraw(
            _amount,
            address(this), // the address of the receiver of the funds withdrawn
            address(this) // the address of the user you want to withdraw from (they must have approved this contract to spend their tokens)
        );
    }

    function withdrawHarvest(uint256 _amount) internal {
        ISupplyHarvestVault(MCH_DAI).withdraw(
            _amount,
            address(this), // the address of the receiver of the funds withdrawn
            address(this) // the address of the user you want to withdraw from (they must have approved this contract to spend their tokens)
        );
    }

    /// REWARDS ///

    function claimRewards() {
        ISupplyVault(MC_DAI).claimRewards(address(this));
    }

    function harvest() {
        ISupplyVault(MCH_DAI).harvest();
    }
}
