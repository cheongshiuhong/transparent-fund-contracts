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
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Code
import "../../../lib/Decimals.sol";
import "../../../lib/ValuationHelpers.sol";
import "../../../lib/FrontOfficeHelpers.sol";
import "../../../interfaces/main/helpers/IMainFundToken.sol";
import "../../../interfaces/main/helpers/IAccounting.sol";
import "../../../interfaces/main/helpers/IIncentivesManager.sol";
import "../../../interfaces/main/helpers/incentives/IIncentive.sol";
import "../../../interfaces/main/helpers/IFrontOfficeParameters.sol";
import "../../../interfaces/main/helpers/IFrontOffice.sol";
import "./MainFundPausableHelper.sol";

import "hardhat/console.sol";

/**
 * @title FrontOffice
 * @author Translucent
 *
 * @notice Contract for the main fund's front office department.
 */
contract FrontOffice is ReentrancyGuard, MainFundPausableHelper, IFrontOffice {
    /** Libraries */
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IMainFundToken;
    using Decimals for Decimals.Number;
    using FrontOfficeHelpers for FrontOfficeHelpers.Request;
    using FrontOfficeHelpers for FrontOfficeHelpers.Queue;

    /** Withdrawal state struct */
    struct WithdrawalState {
        uint256 maxValuePerPeriod;
        uint256 blocksPerPeriod;
        uint256 currentBlock;
        uint256 currentValue;
    }

    /** States */
    mapping(address => uint256) private _availableWithdrawalAmounts;
    mapping(address => FrontOfficeHelpers.Queue) private _depositsQueues;
    mapping(address => FrontOfficeHelpers.Queue) private _withdrawalsQueues;
    mapping(address => RequestAccessor[]) private _requestsAccessors;

    /** Parameters */
    IFrontOfficeParameters private immutable _parameters;

    /** Constructor  */
    constructor(
        address fundAddress,
        address parametersAddress
    ) MainFundPausableHelper(fundAddress) {
        _parameters = IFrontOfficeParameters(parametersAddress);
    }

    /** Internal modifiers */
    modifier onlyAllowedTokens(address tokenAddress) {
        _parameters.requireAllowedToken(tokenAddress);
        _;
    }

    /******************************************/
    /** Functions to facilitate user requests */
    /******************************************/
    /**
     * Gets the number of user requests for a user.
     *
     * @param - The address of the user to lookup.
     * @return - The users's number of requests.
     */
    function getUserRequestCount(
        address userAddress
    ) public view override returns (uint256) {
        return _requestsAccessors[userAddress].length;
    }

    /**
     * Gets a user request with the accessor.
     *
     * @param accessor - The accessor to lookup.
     * @return - The user's request copied into memory.
     */
    function getUserRequestByAccessor(
        RequestAccessor memory accessor
    ) external view override returns (FrontOfficeHelpers.Request memory) {
        return _getUserRequestByAccessor(accessor);
    }

    /**
     * Internal fuction to get the reference to a user request with the accessor.
     *
     * @param accessor - The accessor to lookup. 
     * @return - The reference to the user request in storage.
     */
    function _getUserRequestByAccessor(
        RequestAccessor memory accessor
    ) internal view returns (FrontOfficeHelpers.Request storage) {
        return accessor.isDeposit
            ? _depositsQueues[accessor.token].requests[accessor.queueNumber]
            : _withdrawalsQueues[accessor.token].requests[accessor.queueNumber];
    }

    /**
     * Gets a user request with the index.
     *
     * @param userAddress - The address of the user to lookup.
     * @param index - The index to lookup.
     * @return - The request accessor copied into memory.
     * @return - The user request copied into memory.
     */
    function getUserRequestByIndex(
        address userAddress,
        uint256 index
    ) external view override returns (
        RequestAccessor memory,
        FrontOfficeHelpers.Request memory
    ) {
        return _getUserRequestByIndex(userAddress, index);
    }

    /**
     * Internal function to get the reference to a user request with the index.
     *
     * @param userAddress - The address of the user to lookup.
     * @param index - The index to lookup.
     * @return - The request accessor copied into memory.
     * @return - The reference to the user request in storage.
     */
    function _getUserRequestByIndex(
        address userAddress,
        uint256 index
    ) internal view returns (
        RequestAccessor memory,
        FrontOfficeHelpers.Request storage
    ) {
        RequestAccessor memory accessor = _requestsAccessors[userAddress][index];
        return (accessor, _getUserRequestByAccessor(accessor));
    }

    /**
     * Gets the length of the deposits queue.
     *
     * @param tokenAddress - The address of the token to lookup.
     * @return - The length of the deposits queue for the input token.
     */
    function getDepositsQueueLength(
        address tokenAddress
    ) external view override returns (uint256) {
        return _depositsQueues[tokenAddress].length();
    }

    /**
     * Gets the length of the withdrawals queue.
     *
     * @param tokenAddress - The address of the token to lookup.
     * @return - The length of the withdrawals queue for the input token.
     */
    function getWithdrawalsQueueLength(
        address tokenAddress
    ) external view override returns (uint256) {
        return _depositsQueues[tokenAddress].length();
    }

    /**
     * Creates a request for a deposit.
     *
     * @param tokenAddress - The address of the token to deposit.
     * @param amountIn - The amount of the token to deposit.
     * @param minAmountOut - The minimum amount of fund tokens to receive.
     * @param blockDeadline - The latest block of execution for the deposit.
     * @param incentiveAddress - The address of the incentive if any (0x0 if none).
     */
    function requestDeposit(
        address tokenAddress,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 blockDeadline,
        address incentiveAddress
    ) external nonReentrant whenNotPaused override {
        // Require that the token is an allowed token
        _parameters.requireAllowedToken(tokenAddress);

        // Require that user has no pending requests
        uint256 requestCount = getUserRequestCount(_msgSender());
        if (requestCount > 0) {
            FrontOfficeHelpers.Request storage request;
            (, request) = _getUserRequestByIndex(_msgSender(), requestCount - 1);
            require(
                !request.isPending(),
                "FrontOffice: user already has a pending request"
            );
        }

        // Require that the incentive is valid for the user or not applicable
        IIncentivesManager.ValidityCode validityCode = getFund()
            .getIncentivesManager()
            .checkValidity(incentiveAddress, _msgSender());

        require(
            validityCode == IIncentivesManager.ValidityCode.VALID
                || validityCode == IIncentivesManager.ValidityCode.NOT_APPLICABLE,
            "FrontOffice: incentive is invalid or does not apply to user"
        );

        // Transfer the tokens in
        IERC20Metadata(tokenAddress).safeTransferFrom(
            _msgSender(), address(this), amountIn
        );

        // Enqueue the request
        uint256 queueNumber = _depositsQueues[tokenAddress].push(
            _msgSender(), amountIn, minAmountOut, blockDeadline, incentiveAddress
        );

        // Push the accessor into the user's accessors array
        _requestsAccessors[_msgSender()].push(
            RequestAccessor({
                isDeposit: true,
                token: tokenAddress,
                queueNumber: queueNumber
            })
        );
    }

    /**
     * Creates a request for a withdrawal.
     *
     * @param tokenAddress - The address of the token to withdraw.
     * @param amountIn - The amount of fund tokens to return.
     * @param minAmountOut - The minimum amount of the token to receive.
     * @param blockDeadline - The latest block of execution for the withdrawal.
     */
    function requestWithdrawal(
        address tokenAddress,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 blockDeadline
    ) external nonReentrant whenNotPaused override {
        // Require that the token is an allowed token
        IFrontOfficeParameters parameters = _parameters;
        parameters.requireAllowedToken(tokenAddress);

        // Require that user has no pending requests
         uint256 requestCount = getUserRequestCount(_msgSender());
        if (requestCount > 0) {
            FrontOfficeHelpers.Request storage request;
            (, request) = _getUserRequestByIndex(_msgSender(), requestCount - 1);

            require(
                !request.isPending(),
                "FrontOffice: user already has a pending request"
            );
        }

        // Require that single withdrawal amount is not greater than max parameter
        require(
            amountIn <= parameters.getMaxSingleWithdrawalFundTokenAmount(),
            "FrontOffice: withdarawal amount too large"
        );

        // Transfer the fund tokens in
        getFund().getFundToken().safeTransferFrom(
            _msgSender(), address(this), amountIn
        );

        // Enqueue the request
        uint256 queueNumber = _withdrawalsQueues[tokenAddress].push(
            _msgSender(), amountIn, minAmountOut, blockDeadline, address(0)
        );

        // Push the accessor into the user's accessors array
        _requestsAccessors[_msgSender()].push(
            RequestAccessor({
                isDeposit: false,
                token: tokenAddress,
                queueNumber: queueNumber
            })
        );
    }

    /**
     * Cancels the latest pending request.
     */
    function cancelLatestRequest() external
        nonReentrant
        whenNotPaused
        override
    {
        // Require that user has at least 1 request
        uint256 requestCount = getUserRequestCount(_msgSender());
        require(requestCount > 0, "FrontOffice: user has no requests");

        // Get the reference to the latest request
        RequestAccessor memory accessor;
        FrontOfficeHelpers.Request storage request;
        (accessor, request) = _getUserRequestByIndex(
            _msgSender(), requestCount - 1
        );

        // Will revert internally if the latest request is not pending
        request.setCancelled();

        // Return the tokens
        IERC20Metadata(accessor.token).safeTransfer(
            _msgSender(), request.amountIn
        );
    }

    /**
     * Redeem tokens sent in from failed requests.
     *
     * @param indexes - The indexes of the failed requests in the user's array.
     */
    function redeemFromFailedRequests(
        uint256[] calldata indexes
    ) external nonReentrant {
        // Get the reference to the fund token
        IMainFundToken fundToken = getFund().getFundToken();

        RequestAccessor memory accessor;
        FrontOfficeHelpers.Request storage request;
        for (uint i = 0; i < indexes.length; i++) {
            (accessor, request) = _getUserRequestByIndex(_msgSender(), indexes[i]);

            // Skip if not failed
            if (!request.isFailed()) continue;

            // Deposits - return the deposited tokens
            if (accessor.isDeposit)
                IERC20Metadata(accessor.token).safeTransfer(
                    request.user, request.amountIn
                );

            // Withdrawals - return the deposited fund tokens
            else
                fundToken.safeTransfer(request.user, request.amountIn);
        }
    }

    /***************************************************************/
    /** Functions to facilitate the processing of requests (tasks) */
    /***************************************************************/
    /**
     * Processes the deposits as a task.
     *
     * @notice We do not return tokens on a failed request here,
     *         they are redeemed by the user under `redeemFromFailedRequests`.
     *
     * @param tokenAddress - The address of the token to process deposits for.
     * @param maxRequestsToProcess - The maximum number of requests to process.
     */
    function processDeposits(
        address tokenAddress,
        uint256 maxRequestsToProcess // Limits txn size and allows batching
    ) external nonReentrant override {
        // Require that the token is an allowed token
        // Favour this over modifier to prevent double reading of `_parameters`
        IFrontOfficeParameters parameters = _parameters;
        parameters.requireAllowedToken(tokenAddress);

        // Only callable by the CAO's task runner
        getFund().getCAO().requireCAOTaskRunner(_msgSender());

        // Load the working data into memory
        DepositsWorking memory working = _loadDepositsWorking(
            tokenAddress, parameters
        );

        // Get the reference to the queue and compute the length for iterating
        FrontOfficeHelpers.Queue storage queue = _depositsQueues[tokenAddress];

        // Compute the length for iterating
        uint256 numRequestsToProcess = _min(maxRequestsToProcess, queue.length());

        // Iteratively process the deposits
        FrontOfficeHelpers.Request storage requestRef; // Reference to update status
        FrontOfficeHelpers.Request memory request; // Memory for cheaper attribute reading
        for (uint256 i = 0; i < numRequestsToProcess; i++) {
            requestRef = queue.front();
            request = requestRef;

            // Skip if request is not pending
            if (!request.isPending()) { queue.pop(); continue; }

            // Fail the request if deadline is over
            if (block.number > request.blockDeadline) {
                requestRef.setExpired();
                queue.pop();
                continue;
            }

            // Compute the output amount
            uint256 computedAmountOut =
                Decimals.Number(request.amountIn, working.token.decimals)
                    .mul(working.token.price)
                    .scaleDecimals(18)
                    .div(working.fundToken.price)
                    .value;

            // Fail the request if output amount is less than minimum threshold
            if (computedAmountOut < request.minAmountOut) {
                requestRef.setInsufficientOutput(computedAmountOut);
                queue.pop();
                continue;
            }

            // Let incentives manager handle the minting and depositing
            // into the incentive contract directly if applicable
            IIncentivesManager.ValidityCode validityCode;
            validityCode = working.incentivesManager.checkValidity(
                request.incentive, request.user
            );

            // Handle errors
            if (validityCode == IIncentivesManager.ValidityCode.NOT_FOUND)
                requestRef.setIncentiveNotFound(computedAmountOut);
            else if (validityCode == IIncentivesManager.ValidityCode.NOT_QUALIFIED)
                requestRef.setIncentiveNotQualified(computedAmountOut);

            // Perform regular deposit by minting if no incentive applicable
            else if (validityCode == IIncentivesManager.ValidityCode.NOT_APPLICABLE) {
                // Mint the fund tokens to the user
                working.fundToken.token.mint(request.user, computedAmountOut);

                // Set to successful and record the amount to send to the fund
                requestRef.setSuccessful(computedAmountOut);
                working.amountTokensToSendToFund += request.amountIn;
            }

            // Mint directly into the incentive if valid
            else if (validityCode == IIncentivesManager.ValidityCode.VALID) {
                // Record the direct deposit into the incentive contract
                IIncentive(request.incentive)
                    .recordDirectDeposit(request.user, computedAmountOut);

                // Mint the fund tokens directly into the incentive address
                working.fundToken.token.mint(request.incentive, computedAmountOut);

                // Set to successful and record the amount to send to the fund
                requestRef.setSuccessful(computedAmountOut);
                working.amountTokensToSendToFund += request.amountIn;
            }

            // If not handled --> set unhandled failure
            else { requestRef.setUnhandled(); }

            // Pop at the end regardless
            queue.pop();
        }

        // Record with accounting the amount of fund tokens minted
        working.accounting.recordDeposits(
            // Deposit value is the number of tokens x token price
            Decimals.Number(working.amountTokensToSendToFund, 18)
                .mul(working.token.price)
                .value,
            // The difference of the supply now vs what was
            // initially recorded is the amount that was minted
            working.fundToken.token.totalSupply() - working.fundToken.supply
        );

        // Settle the deposits by transferring the amount to the fund
        working.token.token.safeTransfer(
            getFundAddress(), working.amountTokensToSendToFund
        );
    }

    /**
     * Processes the withdrawals as a task.
     *
     * @dev maxWithdrawalAmount is determined by the allowance from the fund.
     *
     * @notice We do not return tokens on a failed request here,
     *         they are redeemed by the user under `redeemFromFailedRequests`.
     *
     * @param tokenAddress - The address of the token to process deposits for.
     * @param maxRequestsToProcess - The maximum number of requests to process.
     */
    function processWithdrawals(
        address tokenAddress,
        uint256 maxRequestsToProcess // Limits txn size and allows batching
    ) external nonReentrant override {
        // Require that the token is an allowed token
        // Favour this over modifier to prevent double reading of `_parameters`
        IFrontOfficeParameters parameters = _parameters;
        parameters.requireAllowedToken(tokenAddress);

        // Only callable by the CAO's task runner
        getFund().getCAO().requireCAOTaskRunner(_msgSender());

        // Load the working data into memory
        WithdrawalsWorking memory working = _loadWithdrawalsWorking(
            tokenAddress, parameters
        );

        // Get the reference to the queue
        FrontOfficeHelpers.Queue storage queue = _withdrawalsQueues[tokenAddress];
 
        // Compute the length for iterating
        uint256 numRequestsToProcess = _min(maxRequestsToProcess, queue.length());

        // Iteratively process the withdrawals
        FrontOfficeHelpers.Request storage requestRef; // Reference to update status
        FrontOfficeHelpers.Request memory request; // Memory for cheaper attribute reading
        for (uint256 i = 0; i < numRequestsToProcess; i++) {
            requestRef = queue.front();
            request = requestRef;

            // Skip if request is not pending
            if (!request.isPending()) {
                queue.pop();
                continue;
            }

            // Fail the request if amount too large (perhaps on newly set parameter)
            if (request.amountIn > working.maxSingleWithdrawalFundTokenAmount) {
                requestRef.setAmountTooLarge();
                queue.pop();
                continue;
            }

            // Fail the request if deadline is over
            if (block.number > request.blockDeadline) {
                requestRef.setExpired();
                queue.pop();
                continue;
            }

            // Compute the amount out
            uint256 computedAmountOut = Decimals.Number(request.amountIn, 18)
                .mul(working.fundToken.price)
                .scaleDecimals(working.token.decimals)
                .div(working.token.price)
                .value;

            // Fail the request if output amount is less than minimum threshold
            if (computedAmountOut < request.minAmountOut) {
                requestRef.setInsufficientOutput(computedAmountOut);
                queue.pop();
                continue;
            }

            // Stop if we're at the max amount withdrawable
            if (working.amountWithdrawed + computedAmountOut
                > working.amountWithdrawable) {
                break;
            }

            // Default is success
            // Set to successful and transfer the tokens to the user
            requestRef.setSuccessful(computedAmountOut);
            working.amountWithdrawed += computedAmountOut;
            working.fundToken.token.burn(address(this), request.amountIn);
            working.token.token.safeTransferFrom(
                working.fundAddress, request.user, computedAmountOut
            );

            // Pop at the end
            queue.pop();
        }

        // Record with accounting the amount of fund tokens burned
        working.accounting.recordWithdrawals(
            // Withdrawal value is the number of tokens x token price
            Decimals.Number(working.amountWithdrawed, working.token.decimals)
                .mul(working.token.price)
                .value,
            // The difference of what was initially recorded and
            // the supply now is the amount that was burned
            working.fundToken.supply - working.fundToken.token.totalSupply()
        );
    }

    /****************************************************/
    /** Structs to holding working references/variables */
    /** to avoid stack too deep errors (max = 16 vars)  */
    /****************************************************/
    struct TokenWorking {
        IERC20Metadata token;
        uint8 decimals;
        Decimals.Number price;
    }

    struct FundTokenWorking {
        IMainFundToken token;
        uint256 supply;
        Decimals.Number price;
    }

    struct DepositsWorking {
        TokenWorking token;
        FundTokenWorking fundToken;
        IAccounting accounting;
        IIncentivesManager incentivesManager;
        uint256 amountTokensToSendToFund;
    }

    struct WithdrawalsWorking {
        TokenWorking token;
        FundTokenWorking fundToken;
        IAccounting accounting;
        address fundAddress;
        uint256 maxSingleWithdrawalFundTokenAmount;
        uint256 amountWithdrawable;
        uint256 amountWithdrawed;
    }

    /********************************************/
    /** Internal functions to load the workings */
    /********************************************/
    /**
     * Internal function to load the working requried for processing deposits.
     *
     * @param tokenAddress - The address of the token to be processed.
     * @return - The deposits working struct.
     */
    function _loadDepositsWorking(
        address tokenAddress,
        IFrontOfficeParameters parameters
    ) internal view returns (DepositsWorking memory) {
        IERC20Metadata token = IERC20Metadata(tokenAddress);
        IMainFund fund = getFund();
        IMainFundToken fundToken = fund.getFundToken();
        IAccounting fundAccounting = fund.getAccounting();

        return DepositsWorking({
            token: TokenWorking({
                token: token,
                decimals: token.decimals(),
                price: ValuationHelpers.getOraclePrice(
                    parameters.getAllowedTokenOracle(tokenAddress)
                )
            }),
            fundToken: FundTokenWorking({
                token: fundToken,
                supply: fundToken.totalSupply(),
                price: fundAccounting.getFundTokenPrice()
            }),
            accounting: fundAccounting,
            incentivesManager: fund.getIncentivesManager(),
            amountTokensToSendToFund: 0
        });
    }

    /**
     * Internal function to load the working requried for processing withdrawals.
     *
     * @param tokenAddress - The address of the token to be processed.
     * @return - The withdrawals working struct.
     */
    function _loadWithdrawalsWorking(
        address tokenAddress,
        IFrontOfficeParameters parameters
    ) internal view returns (WithdrawalsWorking memory) {
        IERC20Metadata token = IERC20Metadata(tokenAddress);
        IMainFund fund = getFund();
        IMainFundToken fundToken = fund.getFundToken();
        IAccounting fundAccounting = fund.getAccounting();

        return WithdrawalsWorking({
            token: TokenWorking({
                token: token,
                decimals: token.decimals(),
                price: ValuationHelpers.getOraclePrice(
                    parameters.getAllowedTokenOracle(tokenAddress)
                )
            }),
            fundToken: FundTokenWorking({
                token: fundToken,
                supply: fundToken.totalSupply(),
                price: fundAccounting.getFundTokenPrice()
            }),
            accounting: fundAccounting,
            fundAddress: address(fund),
            maxSingleWithdrawalFundTokenAmount:
                parameters.getMaxSingleWithdrawalFundTokenAmount(),
            amountWithdrawable: _min(
                token.allowance(address(fund), address(this)),
                token.balanceOf(address(fund))
            ),
            amountWithdrawed: 0
        });
    }

    /******************************/
    /** Internal helper functions */
    /******************************/
    /**
     * Internal helper function to get the min of two values.
     *
     * @param val1 - The first value.
     * @param val2 - The second value.
     * @return - The smaller of both values.
     */
    function _min(uint256 val1, uint256 val2) internal pure returns (uint256) {
        return val1 < val2 ? val1 : val2;
    }
}
