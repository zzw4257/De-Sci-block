// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract ZKProof is Ownable, ReentrancyGuard {
    struct Proof {
        address submitter;
        string proofType;
        uint256[8] proof;
        uint256[2] publicInputs;
        bool isVerified;
        uint256 submittedAt;
        uint256 verifiedAt;
        string metadataHash; // IPFS hash for additional proof metadata
    }

    struct ProofType {
        string name;
        bool isActive;
        address verifierContract; // Address of the specific verifier contract
        uint256 minReputation; // Minimum reputation required to submit this type
    }

    mapping(uint256 => Proof) public proofs;
    mapping(string => ProofType) public proofTypes;
    mapping(address => uint256[]) public userProofs;
    
    uint256 public nextProofId;
    string[] public supportedProofTypes;
    
    event ProofSubmitted(
        uint256 indexed proofId,
        address indexed submitter,
        string proofType,
        string metadataHash
    );
    
    event ProofVerified(
        uint256 indexed proofId,
        bool isValid,
        address indexed verifier
    );
    
    event ProofTypeAdded(string proofType, address verifierContract);
    event ProofTypeUpdated(string proofType, bool isActive);

    modifier validProofType(string memory _proofType) {
        require(proofTypes[_proofType].isActive, "Invalid or inactive proof type");
        _;
    }

    modifier onlyVerifier(string memory _proofType) {
        require(
            msg.sender == owner() || msg.sender == proofTypes[_proofType].verifierContract,
            "Not authorized to verify this proof type"
        );
        _;
    }

    constructor() Ownable(msg.sender) {
        nextProofId = 1;
        
        // Initialize default proof types
        _addProofType("identity_verification", address(0), 0);
        _addProofType("research_authenticity", address(0), 50);
        _addProofType("data_integrity", address(0), 25);
        _addProofType("peer_review", address(0), 100);
    }

    /**
     * @dev Submit a zero-knowledge proof
     * @param _proofType Type of proof being submitted
     * @param _proof The ZK proof (8 field elements)
     * @param _publicInputs Public inputs for the proof (2 field elements)
     * @param _metadataHash IPFS hash containing proof metadata
     */
    function submitProof(
        string memory _proofType,
        uint256[8] memory _proof,
        uint256[2] memory _publicInputs,
        string memory _metadataHash
    ) external validProofType(_proofType) nonReentrant returns (uint256) {
        // Check if user meets minimum reputation requirement
        // ProofType storage pType = proofTypes[_proofType];
        // Note: In a real implementation, you'd check user reputation from UserProfile contract
        
        uint256 proofId = nextProofId++;
        
        proofs[proofId] = Proof({
            submitter: msg.sender,
            proofType: _proofType,
            proof: _proof,
            publicInputs: _publicInputs,
            isVerified: false,
            submittedAt: block.timestamp,
            verifiedAt: 0,
            metadataHash: _metadataHash
        });

        userProofs[msg.sender].push(proofId);

        emit ProofSubmitted(proofId, msg.sender, _proofType, _metadataHash);
        
        return proofId;
    }

    /**
     * @dev Verify a submitted proof
     * @param _proofId ID of the proof to verify
     * @param _isValid Whether the proof is valid
     */
    function verifyProof(
        uint256 _proofId,
        bool _isValid
    ) external onlyVerifier(proofs[_proofId].proofType) {
        require(_proofId < nextProofId, "Proof does not exist");
        require(!proofs[_proofId].isVerified, "Proof already verified");

        Proof storage proof = proofs[_proofId];
        proof.isVerified = true;
        proof.verifiedAt = block.timestamp;

        // In a real implementation, you would:
        // 1. Call the specific verifier contract for this proof type
        // 2. Verify the ZK proof using the verifier contract
        // For demo purposes, we'll use the _isValid parameter

        emit ProofVerified(_proofId, _isValid, msg.sender);
    }

    /**
     * @dev Add a new proof type
     * @param _proofType Name of the proof type
     * @param _verifierContract Address of the verifier contract
     * @param _minReputation Minimum reputation required
     */
    function addProofType(
        string memory _proofType,
        address _verifierContract,
        uint256 _minReputation
    ) external onlyOwner {
        _addProofType(_proofType, _verifierContract, _minReputation);
    }

    function _addProofType(
        string memory _proofType,
        address _verifierContract,
        uint256 _minReputation
    ) internal {
        require(bytes(_proofType).length > 0, "Proof type cannot be empty");
        require(!proofTypes[_proofType].isActive, "Proof type already exists");

        proofTypes[_proofType] = ProofType({
            name: _proofType,
            isActive: true,
            verifierContract: _verifierContract,
            minReputation: _minReputation
        });

        supportedProofTypes.push(_proofType);
        emit ProofTypeAdded(_proofType, _verifierContract);
    }

    /**
     * @dev Update proof type status
     * @param _proofType Name of the proof type
     * @param _isActive Whether the proof type is active
     */
    function updateProofType(
        string memory _proofType,
        bool _isActive
    ) external onlyOwner {
        require(bytes(proofTypes[_proofType].name).length > 0, "Proof type does not exist");
        
        proofTypes[_proofType].isActive = _isActive;
        emit ProofTypeUpdated(_proofType, _isActive);
    }

    /**
     * @dev Get proof details
     * @param _proofId ID of the proof
     * @return Proof struct
     */
    function getProof(uint256 _proofId) external view returns (Proof memory) {
        require(_proofId < nextProofId, "Proof does not exist");
        return proofs[_proofId];
    }

    /**
     * @dev Get all proof IDs submitted by a user
     * @param _user Address of the user
     * @return Array of proof IDs
     */
    function getUserProofs(address _user) external view returns (uint256[] memory) {
        return userProofs[_user];
    }

    /**
     * @dev Get all supported proof types
     * @return Array of proof type names
     */
    function getSupportedProofTypes() external view returns (string[] memory) {
        return supportedProofTypes;
    }

    /**
     * @dev Check if a proof is verified
     * @param _proofId ID of the proof
     * @return Whether the proof is verified
     */
    function isProofVerified(uint256 _proofId) external view returns (bool) {
        if (_proofId >= nextProofId) return false;
        return proofs[_proofId].isVerified;
    }

    /**
     * @dev Get proof type details
     * @param _proofType Name of the proof type
     * @return ProofType struct
     */
    function getProofType(string memory _proofType) external view returns (ProofType memory) {
        return proofTypes[_proofType];
    }

    /**
     * @dev Get total number of proofs submitted
     * @return Total proof count
     */
    function getTotalProofs() external view returns (uint256) {
        return nextProofId - 1;
    }
}
