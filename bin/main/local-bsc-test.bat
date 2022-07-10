@echo off

set script=.\scripts\local\main\setupAndTest.ts

echo Running script "%script%" in hardhat isolated environment...

npx hardhat run %script% --network hardhat
