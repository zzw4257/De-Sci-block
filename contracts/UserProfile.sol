// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract UserProfile is Ownable, ReentrancyGuard {
    struct Profile {
        string fullName;
        uint256 age;
        string email;
        string ipfsHash;
        bool isVerified;
        uint256 createdAt;
        uint256 updatedAt;
        uint256 reputation;
    }

    mapping(address => Profile) public profiles;
    mapping(string => address) public emailToAddress;
    mapping(address => bool) public hasProfile;
    
    address[] public allUsers;
    
    event ProfileCreated(address indexed user, string email, string ipfsHash);
    event ProfileUpdated(address indexed user, string ipfsHash);
    event ProfileVerified(address indexed user, bool verified);
    event ReputationUpdated(address indexed user, uint256 newReputation);

    modifier onlyProfileOwner() {
        require(hasProfile[msg.sender], "Profile does not exist");
        _;
    }

    modifier emailNotTaken(string memory _email) {
        require(emailToAddress[_email] == address(0), "Email already registered");
        _;
    }

    constructor() Ownable(msg.sender) {}

    /**
     * @dev Create a new user profile
     * @param _fullName Full name of the user
     * @param _age Age of the user
     * @param _email Email address (must be unique)
     * @param _ipfsHash IPFS hash for additional profile data
     */
    function createProfile(
        string memory _fullName,
        uint256 _age,
        string memory _email,
        string memory _ipfsHash
    ) external emailNotTaken(_email) nonReentrant {
        require(!hasProfile[msg.sender], "Profile already exists");
        require(bytes(_fullName).length > 0, "Full name cannot be empty");
        require(_age > 0 && _age < 150, "Invalid age");
        require(bytes(_email).length > 0, "Email cannot be empty");

        profiles[msg.sender] = Profile({
            fullName: _fullName,
            age: _age,
            email: _email,
            ipfsHash: _ipfsHash,
            isVerified: false,
            createdAt: block.timestamp,
            updatedAt: block.timestamp,
            reputation: 0
        });

        emailToAddress[_email] = msg.sender;
        hasProfile[msg.sender] = true;
        allUsers.push(msg.sender);

        emit ProfileCreated(msg.sender, _email, _ipfsHash);
    }

    /**
     * @dev Update existing profile
     * @param _fullName New full name
     * @param _age New age
     * @param _ipfsHash New IPFS hash
     */
    function updateProfile(
        string memory _fullName,
        uint256 _age,
        string memory _ipfsHash
    ) external onlyProfileOwner nonReentrant {
        require(bytes(_fullName).length > 0, "Full name cannot be empty");
        require(_age > 0 && _age < 150, "Invalid age");

        Profile storage profile = profiles[msg.sender];
        profile.fullName = _fullName;
        profile.age = _age;
        profile.ipfsHash = _ipfsHash;
        profile.updatedAt = block.timestamp;

        emit ProfileUpdated(msg.sender, _ipfsHash);
    }

    /**
     * @dev Get profile information
     * @param _user Address of the user
     * @return Profile struct
     */
    function getProfile(address _user) external view returns (Profile memory) {
        require(hasProfile[_user], "Profile does not exist");
        return profiles[_user];
    }

    /**
     * @dev Verify a user profile (only owner)
     * @param _user Address of the user to verify
     * @param _verified Verification status
     */
    function verifyProfile(address _user, bool _verified) external onlyOwner {
        require(hasProfile[_user], "Profile does not exist");
        profiles[_user].isVerified = _verified;
        emit ProfileVerified(_user, _verified);
    }

    /**
     * @dev Update user reputation (only owner or authorized contracts)
     * @param _user Address of the user
     * @param _reputation New reputation score
     */
    function updateReputation(address _user, uint256 _reputation) external onlyOwner {
        require(hasProfile[_user], "Profile does not exist");
        profiles[_user].reputation = _reputation;
        emit ReputationUpdated(_user, _reputation);
    }

    /**
     * @dev Get total number of users
     * @return Number of registered users
     */
    function getTotalUsers() external view returns (uint256) {
        return allUsers.length;
    }

    /**
     * @dev Get user address by email
     * @param _email Email address
     * @return User address
     */
    function getUserByEmail(string memory _email) external view returns (address) {
        return emailToAddress[_email];
    }

    /**
     * @dev Check if user is verified
     * @param _user Address of the user
     * @return Verification status
     */
    function isUserVerified(address _user) external view returns (bool) {
        if (!hasProfile[_user]) return false;
        return profiles[_user].isVerified;
    }

    /**
     * @dev Get user reputation
     * @param _user Address of the user
     * @return Reputation score
     */
    function getUserReputation(address _user) external view returns (uint256) {
        if (!hasProfile[_user]) return 0;
        return profiles[_user].reputation;
    }
}
