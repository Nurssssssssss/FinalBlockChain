// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import { UpgradeableTreasuryV1 } from "./UpgradeableTreasuryV1.sol";

contract UpgradeableTreasuryV2 is UpgradeableTreasuryV1 {
    uint256 private _protocolFeeBps;

    error FeeTooHigh(uint256 feeBps);

    event ProtocolFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);

    function setProtocolFeeBps(uint256 newFeeBps) external onlyRole(TREASURER_ROLE) {
        if (newFeeBps > 1000) revert FeeTooHigh(newFeeBps);
        uint256 oldFeeBps = _protocolFeeBps;
        _protocolFeeBps = newFeeBps;
        emit ProtocolFeeUpdated(oldFeeBps, newFeeBps);
    }

    function protocolFeeBps() external view returns (uint256) {
        return _protocolFeeBps;
    }

    function version() public pure override returns (uint256) {
        return 2;
    }
}
