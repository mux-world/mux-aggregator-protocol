# mux-aggregator-protocol

The MUX Aggregator is a sub-protocol in the MUX protocol suite that automatically selects the most suitable liquidity route and minimizes the composite cost for traders while meeting the needs of opening positions. The aggregator can also supply additional margin for traders to raise the leverage up to 100x on aggregated underlying protocols.

Update: 1. MUX no longer supports GMX1Adapter; 2. Borrowing via GMX2Adapter is disabled.

## Compile

```
yarn
patch -p1 < misc/hardhat+2.11.2.patch
npx hardhat compile
```

## Run test cases

```
npx hardhat test
```
