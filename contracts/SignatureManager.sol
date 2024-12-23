// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract SignatureManager is Ownable, EIP712 {
    using ECDSA for bytes32;
    mapping(bytes32 => bool) private usedDigests;

    event AIAgentUpdated(address indexed oldAgent, address indexed newAgent);
    struct RedeemRequest {
        address user;
        string message_hash;
    }

    // Define the type hash for the RedeemRequest struct
    bytes32 private constant INTERACT_TYPEHASH =
        keccak256("RedeemRequest(address user,string message_hash)");

    constructor(
        string memory name,
        string memory version
    ) Ownable(msg.sender) EIP712(name, version) {}

    function _hashRedeemRequest(
        RedeemRequest memory req
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    INTERACT_TYPEHASH,
                    req.user,
                    keccak256(bytes(req.message_hash))
                )
            );
    }

    function verifySignature(
        address user,
        string memory message_hash,
        bytes memory signature
    ) public view returns (bool) {
        RedeemRequest memory req = RedeemRequest({
            user: user,
            message_hash: message_hash
        });
        // Use _hashTypedDataV4 from EIP712 to hash the typed data
        bytes32 digest = _hashTypedDataV4(_hashRedeemRequest(req));
        require(!usedDigests[digest], "Digest already used");

        // Recover the signer's address from the digest and signature
        address signer = ECDSA.recover(digest, signature);
        require(signer == user, "Invalid signature");
        return true;
    }

    function isDigestUsed(bytes32 digest) public view returns (bool) {
        return usedDigests[digest];
    }
}
