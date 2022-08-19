# Morpho-Compound On-Chain Examples

Learn how to interact with the Morpho-Compound protocol on-chain using a Smart Contract!

## Installation

This example repository uses [foundry](https://github.com/foundry-rs/foundry) to manage dependencies and resolve them at compilation.

```bash
git clone git@github.com:morpho-labs/morpho-onchain-examples.git
cd morpho-onchain-examples
git submodule update --init --recursive
```

## Dependencies

Dependencies are included as git submodules and installable on any git repository. We recommend doing so via:

```bash
git submodule add https://github.com/morpho-dao/morpho-core-v1 lib/morpho-dao/morpho-core-v1
git submodule add https://github.com/morpho-dao/morpho-utils lib/morpho-dao/morpho-utils
git submodule add https://github.com/OpenZeppelin/openzeppelin-contracts lib/openzeppelin/contracts
```

But you can also install them via `npm` or `yarn`:

```bash
yarn add @morphodao/morpho-core-v1
yarn add @openzeppelin/contracts
```

> [morpho-utils](https://github.com/morpho-dao/morpho-utils) is not yet available as an npm package!

## Examples

- [MorphoSupplier.sol](./src/MorphoSupplier.sol): supply through Morpho-Compound using a Smart Contract
- [MorphoBorrower.sol](./src/MorphoBorrower.sol): borrow through Morpho-Compound using a Smart Contract
- [MorphoRewardsTracker.sol](./src/MorphoRewardsTracker.sol): track rewards accrued through Morpho-Compound using a Smart Contract
