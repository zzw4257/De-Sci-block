// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./ZKProof.sol";
import "./Dataset.sol";

/**
 * @title ResearchDataVerifier
 * @dev Research data verification main contract, implementing complete ZKP verification flow
 * Includes: data submission, feature extraction, constraint verification, ZKP generation and verification
 */
contract ResearchDataVerifier is Ownable, ReentrancyGuard {
    using Strings for uint256;

    // Data structures
    struct ResearchData {
        address submitter;
        string dataType;           // Data type: experiment, dataset, analysis
        string dataHash;           // Original data IPFS hash
        string metadataHash;       // Metadata IPFS hash
        uint256 timestamp;
        bool isVerified;
        uint256 verificationScore; // Verification score 0-100
        string verificationStatus; // Verification status
    }

    struct DataFeature {
        uint256 mean;              // Mean value
        uint256 standardDeviation; // Standard deviation
        uint256 minValue;          // Minimum value
        uint256 maxValue;          // Maximum value
        uint256 dataCount;         // Data point count
        bytes32 featureHash;       // Feature hash
    }

    struct Constraint {
        string constraintType;     // Constraint type
        uint256 threshold;         // Threshold
        bool isActive;             // Whether active
        string description;        // Constraint description
    }

    // State variables
    mapping(bytes32 => ResearchData) public researchData;
    mapping(bytes32 => DataFeature) public dataFeatures;
    mapping(bytes32 => Constraint[]) public dataConstraints;
    mapping(address => bytes32[]) public userData;
    
    bytes32[] public allDataIds;
    uint256 public nextDataId;
    
    // Constraint types
    string[] public constraintTypes;
    mapping(string => Constraint) public globalConstraints;
    
    // Events
    event DataSubmitted(
        bytes32 indexed dataId,
        address indexed submitter,
        string dataType,
        string dataHash
    );
    
    event FeaturesExtracted(
        bytes32 indexed dataId,
        bytes32 featureHash,
        uint256 mean,
        uint256 standardDeviation
    );
    
    event ConstraintAdded(
        string constraintType,
        uint256 threshold,
        string description
    );
    
    event DataVerified(
        bytes32 indexed dataId,
        bool isValid,
        uint256 score,
        string status
    );

    // Modifiers
    modifier dataExists(bytes32 _dataId) {
        require(researchData[_dataId].submitter != address(0), "Data does not exist");
        _;
    }

    modifier onlyDataOwner(bytes32 _dataId) {
        require(researchData[_dataId].submitter == msg.sender, "Not data owner");
        _;
    }

    constructor() Ownable(msg.sender) {
        nextDataId = 1;
        
        // Initialize default constraints
        _addGlobalConstraint("error_threshold", 5, "Error threshold not exceeding 5%");
        _addGlobalConstraint("data_format", 1, "Data format must conform to specifications");
        _addGlobalConstraint("hash_validity", 1, "Hash value must be valid");
        _addGlobalConstraint("statistical_validity", 10, "Statistical validity check");
    }

    /**
     * @dev 提交科研数据
     * @param _dataType 数据类型
     * @param _dataHash 数据IPFS哈希
     * @param _metadataHash 元数据IPFS哈希
     * @return dataId 数据ID
     */
    function submitResearchData(
        string memory _dataType,
        string memory _dataHash,
        string memory _metadataHash
    ) external nonReentrant returns (bytes32) {
        require(bytes(_dataHash).length > 0, "Data hash cannot be empty");
        require(bytes(_dataType).length > 0, "Data type cannot be empty");
        
        bytes32 dataId = keccak256(abi.encodePacked(
            msg.sender,
            _dataType,
            _dataHash,
            block.timestamp,
            nextDataId
        ));
        
        researchData[dataId] = ResearchData({
            submitter: msg.sender,
            dataType: _dataType,
            dataHash: _dataHash,
            metadataHash: _metadataHash,
            timestamp: block.timestamp,
            isVerified: false,
            verificationScore: 0,
            verificationStatus: "pending"
        });
        
        userData[msg.sender].push(dataId);
        allDataIds.push(dataId);
        nextDataId++;
        
        emit DataSubmitted(dataId, msg.sender, _dataType, _dataHash);
        
        return dataId;
    }

    /**
     * @dev 提取数据特征（链下计算，链上存储）
     * @param _dataId 数据ID
     * @param _mean 平均值
     * @param _stdDev 标准差
     * @param _min 最小值
     * @param _max 最大值
     * @param _count 数据点数量
     */
    function extractDataFeatures(
        bytes32 _dataId,
        uint256 _mean,
        uint256 _stdDev,
        uint256 _min,
        uint256 _max,
        uint256 _count
    ) external onlyDataOwner(_dataId) {
        bytes32 featureHash = keccak256(abi.encodePacked(
            _mean, _stdDev, _min, _max, _count, _dataId
        ));
        
        dataFeatures[_dataId] = DataFeature({
            mean: _mean,
            standardDeviation: _stdDev,
            minValue: _min,
            maxValue: _max,
            dataCount: _count,
            featureHash: featureHash
        });
        
        emit FeaturesExtracted(_dataId, featureHash, _mean, _stdDev);
    }

    /**
     * @dev 添加数据特定约束
     * @param _dataId 数据ID
     * @param _constraintType 约束类型
     * @param _threshold 阈值
     * @param _description 描述
     */
    function addDataConstraint(
        bytes32 _dataId,
        string memory _constraintType,
        uint256 _threshold,
        string memory _description
    ) external onlyDataOwner(_dataId) {
        Constraint memory newConstraint = Constraint({
            constraintType: _constraintType,
            threshold: _threshold,
            isActive: true,
            description: _description
        });
        
        dataConstraints[_dataId].push(newConstraint);
    }

    /**
     * @dev 添加全局约束
     * @param _constraintType 约束类型
     * @param _threshold 阈值
     * @param _description 描述
     */
    function addGlobalConstraint(
        string memory _constraintType,
        uint256 _threshold,
        string memory _description
    ) external onlyOwner {
        _addGlobalConstraint(_constraintType, _threshold, _description);
    }

    function _addGlobalConstraint(
        string memory _constraintType,
        uint256 _threshold,
        string memory _description
    ) internal {
        globalConstraints[_constraintType] = Constraint({
            constraintType: _constraintType,
            threshold: _threshold,
            isActive: true,
            description: _description
        });
        
        constraintTypes.push(_constraintType);
        emit ConstraintAdded(_constraintType, _threshold, _description);
    }

    /**
     * @dev 验证数据是否满足约束条件
     * @param _dataId 数据ID
     * @return isValid 是否有效
     * @return score 验证分数
     * @return status 状态描述
     */
    function validateDataConstraints(
        bytes32 _dataId
    ) external view returns (bool isValid, uint256 score, string memory status) {
        DataFeature storage features = dataFeatures[_dataId];
        Constraint[] storage constraints = dataConstraints[_dataId];
        
        if (features.dataCount == 0) {
            return (false, 0, "Features not extracted");
        }
        
        uint256 totalScore = 0;
        uint256 maxScore = 100;
        uint256 constraintCount = constraints.length + constraintTypes.length;
        
        // 检查数据特定约束
        for (uint i = 0; i < constraints.length; i++) {
            if (constraints[i].isActive) {
                bool constraintMet = _checkConstraint(features, constraints[i]);
                if (constraintMet) {
                    totalScore += maxScore / constraintCount;
                }
            }
        }
        
        // 检查全局约束
        for (uint i = 0; i < constraintTypes.length; i++) {
            Constraint storage globalConstraint = globalConstraints[constraintTypes[i]];
            if (globalConstraint.isActive) {
                bool constraintMet = _checkConstraint(features, globalConstraint);
                if (constraintMet) {
                    totalScore += maxScore / constraintCount;
                }
            }
        }
        
        isValid = totalScore >= 70; // 70%以上算通过
        score = totalScore;
        status = isValid ? "verified" : "failed";
        
        return (isValid, score, status);
    }

    /**
     * @dev 检查单个约束条件
     * @param _features 数据特征
     * @param _constraint 约束条件
     * @return 是否满足约束
     */
    function _checkConstraint(
        DataFeature storage _features,
        Constraint storage _constraint
    ) internal view returns (bool) {
        if (keccak256(bytes(_constraint.constraintType)) == keccak256(bytes("error_threshold"))) {
            // 误差阈值检查：标准差/平均值 < 阈值
            if (_features.mean > 0) {
                uint256 errorRate = (_features.standardDeviation * 100) / _features.mean;
                return errorRate <= _constraint.threshold;
            }
        } else if (keccak256(bytes(_constraint.constraintType)) == keccak256(bytes("data_format"))) {
            // 数据格式检查：数据点数量 > 0
            return _features.dataCount > 0;
        } else if (keccak256(bytes(_constraint.constraintType)) == keccak256(bytes("hash_validity"))) {
            // Hash validity check
            return _features.featureHash != bytes32(0);
        } else if (keccak256(bytes(_constraint.constraintType)) == keccak256(bytes("statistical_validity"))) {
            // 统计有效性：最大值 > 最小值
            return _features.maxValue > _features.minValue;
        }
        
        return false;
    }

    /**
     * @dev 通过ZKP验证数据
     * @param _dataId 数据ID
     * @param _zkpContract ZKP合约地址
     * @param _proofId ZKP证明ID
     */
    function verifyDataWithZKP(
        bytes32 _dataId,
        address _zkpContract,
        uint256 _proofId
    ) external dataExists(_dataId) {
        ZKProof zkp = ZKProof(_zkpContract);
        
        // 检查ZKP证明是否已验证
        require(zkp.isProofVerified(_proofId), "ZKP proof not verified");
        
        // 获取ZKP证明详情
        ZKProof.Proof memory proof = zkp.getProof(_proofId);
        
        // 验证证明类型匹配
        require(
            keccak256(bytes(proof.proofType)) == keccak256(bytes("research_data_verification")),
            "Invalid proof type"
        );
        
        // 更新数据验证状态
        researchData[_dataId].isVerified = true;
        researchData[_dataId].verificationStatus = "zkp_verified";
        researchData[_dataId].verificationScore = 100;
        
        emit DataVerified(_dataId, true, 100, "zkp_verified");
    }

    /**
     * @dev 获取数据详情
     * @param _dataId 数据ID
     * @return 数据详情
     */
    function getResearchData(bytes32 _dataId) external view returns (ResearchData memory) {
        return researchData[_dataId];
    }

    /**
     * @dev 获取数据特征
     * @param _dataId 数据ID
     * @return 数据特征
     */
    function getDataFeatures(bytes32 _dataId) external view returns (DataFeature memory) {
        return dataFeatures[_dataId];
    }

    /**
     * @dev 获取数据约束
     * @param _dataId 数据ID
     * @return 约束数组
     */
    function getDataConstraints(bytes32 _dataId) external view returns (Constraint[] memory) {
        return dataConstraints[_dataId];
    }

    /**
     * @dev 获取用户所有数据ID
     * @param _user 用户地址
     * @return 数据ID数组
     */
    function getUserDataIds(address _user) external view returns (bytes32[] memory) {
        return userData[_user];
    }

    /**
     * @dev 获取所有数据ID
     * @return 数据ID数组
     */
    function getAllDataIds() external view returns (bytes32[] memory) {
        return allDataIds;
    }

    /**
     * @dev 获取约束类型
     * @return 约束类型数组
     */
    function getConstraintTypes() external view returns (string[] memory) {
        return constraintTypes;
    }

    /**
     * @dev 获取全局约束
     * @param _constraintType 约束类型
     * @return 约束详情
     */
    function getGlobalConstraint(string memory _constraintType) external view returns (Constraint memory) {
        return globalConstraints[_constraintType];
    }
} 