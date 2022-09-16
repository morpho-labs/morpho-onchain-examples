// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ISupplyVault} from "@morpho-dao/morpho-tokenized-vaults/src/aave-v2/interfaces/ISupplyVault.sol";

contract MorphoAaveV2VaultSupplier {
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address public constant MA_DAI = 0xd99D793B8FDaE42C1867293C172b9CBBD3ea49FF;

    /// QUERY ///

    /// @notice Returns the total balance of DAI this contract has supplied and accrued through the vault.
    /// @return The total balance of DAI this contract has supplied and accrued through the vault.
    function getDAIBalance() public view returns (uint256) {
        return
            ISupplyVault(MA_DAI).convertToAssets(
                ISupplyVault(MA_DAI).balanceOf(address(this))
            );
    }

    /// SUPPLY ///

    function deposit(uint256 _amount) internal {
        IERC20(DAI).approve(MA_DAI, _amount);
        ISupplyVault(MA_DAI).deposit(
            _amount,
            address(this) // the address of the user you want to supply on behalf of
        );
    }

    /// WITHDRAW ///

    function withdraw(uint256 _amount) internal {
        ISupplyVault(MA_DAI).withdraw(
            _amount,
            address(this), // the address of the receiver of the funds withdrawn
            address(this) // the address of the user you want to withdraw from (they must have approved this contract to spend their tokens)
        );
    }
}
