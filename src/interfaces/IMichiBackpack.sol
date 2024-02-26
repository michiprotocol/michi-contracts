pragma solidity ^0.8.13;

interface IMichiBackpack {
    function getCurrentIndex() external view returns (uint256);

    function mint(address recipient) external payable;
}
