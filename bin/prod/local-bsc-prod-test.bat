@echo off

set script=.\scripts\bsc-mainnet-prod\v1\index.ts

echo Running script "%script%" in hardhat isolated environment...

npx hardhat run %script% --network hardhat
