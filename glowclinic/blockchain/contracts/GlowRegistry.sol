// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title GlowRegistry
/// @notice Menyimpan sidik jari (hash) catatan GlowClinic di blockchain.
///         Data asli (nama pasien, nominal, dll.) TIDAK disimpan on-chain,
///         hanya SHA-256 dari data tersebut, sehingga privasi pasien terjaga.
contract GlowRegistry {
    address public immutable owner;
    uint256 public totalAnchored;

    /// hash => waktu block saat pertama kali dicatat (0 = belum pernah)
    mapping(bytes32 => uint256) public anchoredAt;

    event Anchored(bytes32 indexed hash, string kind, uint256 timestamp);

    error NotOwner();
    error AlreadyAnchored(bytes32 hash);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @param hash SHA-256 dari catatan (booking / payment / spin / treatment)
    /// @param kind label jenis catatan, mis. "booking", "payment"
    function anchor(bytes32 hash, string calldata kind) external onlyOwner {
        if (anchoredAt[hash] != 0) revert AlreadyAnchored(hash);
        anchoredAt[hash] = block.timestamp;
        totalAnchored += 1;
        emit Anchored(hash, kind, block.timestamp);
    }

    /// @return waktu pencatatan (detik epoch), 0 jika hash tidak ada di chain
    function verify(bytes32 hash) external view returns (uint256) {
        return anchoredAt[hash];
    }
}
