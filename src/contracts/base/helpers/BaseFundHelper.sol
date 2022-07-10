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

import "@openzeppelin/contracts/utils/Context.sol";
import "../../../interfaces/base/IBaseFund.sol";

/**
 * @title BaseFundHelper
 * @author Translucent
 *
 * @notice Base contract for helpers to inherit from,
 *         providing reference to the fund contract.
 */
abstract contract BaseFundHelper is Context {
    address private _fundAddress;

    /**
     * Sets the fund
     */
    constructor(address fundAddress) {
        _fundAddress = fundAddress;
    }

    /**
     * @dev Returns the address of the fund.
     */
    function getFundAddress() public view returns (address) {
        return _fundAddress;
    }

    /**
     * @dev Returns the address of the fund.
     */
    function getFund() public view returns (IBaseFund) {
        return IBaseFund(_fundAddress);
    }

    /**
     * @dev Throws if called by any account other than the fund.
     */
    modifier onlyFund() {
        require(_fundAddress == _msgSender(), "BaseFundHelper: caller is not the fund");
        _;
    }
}
