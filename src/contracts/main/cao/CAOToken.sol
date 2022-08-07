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
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

// Code
import "../../../lib/mappings/EnumerableAddressToAddressMap.sol";

/**
 * @title CAOToken
 * @author Translucent
 *
 * @notice CAO Token used for governance of the CAO.
 */
contract CAOToken is Ownable, ERC20Votes {
    /** Libraries */
    // using EnumerableAddressToAddressMap for EnumerableAddressToAddressMap.Map;
    using EnumerableSet for EnumerableSet.AddressSet;

    /** States */
    // Reverses the lookup of delegates
    mapping(address => EnumerableSet.AddressSet) private _delegateesToDelegators;

    /** Constructor */
    constructor(string memory name, string memory symbol) ERC20(name, symbol) ERC20Permit(name) {}

    /****************************************/
    /** Override ERC20 for custom behaviour */
    /****************************************/
    // Holders cannot transfer the token directly.
    function transfer(address, uint256) public pure override returns (bool) {
        revert("Token cannot be directly transferred. Go through the CAO to sell it instead.");
    }

    // Only the CAO can perform transfers of tokens.
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public onlyOwner override returns (bool) {
        // No need for allowances
        _transfer(from, to, amount);
        return true;
        // return super.transferFrom(from, to, amount);
    }

    // Only the CAO can mint
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // Only the CAO can burn
    function burn(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }

    /***************************************************************/
    /** Override delegate to only allow delegation to token-holder */
    /***************************************************************/
    // Run checks and update reverse mapping before performing the delegation
    function _delegate(
        address delegator,
        address delegatee
    ) internal override(ERC20Votes) {
        require(
            // Can only delegate to token holder or null address (remove delegation)
            balanceOf(delegatee) > 0 || delegatee == address(0),
            "CAOToken: cannot delegate to non-token holder"
        );

        // Unset the inverse mapping of any existing delegation
        address currentDelegatee = delegates(delegator);
        if (currentDelegatee != address(0)) {
            _delegateesToDelegators[currentDelegatee].remove(delegator);
        }

        // Set the inverse mapping of delegatee to delegator
        _delegateesToDelegators[delegatee].add(delegator);

        super._delegate(delegator, delegatee);
    }

    // Undelegate delegations to the `from` user if no longer a token holder
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Votes) {
        // If the transfer results in the `from` user to no longer be a token holder,
        // and the `from` user is currently being delegated to, remove the delegations
        // No iterations if not being delegated to.
        if (balanceOf(from) == 0) {
            address[] memory delegators = _delegateesToDelegators[from].values();
            for (uint i = 0; i < delegators.length; i++) {
                _delegate(delegators[i], address(0));
            }
        }

        super._afterTokenTransfer(from, to, amount);
    }

    /***********************************************************/
    /** The functions below are overrides required by Solidity */
    /***********************************************************/
    function _mint(
        address to,
        uint256 amount
    ) internal override(ERC20Votes) {
        super._mint(to, amount);
    }

    function _burn(
        address account,
        uint256 amount
    ) internal override(ERC20Votes) {
        super._burn(account, amount);
    }
}
