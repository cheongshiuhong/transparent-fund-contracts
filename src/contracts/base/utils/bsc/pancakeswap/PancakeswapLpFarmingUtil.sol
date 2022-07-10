/*
    Copyright 2022 Translucent.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache-2.0
*/

pragma solidity ^0.8.12;

// External libraries
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Code
import "./Interfaces.sol";


/**
 * @title PancakeswapLpFarmingUtil
 * @author Translucent
 *
 * @notice Provides utils to add liquidity and farm the received LP tokens.
 */
contract PancakeswapLpFarmingUtil {
    /** Libraries */
    using SafeERC20 for IERC20;

    /** Immutable addresses */
    IPancakeswapRouter public immutable _router;
    IPancakeswapMasterChefV2 public immutable _masterChefV2;
    
    constructor(address routerAddress, address masterChefV2Address) {
        _router = IPancakeswapRouter(routerAddress);
        _masterChefV2 = IPancakeswapMasterChefV2(masterChefV2Address);
    }

    struct FarmTokenAndETHArgs {
        address token;
        uint256 amountToken;
        uint256 amountETH;
        uint256 amountTokenMin;
        uint256 amountETHMin;
        uint256 pid;
        bool farmAllBalance;
    }

    /**
     * Helper to provider liquidity of token + ETH and deposit.
     *
     * @param - The args struct.
     */
    function farmTokenAndETH(
        FarmTokenAndETHArgs calldata args
    ) external returns (uint256, uint256, uint256) {
        // Add liquidity
        IERC20(args.token).safeIncreaseAllowance(address(_router), args.amountToken);
        (
            uint256 amountToken,
            uint256 amountETH,
            uint256 amountToFarm
        ) = _router.addLiquidityETH{ value: args.amountETH }(
            args.token,          // token
            args.amountToken,    // amonutTokenDesire
            args.amountTokenMin, // amountTokenMin
            args.amountETHMin,   // amountETHDesired
            address(this),       // to
            block.timestamp + 5 // Force a greater timestamp so no deadline
        );
        IERC20(args.token).safeApprove(address(_router), 0);

        // Retrieve the pair address
        address pairAddress = _masterChefV2.lpToken(args.pid);

        // Compute the amount to farm based on the input
        // Farm only what was received from adding liquidity by default
        // Override and farm entire balance if input wants it
        if (args.farmAllBalance) {
            amountToFarm = IERC20(pairAddress).balanceOf(address(this));            
        }

        // Deposit into materchef
        IERC20(pairAddress).safeIncreaseAllowance(address(_masterChefV2), amountToFarm);
        _masterChefV2.deposit(args.pid, amountToFarm);
        IERC20(pairAddress).safeApprove(address(_masterChefV2), 0);

        return (amountToken, amountETH, amountToFarm);
    }

    struct FarmTokensArgs {
        address tokenA;
        address tokenB;
        uint256 amountA;
        uint256 amountB;
        uint256 amountAMin;
        uint256 amountBMin;
        uint256 pid;
        bool farmAllBalance;
    }

    /**
     * Helper to provide liquidity of tokens and deposit LPs.
     *
     * @param args - The args struct.
     */
    function farmTokens(
        FarmTokensArgs calldata args
    ) external returns (uint256, uint256, uint256) {

        // Add liquidity
        IERC20(args.tokenA).safeIncreaseAllowance(address(_router), args.amountA);
        IERC20(args.tokenB).safeIncreaseAllowance(address(_router), args.amountB);
        (
            uint256 amountA,
            uint256 amountB,
            uint256 amountToFarm
        ) = _router.addLiquidity(
            args.tokenA,      // token0
            args.tokenB,      // token1
            args.amountA,     // amountTokenDesired
            args.amountB,     // amountTokenDesired
            args.amountAMin,  // amountTokenAMin (95%)
            args.amountBMin,  // amountBMin (95%)
            address(this),      // to
            block.timestamp + 5 // Force a greater timestamp so no deadline
        );
        IERC20(args.tokenA).safeApprove(address(_router), 0);
        IERC20(args.tokenB).safeApprove(address(_router), 0);

        // Retrieve the pair address
        address pairAddress = _masterChefV2.lpToken(args.pid);

        // Compute the amount to farm based on the input
        // Farm only what was received from adding liquidity by default
        // Override and farm entire balance if input wants it
        if (args.farmAllBalance) {
            amountToFarm = IERC20(pairAddress).balanceOf(address(this));
        }

        // Deposit into materchef
        IERC20(pairAddress).safeIncreaseAllowance(address(_masterChefV2), amountToFarm);
        _masterChefV2.deposit(args.pid, amountToFarm);
        IERC20(pairAddress).safeApprove(address(_masterChefV2), 0);

        return (amountA, amountB, amountToFarm);
    }

    struct UnfarmTokenAndETHArgs {
        address token;
        uint256 amountLp;
        uint256 amountTokenMin;
        uint256 amountETHMin;
        uint256 pid;
    }

    /**
     * Helper to withdraw and remove liquidity of token+ETH.
     *
     * @param args - The args struct.
     */
    function unfarmTokenAndETH(
        UnfarmTokenAndETHArgs calldata args
    ) external returns (uint256, uint256) {
        // Withdraw from materchef
        _masterChefV2.withdraw(args.pid, args.amountLp);

        // Get the pair address
        address pairAddress = _masterChefV2.lpToken(args.pid);

        // Remove liquidity
        IERC20(pairAddress).safeIncreaseAllowance(address(_router), args.amountLp);
        (uint256 amountToken, uint256 amountETH) = _router.removeLiquidityETH(
            args.token,          // token
            args.amountLp,       // liquidity
            args.amountTokenMin, // amountTokenMin
            args.amountETHMin,   // amountTokenAMin
            address(this),         // to
            block.timestamp + 5 // Force a greater timestamp so no deadline
        );
        IERC20(pairAddress).safeApprove(address(_router), 0);

        // Decode the response
        return (amountToken, amountETH);
    }

    struct UnfarmTokensArgs {
        address tokenA;
        address tokenB;
        uint256 amountLp;
        uint256 amountAMin;
        uint256 amountBMin;
        uint256 pid;
    }

    /**
     * Helper to withdraw and remove liquidity of tokens.
     *
     * @param args - The args struct.
     */
    function unfarmTokens(
        UnfarmTokensArgs calldata args
    ) external returns (uint256, uint256) {
        // Withdraw from materchef
        _masterChefV2.withdraw(args.pid, args.amountLp);

        // Get the pair address
        address pairAddress = _masterChefV2.lpToken(args.pid);

        // Remove liquidity
        IERC20(pairAddress).safeIncreaseAllowance(address(_router), args.amountLp);
        (uint256 amountA, uint256 amountB) = _router.removeLiquidity(
            args.tokenA,     // token
            args.tokenB,     // token
            args.amountLp,   // liquidity
            args.amountAMin, // amountAMin
            args.amountBMin, // amountBMin
            address(this),     // to
            block.timestamp + 5 // Force a greater timestamp so no deadline
        );
        IERC20(pairAddress).safeApprove(address(_router), 0);

        // Decode the response
        return (amountA, amountB);
    }
}
