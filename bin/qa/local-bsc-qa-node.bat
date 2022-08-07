@echo off

set script=.\scripts\bsc-mainnet-qa\v2\index.ts

echo Starting a local isolated node...

start npx hardhat node

timeout /t 5

echo Running script "%script%" in a local isolated node...

npx hardhat run %script% --network localhost
