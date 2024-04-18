// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";

import "./interfaces/ITokenizedPointERC20.sol";

/**
 * @title MichiPointerMinter
 *     @dev Implementation of a minter contract to mint tokenized points to users.
 *     The user will initiate a request to tokenize points and transfer their
 *     Michi Wallet NFT to a locker. This contract may be deployed on a different
 *     chain than the Michi Wallet NFT.
 */
contract MichiPointsMinter is AccessControl {
    /// @notice Minter role
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Fulfilled request data parameters
    struct FulfilledRequest {
        address receiver;
        address[] tokenizedPointsAddresses;
        uint256 chainId;
        uint256 requestId;
        uint256[] amounts;
    }

    /// @notice fee taken upon tokenizing points
    uint256 public tokenizeFee;

    /// @notice precision denominator for fees
    uint256 public precision;

    /// @notice address that receives tokenize fees
    address public feeReceiver;

    /// @notice mapping of approved tokenized points token addresses
    mapping(address => bool) private approvedTokenizedPoints;

    /// @notice mapping of fulfilled requests by request id and chain initiated on
    mapping(uint256 => mapping(uint256 => FulfilledRequest)) public chainToRequestId;

    /// @notice mapping of fulfilled requests by chain
    mapping(uint256 => uint256[]) public fulfilledRequestsByChain;

    /// @notice mapping of total amount of tokenized points minted to users by tokenized points token address
    mapping(address => uint256) public userAmountMintedByTokenizedPoint;

    /// @notice mapping of total amount of fees taken by tokenized points token address
    mapping(address => uint256) public feesByTokenizedPoint;

    /// @notice error when array length is not matching
    error ArrayLengthMismatch();

    /// @notice error when unapproved token is inputted as parameter
    error UnapprovedToken(address token);

    /// @notice error when 0 tokens are requested to be minted
    error InvalidAmount(uint256 amount);

    /// @notice error when request can already been fulfilled
    error RequestAlreadyFulfilled(uint256 chainId, uint256 requestId);

    /// @notice error when tokenize fee is set too high
    error InvalidTokenizeFee(uint256 tokenizeFee);

    /// @notice error when approving an already approved token
    error TokenizedPointAlreadyApproved(address tokenizedPoint);

    /// @notice error when removing an unapproved token
    error TokenizedPointNotApproved(address tokenizedPoint);

    /// @notice event when a tokenize point request has been completed
    event RequestFulfilled(
        address receier, address[] tokenizedPoints, uint256 chainId, uint256 requestId, uint256[] amounts
    );

    /// @dev Constructor for MichiPointsMinter contract
    /// @param feeReceiver_ address of the fee receiver
    /// @param tokenizeFee_ tokenize fee
    /// @param precision_ precision denominator
    constructor(address feeReceiver_, uint256 tokenizeFee_, uint256 precision_) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);

        feeReceiver = feeReceiver_;
        tokenizeFee = tokenizeFee_;
        precision = precision_;
    }

    /// @dev Initiate tokenized points minting
    /// @param receiver address receiving the minted tokens
    /// @param tokensToMint array of tokens to mint
    /// @param amounts array of amounts to mint
    /// @param chainId chain that request was made on
    /// @param requestId id of request
    function mintTokenizedPoints(
        address receiver,
        address[] calldata tokensToMint,
        uint256[] calldata amounts,
        uint256 chainId,
        uint256 requestId
    ) external onlyRole(MINTER_ROLE) {
        if (tokensToMint.length != amounts.length) revert ArrayLengthMismatch();

        for (uint256 i = 0; i < tokensToMint.length; i++) {
            if (!approvedTokenizedPoints[tokensToMint[i]]) revert UnapprovedToken(tokensToMint[i]);
            if (amounts[i] == 0) revert InvalidAmount(amounts[i]);

            if (tokenizeFee == 0) {
                ITokenizedPointERC20(tokensToMint[i]).mint(receiver, amounts[i]);
                userAmountMintedByTokenizedPoint[tokensToMint[i]] += amounts[i];
            } else {
                uint256 fee = amounts[i] * tokenizeFee / precision;
                uint256 amountAfterFees = amounts[i] - fee;

                ITokenizedPointERC20(tokensToMint[i]).mint(receiver, amountAfterFees);
                ITokenizedPointERC20(tokensToMint[i]).mint(feeReceiver, fee);

                userAmountMintedByTokenizedPoint[tokensToMint[i]] += amountAfterFees;
                feesByTokenizedPoint[tokensToMint[i]] += fee;
            }
        }
        FulfilledRequest storage fulfilledRequest = chainToRequestId[chainId][requestId];
        if (fulfilledRequest.requestId != 0) revert RequestAlreadyFulfilled(chainId, requestId);

        fulfilledRequest.receiver = receiver;
        fulfilledRequest.tokenizedPointsAddresses = tokensToMint;
        fulfilledRequest.chainId = chainId;
        fulfilledRequest.requestId = requestId;
        fulfilledRequest.amounts = amounts;

        fulfilledRequestsByChain[chainId].push(requestId);

        emit RequestFulfilled(receiver, tokensToMint, chainId, requestId, amounts);
    }

    /// @dev Grant minter role
    /// @param user address to receive minter role
    function grantMinterRole(address user) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MINTER_ROLE, user);
    }

    /// @dev Revoke minter role
    /// @param user address to revoke minter role
    function revokeMinterRole(address user) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(MINTER_ROLE, user);
    }

    /// @dev Add approved tokenized point token address
    /// @param tokenizedPointAddress token address of tokenized point
    function addApprovedTokenizedPoint(address tokenizedPointAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (approvedTokenizedPoints[tokenizedPointAddress]) revert TokenizedPointAlreadyApproved(tokenizedPointAddress);
        approvedTokenizedPoints[tokenizedPointAddress] = true;
    }

    /// @dev Remove approval for tokenized point token address
    /// @param tokenizedPointAddress token address of tokenized point
    function removeTokenizedPoint(address tokenizedPointAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!approvedTokenizedPoints[tokenizedPointAddress]) revert TokenizedPointNotApproved(tokenizedPointAddress);
        approvedTokenizedPoints[tokenizedPointAddress] = false;
    }

    /// @dev Set new tokenize fee
    /// @param newTokenizeFee new tokenize fee
    function setTokenizeFee(uint256 newTokenizeFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newTokenizeFee > 500) revert InvalidTokenizeFee(newTokenizeFee);
        tokenizeFee = newTokenizeFee;
    }
}
