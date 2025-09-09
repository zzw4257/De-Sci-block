// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title DataFeatureExtractor
 * @dev Data feature extraction contract, implementing statistical feature calculation for research data
 * Supports multiple data types and statistical metrics calculation
 */
contract DataFeatureExtractor is Ownable, ReentrancyGuard {
    using Strings for uint256;

    // Data type enumeration
    enum DataType {
        EXPERIMENTAL,    // Experimental data
        STATISTICAL,     // Statistical data
        TIME_SERIES,     // Time series
        CATEGORICAL,     // Categorical data
        NUMERICAL        // Numerical data
    }

    // Feature type enumeration
    enum FeatureType {
        MEAN,           // Mean value
        MEDIAN,         // Median value
        STANDARD_DEVIATION, // Standard deviation
        VARIANCE,       // Variance
        MIN_VALUE,      // Minimum value
        MAX_VALUE,      // Maximum value
        RANGE,          // Range
        SKEWNESS,       // Skewness
        KURTOSIS,       // Kurtosis
        QUANTILES,      // Quantiles
        CORRELATION,    // Correlation
        DISTRIBUTION    // Distribution features
    }

    // 数据特征结构
    struct DataFeatures {
        DataType dataType;
        uint256 dataCount;
        uint256[] numericalFeatures;    // 数值特征
        string[] categoricalFeatures;   // 分类特征
        uint256 timestamp;
        string featureHash;
        bool isCalculated;
        address calculator;
    }

    // 统计指标结构
    struct StatisticalMetrics {
        uint256 mean;
        uint256 median;
        uint256 standardDeviation;
        uint256 variance;
        uint256 minValue;
        uint256 maxValue;
        uint256 range;
        uint256 skewness;
        uint256 kurtosis;
        uint256[] quantiles;
    }

    // 状态变量
    mapping(bytes32 => DataFeatures) public dataFeatures;
    mapping(bytes32 => StatisticalMetrics) public statisticalMetrics;
    mapping(address => bytes32[]) public userCalculations;
    
    bytes32[] public allFeatureIds;
    uint256 public nextFeatureId;
    
    // 特征计算器
    mapping(address => bool) public authorizedCalculators;
    
    // 事件
    event FeaturesCalculated(
        bytes32 indexed featureId,
        address indexed calculator,
        DataType dataType,
        uint256 dataCount
    );
    
    event StatisticalMetricsUpdated(
        bytes32 indexed featureId,
        uint256 mean,
        uint256 standardDeviation,
        uint256 minValue,
        uint256 maxValue
    );
    
    event CalculatorAuthorized(address indexed calculator, bool isAuthorized);
    
    // 修饰符
    modifier onlyAuthorizedCalculator() {
        require(authorizedCalculators[msg.sender] || msg.sender == owner(), "Not authorized calculator");
        _;
    }

    modifier featureExists(bytes32 _featureId) {
        require(dataFeatures[_featureId].calculator != address(0), "Feature does not exist");
        _;
    }

    constructor() Ownable(msg.sender) {
        nextFeatureId = 1;
        authorizedCalculators[msg.sender] = true;
    }

    /**
     * @dev 授权特征计算器
     * @param _calculator 计算器地址
     * @param _isAuthorized 是否授权
     */
    function authorizeCalculator(address _calculator, bool _isAuthorized) external onlyOwner {
        authorizedCalculators[_calculator] = _isAuthorized;
        emit CalculatorAuthorized(_calculator, _isAuthorized);
    }

    /**
     * @dev 计算数据特征
     * @param _dataType 数据类型
     * @param _dataCount 数据点数量
     * @param _numericalFeatures 数值特征数组
     * @param _categoricalFeatures 分类特征数组
     * @return featureId 特征ID
     */
    function calculateDataFeatures(
        DataType _dataType,
        uint256 _dataCount,
        uint256[] memory _numericalFeatures,
        string[] memory _categoricalFeatures
    ) external onlyAuthorizedCalculator returns (bytes32) {
        require(_dataCount > 0, "Data count must be greater than 0");
        require(_numericalFeatures.length > 0 || _categoricalFeatures.length > 0, "Must have at least one feature");
        
        bytes32 featureId = keccak256(abi.encode(
            msg.sender,
            uint256(_dataType),
            _dataCount,
            _numericalFeatures,
            _categoricalFeatures,
            block.timestamp,
            nextFeatureId
        ));
        
        dataFeatures[featureId] = DataFeatures({
            dataType: _dataType,
            dataCount: _dataCount,
            numericalFeatures: _numericalFeatures,
            categoricalFeatures: _categoricalFeatures,
            timestamp: block.timestamp,
            featureHash: "",
            isCalculated: true,
            calculator: msg.sender
        });
        
        // Calculate feature hash
        dataFeatures[featureId].featureHash = _calculateFeatureHash(featureId);
        
        userCalculations[msg.sender].push(featureId);
        allFeatureIds.push(featureId);
        nextFeatureId++;
        
        emit FeaturesCalculated(featureId, msg.sender, _dataType, _dataCount);
        
        return featureId;
    }

    /**
     * @dev Internal function to calculate data features (for batch operations)
     * @param _dataType Data type
     * @param _dataCount Data point count
     * @param _numericalFeatures Numerical features array
     * @param _categoricalFeatures Categorical features array
     * @return featureId Feature ID
     */
    function _calculateDataFeaturesInternal(
        DataType _dataType,
        uint256 _dataCount,
        uint256[] memory _numericalFeatures,
        string[] memory _categoricalFeatures
    ) internal returns (bytes32) {
        require(_dataCount > 0, "Data count must be greater than 0");
        require(_numericalFeatures.length > 0 || _categoricalFeatures.length > 0, "Must have at least one feature");
        
        bytes32 featureId = keccak256(abi.encode(
            msg.sender,
            uint256(_dataType),
            _dataCount,
            _numericalFeatures,
            _categoricalFeatures,
            block.timestamp,
            nextFeatureId
        ));
        
        dataFeatures[featureId] = DataFeatures({
            dataType: _dataType,
            dataCount: _dataCount,
            numericalFeatures: _numericalFeatures,
            categoricalFeatures: _categoricalFeatures,
            timestamp: block.timestamp,
            featureHash: "",
            isCalculated: true,
            calculator: msg.sender
    });
        
        // Calculate feature hash
        dataFeatures[featureId].featureHash = _calculateFeatureHash(featureId);
        
        userCalculations[msg.sender].push(featureId);
        allFeatureIds.push(featureId);
        nextFeatureId++;
        
        emit FeaturesCalculated(featureId, msg.sender, _dataType, _dataCount);
        
        return featureId;
    }

    /**
     * @dev Update statistical metrics
     * @param _featureId Feature ID
     * @param _metrics Statistical metrics
     */
    function updateStatisticalMetrics(
        bytes32 _featureId,
        StatisticalMetrics memory _metrics
    ) external onlyAuthorizedCalculator featureExists(_featureId) {
        // 验证统计指标的合理性
        require(_validateStatisticalMetrics(_metrics), "Invalid statistical metrics");
        
        statisticalMetrics[_featureId] = _metrics;
        
        emit StatisticalMetricsUpdated(
            _featureId,
            _metrics.mean,
            _metrics.standardDeviation,
            _metrics.minValue,
            _metrics.maxValue
        );
    }

    /**
     * @dev 批量计算特征
     * @param _dataTypes 数据类型数组
     * @param _dataCounts 数据点数量数组
     * @param _numericalFeaturesArray 数值特征数组的数组
     * @param _categoricalFeaturesArray 分类特征数组的数组
     * @return featureIds 特征ID数组
     */
    function calculateMultipleFeatures(
        DataType[] memory _dataTypes,
        uint256[] memory _dataCounts,
        uint256[][] memory _numericalFeaturesArray,
        string[][] memory _categoricalFeaturesArray
    ) external onlyAuthorizedCalculator returns (bytes32[] memory) {
        require(_dataTypes.length == _dataCounts.length, "Array lengths must match");
        require(_dataTypes.length == _numericalFeaturesArray.length, "Array lengths must match");
        require(_dataTypes.length == _categoricalFeaturesArray.length, "Array lengths must match");
        
        bytes32[] memory featureIds = new bytes32[](_dataTypes.length);
        
        for (uint i = 0; i < _dataTypes.length; i++) {
            featureIds[i] = _calculateDataFeaturesInternal(
                _dataTypes[i],
                _dataCounts[i],
                _numericalFeaturesArray[i],
                _categoricalFeaturesArray[i]
            );
        }
        
        return featureIds;
    }

    /**
     * @dev 验证统计指标
     * @param _metrics 统计指标
     * @return 是否有效
     */
    function _validateStatisticalMetrics(StatisticalMetrics memory _metrics) internal pure returns (bool) {
        // 基本合理性检查
        if (_metrics.minValue > _metrics.maxValue) {
            return false;
        }
        
        if (_metrics.range != _metrics.maxValue - _metrics.minValue) {
            return false;
        }
        
        // 标准差和方差的合理性
        if (_metrics.variance != _metrics.standardDeviation * _metrics.standardDeviation) {
            return false;
        }
        
        // 偏度和峰度的范围检查
        if (_metrics.skewness > 100 || _metrics.kurtosis > 100) {
            return false;
        }
        
        return true;
    }

    /**
     * @dev 计算特征哈希
     * @param _featureId 特征ID
     * @return 特征哈希
     */
    function _calculateFeatureHash(bytes32 _featureId) internal view returns (string memory) {
        DataFeatures storage features = dataFeatures[_featureId];
        
        bytes32 hash = keccak256(abi.encode(
            uint256(features.dataType),
            features.dataCount,
            features.numericalFeatures,
            features.categoricalFeatures,
            features.timestamp
        ));
        
        return _bytes32ToHexString(hash);
    }

    /**
     * @dev 获取数据特征
     * @param _featureId 特征ID
     * @return 数据特征
     */
    function getDataFeatures(bytes32 _featureId) external view returns (DataFeatures memory) {
        return dataFeatures[_featureId];
    }

    /**
     * @dev 获取统计指标
     * @param _featureId 特征ID
     * @return 统计指标
     */
    function getStatisticalMetrics(bytes32 _featureId) external view returns (StatisticalMetrics memory) {
        return statisticalMetrics[_featureId];
    }

    /**
     * @dev 获取用户所有计算的特征ID
     * @param _user 用户地址
     * @return 特征ID数组
     */
    function getUserFeatureIds(address _user) external view returns (bytes32[] memory) {
        return userCalculations[_user];
    }

    /**
     * @dev 获取所有特征ID
     * @return 特征ID数组
     */
    function getAllFeatureIds() external view returns (bytes32[] memory) {
        return allFeatureIds;
    }

    /**
     * @dev 检查地址是否为授权计算器
     * @param _address 地址
     * @return 是否授权
     */
    function isAuthorizedCalculator(address _address) external view returns (bool) {
        return authorizedCalculators[_address];
    }

    /**
     * @dev 获取特征统计摘要
     * @param _featureId 特征ID
     * @return 统计摘要字符串
     */
    function getFeatureSummary(bytes32 _featureId) external view returns (string memory) {
        DataFeatures storage features = dataFeatures[_featureId];
        StatisticalMetrics storage metrics = statisticalMetrics[_featureId];
        
        if (!features.isCalculated) {
            return "Features not calculated";
        }
        
        string memory summary = string(abi.encodePacked(
            "DataType: ", _getDataTypeString(features.dataType),
            ", Count: ", features.dataCount.toString(),
            ", Mean: ", metrics.mean.toString(),
            ", StdDev: ", metrics.standardDeviation.toString()
        ));
        
        return summary;
    }

    /**
     * @dev 获取数据类型字符串
     * @param _dataType 数据类型
     * @return 数据类型字符串
     */
    function _getDataTypeString(DataType _dataType) internal pure returns (string memory) {
        if (_dataType == DataType.EXPERIMENTAL) return "Experimental";
        if (_dataType == DataType.STATISTICAL) return "Statistical";
        if (_dataType == DataType.TIME_SERIES) return "Time Series";
        if (_dataType == DataType.CATEGORICAL) return "Categorical";
        if (_dataType == DataType.NUMERICAL) return "Numerical";
        return "Unknown";
    }

    /**
     * @dev 计算数据质量分数
     * @param _featureId 特征ID
     * @return 质量分数 (0-100)
     */
    function calculateDataQualityScore(bytes32 _featureId) external view returns (uint256) {
        DataFeatures storage features = dataFeatures[_featureId];
        StatisticalMetrics storage metrics = statisticalMetrics[_featureId];
        
        if (!features.isCalculated) {
            return 0;
        }
        
        uint256 score = 0;
        
        // 数据完整性 (20分)
        if (features.dataCount > 0) score += 20;
        
        // 统计合理性 (30分)
        if (metrics.standardDeviation <= metrics.mean / 2) score += 30;
        else if (metrics.standardDeviation <= metrics.mean) score += 15;
        
        // 数据范围合理性 (25分)
        if (metrics.range > 0 && metrics.range < metrics.mean * 10) score += 25;
        else if (metrics.range > 0) score += 10;
        
        // 特征多样性 (25分)
        if (features.numericalFeatures.length >= 5) score += 25;
        else if (features.numericalFeatures.length >= 3) score += 15;
        else if (features.numericalFeatures.length >= 1) score += 10;
        
        return score;
    }

    /**
     * @dev Convert bytes32 to hex string
     * @param _bytes32 Bytes32 value
     * @return Hex string representation
     */
    function _bytes32ToHexString(bytes32 _bytes32) internal pure returns (string memory) {
        bytes memory bytesArray = new bytes(64);
        for (uint i = 0; i < 32; i++) {
            bytes1 b = bytes1(uint8(uint256(_bytes32) / (2**(8*(31 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            bytesArray[2*i] = _char(hi);
            bytesArray[2*i + 1] = _char(lo);
        }
        return string(bytesArray);
    }

    /**
     * @dev Convert byte to hex character
     * @param _b Byte value
     * @return Hex character
     */
    function _char(bytes1 _b) internal pure returns (bytes1) {
        if (uint8(_b) < 10) return bytes1(uint8(_b) + 0x30);
        else return bytes1(uint8(_b) + 0x57);
    }
} 