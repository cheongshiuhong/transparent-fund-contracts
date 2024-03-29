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

// Code
import "../../../../lib/Decimals.sol";

/**
 * @title IHumanResources
 * @author Translucent
 *
 * @notice Interface for the CAO's human resources.
 */
interface IHumanResources {
    /********************************************/
    /** Structs to track the employee's details */
    /********************************************/
    struct EmployeeDetails {
        uint256 remunerationPerBlock;
        uint256 remunerationAccrued;
        uint256 lastAccruedBlock;
    }

    /*********************************/
    /** Functions to read the states */
    /*********************************/
    function getEmployeeCount() external view returns (uint256);
    function getEmployeeByIndex(
        uint256 employeeIndex
    ) external view returns (address, EmployeeDetails memory);
    function getEmployeeByAddress(
        address employeeAddress
    ) external view returns (EmployeeDetails memory);
    function getEmployeeCurrentRemuneration(
        address employeeAddress
    ) external view returns (Decimals.Number memory);
    function getUnredeemedExEmployees() external view returns (
        address[] memory,
        EmployeeDetails[] memory
    );

    /***********************************/
    /** Functions to modify the states */
    /***********************************/
    function addEmployee(
        address employeeAddress,
        uint256 remunerationPerBlock
    ) external;
    function updateEmployee(
        address employeeAddress,
        uint256 remunerationPerBlock
    ) external;
    function removeEmployee(address employeeAddress) external;
    function clearEmployeeRemuneration(address employeeAddress) external;
}
