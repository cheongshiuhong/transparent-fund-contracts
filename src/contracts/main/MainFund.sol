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
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Code
import "../../interfaces/main/cao/ICAO.sol";
import "../../interfaces/main/helpers/IMainFundToken.sol";
import "../../interfaces/main/helpers/IAccounting.sol";
import "../../interfaces/main/helpers/IFrontOffice.sol";
import "../../interfaces/main/helpers/IIncentivesManager.sol";
import "../../interfaces/main/IMainFund.sol";
import "../base/BaseFund.sol";

/**
 * @title MainFund
 * @author Translucent
 *
 * @notice The main fund contract that facilitates front-facing features.
 */
contract MainFund is Context, BaseFund, IMainFund {
    /** Libraries */
    using SafeERC20 for IERC20;

    /** References */
    ICAO private _cao;
    IMainFundToken private _token;
    IAccounting private _accounting;
    IFrontOffice private _frontOffice;
    IIncentivesManager private _incentivesManager;

    /**
     * Sets the helpers for the main fund.
     *
     * @param caoAddress - The address of the cao to set.
     * @param tokenAddress - The address of the fund token to set.
     * @param accountingAddress - The address of the accounting to set.
     * @param frontOfficeAddress - The address of the front office to set.
     * @param incentivesManagerAddress - The address of the incentives manager to set.
     */
    function setMainFundHelpers(
        address caoAddress,
        address tokenAddress,
        address accountingAddress,
        address frontOfficeAddress,
        address incentivesManagerAddress
    ) external override {
        // If already set, run checks first
        if (address(_cao) != address(0)) {
            _cao.requireCAOGovernance(_msgSender());
            require(
                caoAddress != address(0)
                    && tokenAddress != address(0)
                    && accountingAddress != address(0)
                    && frontOfficeAddress != address(0)
                    && incentivesManagerAddress != address(0),
                "MainFund: cannot migrate any of the helpers to the 0x0 address"
            );
        }

        // Set the helpers
        _cao = ICAO(caoAddress);
        _token = IMainFundToken(tokenAddress);
        _accounting = IAccounting(accountingAddress);
        _frontOffice = IFrontOffice(frontOfficeAddress);
        _incentivesManager = IIncentivesManager(incentivesManagerAddress);
    }

    /****************************************/
    /** Functions to get the fund's helpers */
    /****************************************/
    function getCAO() external view override returns (ICAO) {
        return _cao;
    }
    function getFundToken() external view override returns (IMainFundToken) {
        return _token;
    }
    function getAccounting() external view override returns (IAccounting) {
        return _accounting;
    }
    function getFrontOffice() external view override returns (IFrontOffice) {
        return _frontOffice;
    }
    function getIncentivesManager() external view override returns (IIncentivesManager) {
        return _incentivesManager;
    }

    /************************************************/
    /** Functions to facilitate withdrawals (tasks) */
    /************************************************/
    /**
     * Approves the front office to spend tokens for withdrawals.
     *
     * @dev No need to check if token is allowed since Front Office
     *      can only process withdrawals on allowed tokens.
     *
     * @param tokensAddresses - The addresses of the tokens to approve.
     * @param amounts - The amounts to approve for each token.
     */
    function approveFrontOfficeForWithdrawals(
        address[] calldata tokensAddresses,
        uint256[] calldata amounts
    ) external override {
        // Only callable by the CAO's task runner
        _cao.requireCAOTaskRunner(_msgSender());

        // Require valid input array lengths
        require(
            tokensAddresses.length == amounts.length,
            "MainFund: invalid array lengths"
        );

        // Approve each input token to be spent by front office for withdrawals
        address frontOfficeAddress = address(_frontOffice);
        for (uint256 i = 0; i < tokensAddresses.length; i++)
            IERC20(tokensAddresses[i]).approve(frontOfficeAddress, amounts[i]);
    }
}
