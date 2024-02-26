// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "erc6551/interfaces/IERC6551Registry.sol";
import "tokenbound/src/AccountV3.sol";
import "tokenbound/src/AccountProxy.sol";

import "./interfaces/IMichiBackpack.sol";

contract MichiHelper is Ownable {
    using SafeERC20 for IERC20;

    /// @notice instance of Michi Backpack (NFT that represents 6551 wallet)
    IMichiBackpack public michiBackpack;

    /// @notice instance of ERC6551 Registry
    IERC6551Registry public erc6551Registry;

    /// @notice instance of current 6551 wallet implementation
    address public erc6551Implementation;

    /// @notice address that receives fees (if applicable)
    address public feeReceiver;

    uint256 public depositFee;

    uint256 public feePrecision;

    /// @notice tracks total deposits indexed by user and token
    mapping(address => mapping(address => uint256)) public depositsByAccountByToken;

    /// @notice tracks total deposits indexed by token
    mapping(address => uint256) public depositsByToken;

    /// @notice tracks total fees indexed by token
    mapping(address => uint256) public feesCollectedByToken;

    /// @notice tracks if token is approved to be deposited
    mapping(address => bool) public approvedToken;

    /// @notice array of approved tokens to be deposited
    address[] public listApprovedTokens;

    /// @notice emitted when a new Backpack is minted and corresponding 6551 wallet is initialized
    event BackpackCreated(address indexed sender, address indexed backpack);

    /// @notice emitted when a Backpack receives a deposit
    event Deposit(
        address indexed sender,
        address indexed receiver,
        address indexed token,
        uint256 amountAfterFees,
        uint256 feeTaken
    );

    /// @notice error returned when a user tries to deposit an unauthorized token
    error UnauthorizedToken(address token);

    /// @notice error returned when depositor is not the owner of 6551 wallet (safety precaution to prevent wrong deposits)
    error UnauthorizedUser(address user);

    /// @notice error returned when 6551 wallet owner is not sender
    error OwnerMismatch();

    /// @notice error returned when proposed deposit fee exceeds 5%
    error InvalidDepositFee(uint256 depositFee);

    /// @notice error returned when proposed fee recipient is zero address
    error InvalidFeeReceiver(address feeRecipient);

    /// @notice error returned when attempting to add an already approved token
    error TokenAlreadyApproved(address token);

    /// @notice error returned when attempting to remove an unapproved token
    error TokenNotApproved(address token);

    constructor(
        address erc6551Registry_,
        address erc6551Implementation_,
        address michiBackpack_,
        address feeReceiver_,
        uint256 depositFee_,
        uint256 feePrecision_
    ) {
        erc6551Registry = IERC6551Registry(erc6551Registry_);
        erc6551Implementation = erc6551Implementation_;
        michiBackpack = IMichiBackpack(michiBackpack_);
        feeReceiver = feeReceiver_;
        depositFee = depositFee_;
        feePrecision = feePrecision_;
    }

    function createBackpack(uint256 quantity) external payable {
        for (uint256 i = 0; i < quantity; i++) {
            uint256 currentIndex = michiBackpack.getCurrentIndex();
            michiBackpack.mint{value: msg.value}(msg.sender);
            bytes32 salt = bytes32(abi.encode(0));
            address payable newBackpack = payable(
                erc6551Registry.createAccount(
                    erc6551Implementation, salt, block.chainid, address(michiBackpack), currentIndex
                )
            );

            if (AccountV3(newBackpack).owner() != msg.sender) revert OwnerMismatch();
            emit BackpackCreated(msg.sender, newBackpack);
        }
    }

    function depositYT(address token, address backpack, uint256 amount, bool takeFee) external {
        if (AccountV3(payable(backpack)).owner() != msg.sender) revert UnauthorizedUser(msg.sender);
        uint256 fee;

        if (takeFee) {
            fee = amount * depositFee / feePrecision;
            IERC20(token).safeTransferFrom(msg.sender, feeReceiver, fee);
            IERC20(token).safeTransferFrom(msg.sender, backpack, amount - fee);

            depositsByAccountByToken[backpack][token] += amount - fee;
            depositsByToken[token] += amount - fee;
            feesCollectedByToken[token] += fee;
        } else {
            IERC20(token).safeTransferFrom(msg.sender, backpack, amount);
            depositsByAccountByToken[backpack][token] += amount;
            depositsByToken[token] += amount;
        }

        emit Deposit(msg.sender, backpack, token, amount - fee, fee);
    }

    function addApprovedToken(address token) external onlyOwner {
        if (approvedToken[token]) revert TokenAlreadyApproved(token);
        approvedToken[token] = true;
        listApprovedTokens.push(token);
    }

    function removeApprovedToken(address token) external onlyOwner {
        if (!approvedToken[token]) revert TokenNotApproved(token);
        approvedToken[token] = false;
        uint256 arrayLength = listApprovedTokens.length;
        for (uint256 i = 0; i < arrayLength; i++) {
            if (listApprovedTokens[i] == token) {
                listApprovedTokens[i] = listApprovedTokens[arrayLength - 1];
                listApprovedTokens.pop();
                break;
            }
        }
    }

    function setDepositFee(uint256 newDepositFee) external onlyOwner {
        if (newDepositFee > 500) revert InvalidDepositFee(newDepositFee);
        depositFee = newDepositFee;
    }

    function setFeeReceiver(address newFeeReceiver) external onlyOwner {
        if (newFeeReceiver == address(0)) revert InvalidFeeReceiver(newFeeReceiver);
        feeReceiver = newFeeReceiver;
    }

    function updateImplementation(address newImplementation) external onlyOwner {
        erc6551Implementation = newImplementation;
    }
}
