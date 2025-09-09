// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./UserProfile.sol";
import "./ZKProof.sol";
import "./DeSciNFTSimple.sol";
import "./Dataset.sol";

contract DeSciPlatform is Ownable, ReentrancyGuard {
    UserProfile public userProfileContract;
    ZKProof public zkProofContract;
    DeSciNFTSimple public nftContract;
    Dataset public datasetContract;

    struct Research {
        uint256 id;
        string title;
        string description;
        address researcher;
        uint256 datasetId;
        uint256 nftTokenId;
        uint256[] zkProofIds;
        string metadataHash;
        uint256 publishedAt;
        ResearchStatus status;
        uint256 peerReviewCount;
        uint256 averageRating;
    }

    struct PeerReview {
        uint256 researchId;
        address reviewer;
        uint256 rating; // 1-10 scale
        string comments;
        string ipfsHash;
        uint256 reviewedAt;
        bool isVerified;
    }

    enum ResearchStatus {
        Draft,
        Submitted,
        UnderReview,
        Published,
        Rejected
    }

    mapping(uint256 => Research) public researches;
    mapping(uint256 => PeerReview[]) public peerReviews;
    mapping(address => uint256[]) public researcherPublications;
    mapping(uint256 => mapping(address => bool)) public hasReviewed;
    
    uint256 public nextResearchId;
    uint256[] public allResearches;
    
    // Platform settings
    uint256 public minimumReputationToReview = 50;
    uint256 public minimumReviewsToPublish = 2;
    uint256 public reviewReward = 0.01 ether;
    
    event ResearchSubmitted(
        uint256 indexed researchId,
        address indexed researcher,
        string title,
        uint256 datasetId
    );
    
    event ResearchPublished(
        uint256 indexed researchId,
        uint256 indexed nftTokenId,
        address indexed researcher
    );
    
    event PeerReviewSubmitted(
        uint256 indexed researchId,
        address indexed reviewer,
        uint256 rating
    );
    
    event ResearchStatusChanged(
        uint256 indexed researchId,
        ResearchStatus oldStatus,
        ResearchStatus newStatus
    );

    modifier onlyRegisteredUser() {
        require(userProfileContract.hasProfile(msg.sender), "User not registered");
        _;
    }

    modifier researchExists(uint256 _researchId) {
        require(_researchId < nextResearchId, "Research does not exist");
        _;
    }

    modifier onlyResearcher(uint256 _researchId) {
        require(researches[_researchId].researcher == msg.sender, "Not the researcher");
        _;
    }

    constructor(
        address _userProfileContract,
        address _zkProofContract,
        address _nftContract,
        address _datasetContract
    ) Ownable(msg.sender) {
        userProfileContract = UserProfile(_userProfileContract);
        zkProofContract = ZKProof(_zkProofContract);
        nftContract = DeSciNFTSimple(_nftContract);
        datasetContract = Dataset(_datasetContract);
        nextResearchId = 1;
    }

    /**
     * @dev Publish research with integrated dataset and ZK proofs
     * @param _title Title of the research
     * @param _description Description of the research
     * @param _datasetName Name of the dataset
     * @param _datasetDescription Description of the dataset
     * @param _datasetHash Hash of the dataset
     * @param _metadataHash IPFS hash for research metadata
     * @param _zkProofIds Array of ZK proof IDs that validate this research
     * @param _isDatasetPublic Whether the dataset should be public
     * @param _datasetAccessPrice Price to access the dataset
     */
    function publishResearch(
        string memory _title,
        string memory _description,
        string memory _datasetName,
        string memory _datasetDescription,
        string memory _datasetHash,
        string memory _metadataHash,
        uint256[] memory _zkProofIds,
        bool _isDatasetPublic,
        uint256 _datasetAccessPrice
    ) external onlyRegisteredUser nonReentrant returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(userProfileContract.isUserVerified(msg.sender), "User must be verified");

        // Verify all ZK proofs are valid and belong to the user
        for (uint256 i = 0; i < _zkProofIds.length; i++) {
            require(zkProofContract.isProofVerified(_zkProofIds[i]), "Invalid ZK proof");
            ZKProof.Proof memory proof = zkProofContract.getProof(_zkProofIds[i]);
            require(proof.submitter == msg.sender, "ZK proof not owned by researcher");
        }

        // Register dataset
        string[] memory tags = new string[](1);
        tags[0] = "research";
        
        uint256 datasetId = datasetContract.registerDataset(
            _datasetName,
            _datasetDescription,
            _datasetHash,
            _metadataHash,
            _isDatasetPublic,
            _datasetAccessPrice,
            tags
        );

        // Create research entry
        uint256 researchId = nextResearchId++;
        
        researches[researchId] = Research({
            id: researchId,
            title: _title,
            description: _description,
            researcher: msg.sender,
            datasetId: datasetId,
            nftTokenId: 0, // Will be set when published
            zkProofIds: _zkProofIds,
            metadataHash: _metadataHash,
            publishedAt: 0, // Will be set when published
            status: ResearchStatus.Submitted,
            peerReviewCount: 0,
            averageRating: 0
        });

        researcherPublications[msg.sender].push(researchId);
        allResearches.push(researchId);

        emit ResearchSubmitted(researchId, msg.sender, _title, datasetId);
        
        return researchId;
    }

    /**
     * @dev Submit a peer review for research
     * @param _researchId ID of the research to review
     * @param _rating Rating from 1-10
     * @param _comments Review comments
     * @param _ipfsHash IPFS hash for detailed review
     */
    function submitPeerReview(
        uint256 _researchId,
        uint256 _rating,
        string memory _comments,
        string memory _ipfsHash
    ) external onlyRegisteredUser researchExists(_researchId) nonReentrant {
        Research storage research = researches[_researchId];
        require(research.status == ResearchStatus.Submitted || research.status == ResearchStatus.UnderReview, "Research not available for review");
        require(research.researcher != msg.sender, "Cannot review own research");
        require(!hasReviewed[_researchId][msg.sender], "Already reviewed this research");
        require(_rating >= 1 && _rating <= 10, "Rating must be between 1-10");
        
        // Check reviewer reputation
        uint256 reviewerReputation = userProfileContract.getUserReputation(msg.sender);
        require(reviewerReputation >= minimumReputationToReview, "Insufficient reputation to review");

        // Add peer review
        peerReviews[_researchId].push(PeerReview({
            researchId: _researchId,
            reviewer: msg.sender,
            rating: _rating,
            comments: _comments,
            ipfsHash: _ipfsHash,
            reviewedAt: block.timestamp,
            isVerified: userProfileContract.isUserVerified(msg.sender)
        }));

        hasReviewed[_researchId][msg.sender] = true;
        research.peerReviewCount++;

        // Update research status
        if (research.status == ResearchStatus.Submitted) {
            research.status = ResearchStatus.UnderReview;
            emit ResearchStatusChanged(_researchId, ResearchStatus.Submitted, ResearchStatus.UnderReview);
        }

        // Calculate new average rating
        _updateAverageRating(_researchId);

        // Reward reviewer (if contract has funds)
        if (address(this).balance >= reviewReward) {
            payable(msg.sender).transfer(reviewReward);
        }

        emit PeerReviewSubmitted(_researchId, msg.sender, _rating);

        // Auto-publish if minimum reviews reached and average rating is good
        if (research.peerReviewCount >= minimumReviewsToPublish && research.averageRating >= 7) {
            _publishResearch(_researchId);
        }
    }

    /**
     * @dev Internal function to publish research as NFT
     * @param _researchId ID of the research to publish
     */
    function _publishResearch(uint256 _researchId) internal {
        Research storage research = researches[_researchId];
        require(research.status == ResearchStatus.UnderReview, "Research not ready for publishing");

        // Mint NFT for the research
        uint256 nftTokenId = nftContract.mintResearchNFT(
            research.researcher,
            research.title,
            research.description,
            research.metadataHash,
            "paper"
        );

        // Update research status
        research.nftTokenId = nftTokenId;
        research.publishedAt = block.timestamp;
        research.status = ResearchStatus.Published;

        // Update researcher reputation
        uint256 currentReputation = userProfileContract.getUserReputation(research.researcher);
        uint256 bonusReputation = research.averageRating * 10; // Bonus based on review quality
        userProfileContract.updateReputation(research.researcher, currentReputation + bonusReputation);

        emit ResearchPublished(_researchId, nftTokenId, research.researcher);
        emit ResearchStatusChanged(_researchId, ResearchStatus.UnderReview, ResearchStatus.Published);
    }

    /**
     * @dev Manually publish research (owner only)
     * @param _researchId ID of the research to publish
     */
    function manuallyPublishResearch(uint256 _researchId) external onlyOwner researchExists(_researchId) {
        _publishResearch(_researchId);
    }

    /**
     * @dev Update average rating for research
     * @param _researchId ID of the research
     */
    function _updateAverageRating(uint256 _researchId) internal {
        PeerReview[] storage reviews = peerReviews[_researchId];
        if (reviews.length == 0) return;

        uint256 totalRating = 0;
        uint256 verifiedReviews = 0;

        for (uint256 i = 0; i < reviews.length; i++) {
            totalRating += reviews[i].rating;
            if (reviews[i].isVerified) {
                verifiedReviews++;
                totalRating += reviews[i].rating; // Double weight for verified reviewers
            }
        }

        researches[_researchId].averageRating = totalRating / (reviews.length + verifiedReviews);
    }

    /**
     * @dev Get research details
     * @param _researchId ID of the research
     * @return Research struct
     */
    function getResearch(uint256 _researchId) external view researchExists(_researchId) returns (Research memory) {
        return researches[_researchId];
    }

    /**
     * @dev Get peer reviews for research
     * @param _researchId ID of the research
     * @return Array of PeerReview structs
     */
    function getPeerReviews(uint256 _researchId) external view researchExists(_researchId) returns (PeerReview[] memory) {
        return peerReviews[_researchId];
    }

    /**
     * @dev Get all research IDs by a researcher
     * @param _researcher Address of the researcher
     * @return Array of research IDs
     */
    function getResearcherPublications(address _researcher) external view returns (uint256[] memory) {
        return researcherPublications[_researcher];
    }

    /**
     * @dev Get all research IDs
     * @return Array of all research IDs
     */
    function getAllResearches() external view returns (uint256[] memory) {
        return allResearches;
    }

    /**
     * @dev Update platform settings (owner only)
     */
    function updatePlatformSettings(
        uint256 _minimumReputationToReview,
        uint256 _minimumReviewsToPublish,
        uint256 _reviewReward
    ) external onlyOwner {
        minimumReputationToReview = _minimumReputationToReview;
        minimumReviewsToPublish = _minimumReviewsToPublish;
        reviewReward = _reviewReward;
    }

    /**
     * @dev Fund the contract for review rewards
     */
    function fundReviewRewards() external payable onlyOwner {}

    /**
     * @dev Withdraw funds (owner only)
     */
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * @dev Get total number of researches
     * @return Total research count
     */
    function getTotalResearches() external view returns (uint256) {
        return nextResearchId - 1;
    }

    /**
     * @dev Update contract addresses (owner only)
     */
    function updateContractAddresses(
        address _userProfileContract,
        address _zkProofContract,
        address _nftContract,
        address _datasetContract
    ) external onlyOwner {
        userProfileContract = UserProfile(_userProfileContract);
        zkProofContract = ZKProof(_zkProofContract);
        nftContract = DeSciNFTSimple(_nftContract);
        datasetContract = Dataset(_datasetContract);
    }
}
