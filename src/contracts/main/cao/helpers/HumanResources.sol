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
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// Code
import "../../../../lib/Decimals.sol";
import "../../../../interfaces/main/cao/helpers/IHumanResources.sol";
import "../../../../interfaces/main/cao/ICAO.sol";
import "./CAOHelper.sol";

/**
 * @title HumanResources
 * @author Translucent
 *
 * @notice Contract for the CAO's human resources.
 */
contract HumanResources is CAOHelper, IHumanResources {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Decimals for Decimals.Number;

    /** Constants */
    uint8 public constant REMUNERATION_DECIMALS = 18;

    /** States */
    EnumerableSet.AddressSet private _employees;
    mapping(address => EmployeeDetails) private _employeesDetails;
    EnumerableSet.AddressSet private _unredeemedExEmployees;

    /** Events */
    event EmployeeAdded(address employeeAddress, uint256 remunerationPerBlock);
    event EmployeeUpdated(address employeeAddress, uint256 remunerationPerBlock);
    event EmployeeRemoved(address employeeAddress, uint256 remunerationAccrued);

    /** Constructor */
    constructor(address caoAddress) CAOHelper(caoAddress) {}

    /*********************************/
    /** Functions to read the states */
    /*********************************/
    /**
     * Gets the number of employees.
     *
     * @dev We refrain from returning the array directly since
     *      the number of employees might become large.
     *
     * @return - The number of employees.
     */
    function getEmployeeCount() external view override returns (uint256) {
        return _employees.length();
    }

    /**
     * Gets an employee by the index.
     *
     * @param employeeIndex - The index of the employee to lookup.
     * @return - The employee's address.
     * @return - The employee's details.
     */
    function getEmployeeByIndex(
        uint256 employeeIndex
    ) external view override returns (address, EmployeeDetails memory) {
        address employeeAddress = _employees.at(employeeIndex);
        return (employeeAddress,  _employeesDetails[employeeAddress]);
    }

    /**
     * Gets an employee by the address.
     *
     * @param - The address of the employee to lookup.
     * @return - The employee's details
     */
    function getEmployeeByAddress(
        address employeeAddress
    ) external view override returns (EmployeeDetails memory) {
        return _employeesDetails[employeeAddress];
    }

    /**
     * Function to get the accrued remuneration at the current block.
     *
     * @dev This is for the CAO's convenience.
     *
     * @param employeeAddress - The address of the employee to get for.
     * @return - The remuneration value as a Decimals.Number struct.
     */
    function getEmployeeCurrentRemuneration(
        address employeeAddress
    ) external view override returns (Decimals.Number memory) {
        // Return the call to the internal function with the reference
        return Decimals.Number({
            value: _computeEmployeeCurrentRemuneration(
                _employeesDetails[employeeAddress]
            ),
            decimals: REMUNERATION_DECIMALS
        });
    }

    /**
     * Function to get the unredeemed ex-employees with outstanding balances.
     *
     * @return - The array of the unredeemed ex-employees' details.
     */
    function getUnredeemedExEmployees()
        external
        view
        override
        returns (address[] memory, EmployeeDetails[] memory)
    {
        // Pull the addresses into memory
        address[] memory unredeemedExEmployees = _unredeemedExEmployees.values();

        // Iterate and populate the output
        EmployeeDetails[] memory output;
        output = new EmployeeDetails[](unredeemedExEmployees.length);
        for (uint i = 0; i < unredeemedExEmployees.length; i++) {
            output[i] = _employeesDetails[unredeemedExEmployees[i]];
        }
        
        return (unredeemedExEmployees, output);
    }


    /***********************************/
    /** Functions to modify the states */
    /***********************************/
    /**
     * Function to add an employee.
     *
     * @param employeeAddress - The address of the employee to add.
     * @param remunerationPerBlock - The remunerationPerBlock to set.
     */
    function addEmployee(
        address employeeAddress,
        uint256 remunerationPerBlock
    ) external override {
        // Only callable by the CAO through governance
        getCAO().requireCAOGovernance(_msgSender());

        // Require that this is a new employee
        require(
            !_employees.contains(employeeAddress),
            "HumanResources: employee already exists, use update instead"
        );

        // Add the employee
        _employees.add(employeeAddress);
        _employeesDetails[employeeAddress] = EmployeeDetails({
            remunerationPerBlock: remunerationPerBlock,
            remunerationAccrued: 0,
            lastAccruedBlock: block.number
        });

        // Emit the event
        emit EmployeeAdded(employeeAddress, remunerationPerBlock);
    }

    /**
     * Function to update an employee.
     *
     * @param employeeAddress - The address of the employee to update.
     * @param remunerationPerBlock - The remunerationPerBlock to set.
     */
    function updateEmployee(
        address employeeAddress,
        uint256 remunerationPerBlock
    ) external override {
        // Only callable by the CAO through governance
        getCAO().requireCAOGovernance(_msgSender());

        // Require that the employee exists
        require(
            _employees.contains(employeeAddress),
            "HumanResources: employee does not exist, use add instead"
        );

        // Get the reference to the details
        EmployeeDetails storage details = _employeesDetails[employeeAddress];

        // Accrue the past remuneration up to this point before updating
        details.remunerationAccrued = _computeEmployeeCurrentRemuneration(details);

        // Update the remuneration per block
        details.remunerationPerBlock = remunerationPerBlock;

        // Emit the event
        emit EmployeeUpdated(employeeAddress, remunerationPerBlock);
    }

    /**
     * Function to remove an employee.
     *
     * @notice We do NOT directly delete from the remunerations mapping
     *         to allow the ex-employees to redeem the outstanding remunerations
     *         but will no longer accrue any more remunerations.
     *
     * @param employeeAddress - The address of the employee to remove.
     */
    function removeEmployee(address employeeAddress) external override {
        // Only callable by the CAO through governance
        getCAO().requireCAOGovernance(_msgSender());

        // Require that the employee exists
        require(
            _employees.contains(employeeAddress),
            "HumanResources: employee does not exist"
        );

        // Compute the remuneration accrued to current block
        uint256 currentRemuneration = _computeEmployeeCurrentRemuneration(
            _employeesDetails[employeeAddress]
        );

        // Update the remuneration accrued and set future remunerationPerBlock to 0.
        _employeesDetails[employeeAddress] = EmployeeDetails({
            remunerationPerBlock: 0, // no longer accruing
            remunerationAccrued: currentRemuneration,
            lastAccruedBlock: block.number
        });

        // Remove the employee from the employees set
        _employees.remove(employeeAddress);

        // Add it to the unredeemed ex-employees if remuneration accrued not 0
        if (currentRemuneration > 0) _unredeemedExEmployees.add(employeeAddress);

        // Emit the event
        emit EmployeeRemoved(employeeAddress, currentRemuneration);
    }

    /**
     * Clear the accrued remuneration of an employee.
     *
     * @notice Called through governance if the CAO decides
     *         to not grant an employee any remuneration be it
     *         upon removal or just an operational decision .
     *
     * @param employeeAddress - The employee whose accrued remuneration to reset.
     */
    function clearEmployeeRemuneration(
        address employeeAddress
    ) external override {
        // Only callable by the CAO upon claiming
        getCAO().requireCAO(_msgSender());

        // Update the accrued amount and the accrued block
        _employeesDetails[employeeAddress] = EmployeeDetails({
            remunerationPerBlock: _employeesDetails[employeeAddress].remunerationPerBlock,
            remunerationAccrued: 0,
            lastAccruedBlock: block.number
        });

        // Clear from unredeemed ex-employees if its an ex-employee
        if (_unredeemedExEmployees.contains(employeeAddress))
            _unredeemedExEmployees.remove(employeeAddress);
    }

    /******************************/
    /** Internal helper functions */
    /******************************/
    /**
     * Internal function to compute the accrued remuneration at the current block.
     *
     * @param employeeDetails - The details of the employee to compute.
     */
    function _computeEmployeeCurrentRemuneration(
        EmployeeDetails storage employeeDetails
    ) internal view returns (uint256) {
        // Return the current remuneration + the newly accrued remuneration
        return employeeDetails.remunerationAccrued + (
            employeeDetails.remunerationPerBlock * (
                block.number - employeeDetails.lastAccruedBlock
            )
        );
    }
}
