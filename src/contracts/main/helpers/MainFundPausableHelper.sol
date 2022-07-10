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
import "@openzeppelin/contracts/security/Pausable.sol";

// Code
import "@openzeppelin/contracts/utils/Context.sol";
import "../../../interfaces/main/cao/ICAO.sol";
import "../../../interfaces/main/IMainFund.sol";
import "./MainFundHelper.sol";

/**
 * @title MainFundPausableHelper
 * @author Translucent
 *
 * @notice Base contract for main fund pausable helpers to inherit from,
 *         providing reference to the fund contract.
 */
abstract contract MainFundPausableHelper is Context, Pausable, MainFundHelper {
    /** Constructor */
    constructor(address fundAddress) MainFundHelper(fundAddress) {}

    /*******************************/
    /** Functions to pause/unpause */
    /*******************************/
    /**
     * Provides access of the internal pause function to the CAO's token holders.
     */
    function pause() external {
        // Require that the caller is a current cao token holder to pause
        getFund().getCAO().requireCAOTokenHolder(_msgSender());
        _pause();
    }

    /**
     * Provides access of the internal unpause function to the CAO.
     */
    function unpause() external {
        // Only callable by the CAO through governance if already set
        getFund().getCAO().requireCAOGovernance(_msgSender());
        _unpause();
    }
}
