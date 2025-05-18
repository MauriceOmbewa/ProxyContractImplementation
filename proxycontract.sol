// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title LogicV1 — Example logic contract
contract LogicV1 {
    uint256 public x;

    // Only used for first-time initialization
    function initialize(uint256 _x) external {
        require(x == 0, "already initialized");
        x = _x;
    }

    function increment() external {
        x += 1;
    }
}

/// @title ProxyAdmin — Manages upgrades
contract ProxyAdmin {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not admin");
        _;
    }

    function upgrade(address proxy, address newImpl) external onlyOwner {
        TransparentProxy(proxy).upgradeTo(newImpl);
    }
}

/// @title TransparentProxy — EIP-1967 transparent proxy
contract TransparentProxy {
    // EIP-1967 implementation slot:
    // bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
    bytes32 private constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    address public admin;

    constructor(address _logic, bytes memory _data) {
        // set admin
        admin = msg.sender;
        // store implementation
        _setImplementation(_logic);
        // initialize logic (delegatecall)
        (bool ok, ) = _logic.delegatecall(_data);
        require(ok, "init failed");
    }

    /// @notice Fallback function: delegate calls to implementation
    fallback() external payable {
        address impl = _implementation();
        assembly {
            // Copy calldata
            calldatacopy(0, 0, calldatasize())
            // Delegatecall with all gas
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            // Copy return
            returndatacopy(0, 0, returndatasize())
            // Propagate result
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}

    /// @notice Admin-only upgrade
    function upgradeTo(address newImpl) external {
        require(msg.sender == admin, "not admin");
        _setImplementation(newImpl);
    }

    function _implementation() internal view returns (address impl) {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly { impl := sload(slot) }
    }

    function _setImplementation(address newImpl) internal {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly { sstore(slot, newImpl) }
    }
}
