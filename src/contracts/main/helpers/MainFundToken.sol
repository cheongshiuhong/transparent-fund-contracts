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
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Code
import "../../../interfaces/main/helpers/IMainFundToken.sol";
import "./MainFundHelper.sol";

/**
 * @title MainFundToken
 * @author Translucent
 *
 * @notice Contract for the main fund's token.
 */
contract MainFundToken is ERC20, MainFundHelper, IMainFundToken {
    /** Constructor */
    constructor(
        address fundAddress,
        string memory name,
        string memory symbol,
        address initialAccount,
        uint256 initialAmount
    ) ERC20(name, symbol) MainFundHelper(fundAddress) {
        _mint(initialAccount, initialAmount);
    }

    function mint(address account, uint256 amount) external {
        // Only callable by the front office, accounting, or fund contracts
        require(
            _msgSender() == address(getFund().getFrontOffice())
                || _msgSender() == address(getFund().getAccounting())
                || _msgSender() == getFundAddress(),
            "MainFundToken: caller is not the fund, front office, or accounting contract"
        );
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        // Only callable by the front office, accounting, or fund contracts
        require(
            _msgSender() == address(getFund().getFrontOffice())
                || _msgSender() == address(getFund().getAccounting())
                || _msgSender() == getFundAddress(),
            "MainFundToken: caller is not the fund, front office, or accounting contract"
        );
        _burn(account, amount);
    }
}
