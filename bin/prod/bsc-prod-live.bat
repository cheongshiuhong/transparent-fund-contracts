@echo off

set script=.\scripts\bsc-mainnet-prod\v1\index.ts

echo Running script "%script%" in bsc mainnet...

npx hardhat run %script% --network bsc-mainnet
