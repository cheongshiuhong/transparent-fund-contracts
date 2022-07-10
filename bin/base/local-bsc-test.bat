@echo off

set script=.\scripts\local\base\setupAndTest.ts

echo Running script "%script%" in hardhat isolated environment...

npx hardhat run %script% --network hardhat
