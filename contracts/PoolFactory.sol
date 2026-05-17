// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ConstantProductAMM } from "./ConstantProductAMM.sol";

contract PoolFactory is AccessControl {
    bytes32 public constant PAIR_CREATOR_ROLE = keccak256("PAIR_CREATOR_ROLE");

    mapping(address token0 => mapping(address token1 => address pair)) public getPair;
    address[] public allPairs;

    error IdenticalTokens();
    error ZeroAddress();
    error PairExists(address pair);

    event PairCreated(
        address indexed token0,
        address indexed token1,
        address indexed pair,
        bool deterministic,
        bytes32 salt,
        uint256 pairCount
    );

    constructor(address admin) {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAIR_CREATOR_ROLE, admin);
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(
        address tokenA,
        address tokenB,
        address oracleA,
        address oracleB,
        address pairAdmin,
        string memory lpName,
        string memory lpSymbol
    ) external onlyRole(PAIR_CREATOR_ROLE) returns (address pair) {
        (address token0, address token1, address oracle0, address oracle1) = _sort(tokenA, tokenB, oracleA, oracleB);
        if (getPair[token0][token1] != address(0)) revert PairExists(getPair[token0][token1]);

        pair = address(new ConstantProductAMM(token0, token1, oracle0, oracle1, pairAdmin, lpName, lpSymbol));
        _registerPair(token0, token1, pair, false, bytes32(0));
    }

    function createPairDeterministic(
        address tokenA,
        address tokenB,
        address oracleA,
        address oracleB,
        address pairAdmin,
        string memory lpName,
        string memory lpSymbol,
        bytes32 salt
    ) external onlyRole(PAIR_CREATOR_ROLE) returns (address pair) {
        (address token0, address token1, address oracle0, address oracle1) = _sort(tokenA, tokenB, oracleA, oracleB);
        if (getPair[token0][token1] != address(0)) revert PairExists(getPair[token0][token1]);

        pair = address(
            new ConstantProductAMM{ salt: salt }(token0, token1, oracle0, oracle1, pairAdmin, lpName, lpSymbol)
        );
        _registerPair(token0, token1, pair, true, salt);
    }

    function predictDeterministicAddress(
        address tokenA,
        address tokenB,
        address oracleA,
        address oracleB,
        address pairAdmin,
        string memory lpName,
        string memory lpSymbol,
        bytes32 salt
    ) external view returns (address predicted) {
        (address token0, address token1, address oracle0, address oracle1) = _sort(tokenA, tokenB, oracleA, oracleB);
        bytes32 bytecodeHash = keccak256(
            abi.encodePacked(
                type(ConstantProductAMM).creationCode,
                abi.encode(token0, token1, oracle0, oracle1, pairAdmin, lpName, lpSymbol)
            )
        );
        predicted =
            address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, bytecodeHash)))));
    }

    function _registerPair(address token0, address token1, address pair, bool deterministic, bytes32 salt) private {
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, deterministic, salt, allPairs.length);
    }

    function _sort(address tokenA, address tokenB, address oracleA, address oracleB)
        private
        pure
        returns (address token0, address token1, address oracle0, address oracle1)
    {
        if (tokenA == tokenB) revert IdenticalTokens();
        if (tokenA == address(0) || tokenB == address(0) || oracleA == address(0) || oracleB == address(0)) {
            revert ZeroAddress();
        }
        if (tokenA < tokenB) return (tokenA, tokenB, oracleA, oracleB);
        return (tokenB, tokenA, oracleB, oracleA);
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
