# Stable Coins

## Specification for Project:

1. Write 2 contracts DecentralizedStableCoin and DSCEngine, where DecentralisedStableCoin is a ERC20 compatible token contract with burn and mint functions restricted to onlyOwner of the Contract.

2. DSCEngine handles the logic of minting, burn, redemption and liquidation of stable coins. The collateral for stable coin is a set of ERC20 tokens that are provided during the deployment of the stable coin contract along with the priceFeedAddresses of the oracle and stable coin address.

3. Implement depositCollateralAndMint function with inputs as one of the accepted token collateral addresses, amount of token as collateral and amount of stable coin to mint.

4. Implement redeemCollateralForStableCoin function with inputs as one of the accepted token collateral addresses, amount of collateral to withdraw and amount of stable coin to burn.

5. Implement liquidate function to liquidate users with healthFactor below MIN_HEALTH_FACTOR.

6. Implement necessary functions like calculateHealthFactor, getAccountInformation, getCollateralBalanceOfUser, getCollateralValue, getTokenAmountFromUsd and getter functions for all constants used throughout the contracts.

7. Write tests asserting the functionality of the stable coin.
