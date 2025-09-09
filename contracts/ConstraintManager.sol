// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title ConstraintManager
 * @dev Constraint management contract, implementing dynamic management of research data validation rules
 * Supports multiple constraint types, dynamic threshold adjustment and rule combination
 */
contract ConstraintManager is Ownable, ReentrancyGuard {
    using Strings for uint256;

    // Constraint category enumeration
    enum ConstraintCategory {
        STATISTICAL,      // Statistical constraints
        FORMAT,           // Format constraints
        RANGE,            // Range constraints
        RELATIONSHIP,     // Relationship constraints
        QUALITY,          // Quality constraints
        CUSTOM            // Custom constraints
    }

    // Constraint operator enumeration
    enum ConstraintOperator {
        EQUAL,             // Equal
        NOT_EQUAL,         // Not equal
        GREATER_THAN,      // Greater than
        GREATER_EQUAL,     // Greater than or equal
        LESS_THAN,         // Less than
        LESS_EQUAL,        // Less than or equal
        BETWEEN,           // Between
        NOT_BETWEEN,       // Not between
        CONTAINS,          // Contains
        NOT_CONTAINS       // Not contains
    }

    // Constraint structure
    struct Constraint {
        bytes32 constraintId;
        string name;
        string description;
        ConstraintCategory category;
        ConstraintOperator operator;
        uint256[] thresholds;      // Thresholds array
        bool isActive;
        uint256 priority;          // Priority (1-10, 10 highest)
        uint256 weight;            // Weight (0-100)
        string[] applicableFields; // Applicable fields
        uint256 createdAt;
        uint256 updatedAt;
        address creator;
        bool isGlobal;             // Whether it's a global constraint
    }

    // Constraint group structure
    struct ConstraintGroup {
        bytes32 groupId;
        string name;
        string description;
        bytes32[] constraintIds;
        bool isActive;
        uint256 minSatisfaction;   // Minimum satisfied constraints count
        uint256 totalWeight;       // Total weight
        uint256 createdAt;
        address creator;
    }

    // Validation rule structure
    struct ValidationRule {
        bytes32 ruleId;
        string name;
        string description;
        bytes32[] groupIds;
        uint256 minScore;          // Minimum passing score
        bool isActive;
        uint256 createdAt;
        address creator;
    }

    // State variables
    mapping(bytes32 => Constraint) public constraints;
    mapping(bytes32 => ConstraintGroup) public constraintGroups;
    mapping(bytes32 => ValidationRule) public validationRules;
    
    bytes32[] public constraintIds;
    bytes32[] public groupIds;
    bytes32[] public ruleIds;
    
    // Constraint type mappings
    mapping(ConstraintCategory => bytes32[]) public constraintsByCategory;
    mapping(string => bytes32[]) public constraintsByField;
    
    // Events
    event ConstraintCreated(
        bytes32 indexed constraintId,
        string name,
        ConstraintCategory category,
        address indexed creator
    );
    
    event ConstraintUpdated(
        bytes32 indexed constraintId,
        string name,
        bool isActive
    );
    
    event ConstraintGroupCreated(
        bytes32 indexed groupId,
        string name,
        uint256 constraintCount
    );
    
    event ValidationRuleCreated(
        bytes32 indexed ruleId,
        string name,
        uint256 minScore
    );
    
    event ConstraintEvaluated(
        bytes32 indexed constraintId,
        bool result,
        uint256 score
    );

    // Modifiers
    modifier constraintExists(bytes32 _constraintId) {
        require(constraints[_constraintId].constraintId != bytes32(0), "Constraint does not exist");
        _;
    }

    modifier groupExists(bytes32 _groupId) {
        require(constraintGroups[_groupId].groupId != bytes32(0), "Group does not exist");
        _;
    }

    modifier ruleExists(bytes32 _ruleId) {
        require(validationRules[_ruleId].ruleId != bytes32(0), "Rule does not exist");
        _;
    }

    modifier onlyCreatorOrOwner(bytes32 _constraintId) {
        require(
            constraints[_constraintId].creator == msg.sender || msg.sender == owner(),
            "Not creator or owner"
        );
        _;
    }

    constructor() Ownable(msg.sender) {
        _initializeDefaultConstraints();
    }

    /**
     * @dev Create constraint conditions
     * @param _name Constraint name
     * @param _description Constraint description
     * @param _category Constraint category
     * @param _operator Constraint operator
     * @param _thresholds Thresholds array
     * @param _priority Priority
     * @param _weight Weight
     * @param _applicableFields Applicable fields
     * @param _isGlobal Whether it's a global constraint
     * @return constraintId Constraint ID
     */
    function createConstraint(
        string memory _name,
        string memory _description,
        ConstraintCategory _category,
        ConstraintOperator _operator,
        uint256[] memory _thresholds,
        uint256 _priority,
        uint256 _weight,
        string[] memory _applicableFields,
        bool _isGlobal
    ) external returns (bytes32) {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(_priority >= 1 && _priority <= 10, "Priority must be 1-10");
        require(_weight >= 0 && _weight <= 100, "Weight must be 0-100");
        require(_thresholds.length > 0, "Thresholds cannot be empty");
        
        bytes32 constraintId = keccak256(abi.encodePacked(
            msg.sender,
            _name,
            block.timestamp
        ));
        
        constraints[constraintId] = Constraint({
            constraintId: constraintId,
            name: _name,
            description: _description,
            category: _category,
            operator: _operator,
            thresholds: _thresholds,
            isActive: true,
            priority: _priority,
            weight: _weight,
            applicableFields: _applicableFields,
            createdAt: block.timestamp,
            updatedAt: block.timestamp,
            creator: msg.sender,
            isGlobal: _isGlobal
        });
        
        constraintIds.push(constraintId);
        constraintsByCategory[_category].push(constraintId);
        
        // 添加到字段映射
        for (uint i = 0; i < _applicableFields.length; i++) {
            constraintsByField[_applicableFields[i]].push(constraintId);
        }
        
        emit ConstraintCreated(constraintId, _name, _category, msg.sender);
        
        return constraintId;
    }

    /**
     * @dev Internal function to create constraints (for initialization)
     * @param _name Constraint name
     * @param _description Constraint description
     * @param _category Constraint category
     * @param _operator Constraint operator
     * @param _thresholds Thresholds array
     * @param _priority Priority
     * @param _weight Weight
     * @param _applicableFields Applicable fields
     * @param _isGlobal Whether it's a global constraint
     * @return constraintId Constraint ID
     */
    function _createConstraintInternal(
        string memory _name,
        string memory _description,
        ConstraintCategory _category,
        ConstraintOperator _operator,
        uint256[] memory _thresholds,
        uint256 _priority,
        uint256 _weight,
        string[] memory _applicableFields,
        bool _isGlobal
    ) internal returns (bytes32) {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(_priority >= 1 && _priority <= 10, "Priority must be 1-10");
        require(_weight >= 0 && _weight <= 100, "Weight must be 0-100");
        require(_thresholds.length > 0, "Thresholds cannot be empty");
        
        bytes32 constraintId = keccak256(abi.encodePacked(
            address(this),
            _name,
            block.timestamp
        ));
        
        constraints[constraintId] = Constraint({
            constraintId: constraintId,
            name: _name,
            description: _description,
            category: _category,
            operator: _operator,
            thresholds: _thresholds,
            isActive: true,
            priority: _priority,
            weight: _weight,
            applicableFields: _applicableFields,
            createdAt: block.timestamp,
            updatedAt: block.timestamp,
            creator: address(this),
            isGlobal: _isGlobal
        });
        
        constraintIds.push(constraintId);
        constraintsByCategory[_category].push(constraintId);
        
        // Add to field mapping
        for (uint i = 0; i < _applicableFields.length; i++) {
            constraintsByField[_applicableFields[i]].push(constraintId);
        }
        
        emit ConstraintCreated(constraintId, _name, _category, address(this));
        
        return constraintId;
    }

    /**
     * @dev Update constraint conditions
     * @param _constraintId Constraint ID
     * @param _isActive Whether active
     * @param _priority Priority
     * @param _weight Weight
     */
    function updateConstraint(
        bytes32 _constraintId,
        bool _isActive,
        uint256 _priority,
        uint256 _weight
    ) external constraintExists(_constraintId) onlyCreatorOrOwner(_constraintId) {
        require(_priority >= 1 && _priority <= 10, "Priority must be 1-10");
        require(_weight >= 0 && _weight <= 100, "Weight must be 0-100");
        
        Constraint storage constraint = constraints[_constraintId];
        constraint.isActive = _isActive;
        constraint.priority = _priority;
        constraint.weight = _weight;
        constraint.updatedAt = block.timestamp;
        
        emit ConstraintUpdated(_constraintId, constraint.name, _isActive);
    }

    /**
     * @dev Create constraint group
     * @param _name Group name
     * @param _description Group description
     * @param _constraintIds Constraint IDs array
     * @param _minSatisfaction Minimum satisfied constraints count
     * @return groupId Group ID
     */
    function createConstraintGroup(
        string memory _name,
        string memory _description,
        bytes32[] memory _constraintIds,
        uint256 _minSatisfaction
    ) external returns (bytes32) {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(_constraintIds.length > 0, "Constraint IDs cannot be empty");
        require(_minSatisfaction > 0 && _minSatisfaction <= _constraintIds.length, "Invalid min satisfaction");
        
        bytes32 groupId = keccak256(abi.encodePacked(
            msg.sender,
            _name,
            block.timestamp
        ));
        
        uint256 totalWeight = 0;
        for (uint i = 0; i < _constraintIds.length; i++) {
            require(constraints[_constraintIds[i]].constraintId != bytes32(0), "Constraint does not exist");
            totalWeight += constraints[_constraintIds[i]].weight;
        }
        
        constraintGroups[groupId] = ConstraintGroup({
            groupId: groupId,
            name: _name,
            description: _description,
            constraintIds: _constraintIds,
            isActive: true,
            minSatisfaction: _minSatisfaction,
            totalWeight: totalWeight,
            createdAt: block.timestamp,
            creator: msg.sender
        });
        
        groupIds.push(groupId);
        
        emit ConstraintGroupCreated(groupId, _name, _constraintIds.length);
        
        return groupId;
    }

    /**
     * @dev Create validation rule
     * @param _name Rule name
     * @param _description Rule description
     * @param _groupIds Group IDs array
     * @param _minScore Minimum passing score
     * @return ruleId Rule ID
     */
    function createValidationRule(
        string memory _name,
        string memory _description,
        bytes32[] memory _groupIds,
        uint256 _minScore
    ) external returns (bytes32) {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(_groupIds.length > 0, "Group IDs cannot be empty");
        require(_minScore >= 0 && _minScore <= 100, "Min score must be 0-100");
        
        bytes32 ruleId = keccak256(abi.encodePacked(
            msg.sender,
            _name,
            block.timestamp
        ));
        
        for (uint i = 0; i < _groupIds.length; i++) {
            require(constraintGroups[_groupIds[i]].groupId != bytes32(0), "Group does not exist");
        }
        
        validationRules[ruleId] = ValidationRule({
            ruleId: ruleId,
            name: _name,
            description: _description,
            groupIds: _groupIds,
            minScore: _minScore,
            isActive: true,
            createdAt: block.timestamp,
            creator: msg.sender
        });
        
        ruleIds.push(ruleId);
        
        emit ValidationRuleCreated(ruleId, _name, _minScore);
        
        return ruleId;
    }

    /**
     * @dev 评估约束条件
     * @param _constraintId 约束ID
     * @param _fieldValue 字段值
     * @return 是否满足约束
     */
    function evaluateConstraint(
        bytes32 _constraintId,
        uint256 _fieldValue
    ) external view constraintExists(_constraintId) returns (bool) {
        Constraint storage constraint = constraints[_constraintId];
        
        if (!constraint.isActive) {
            return false;
        }
        
        return _evaluateConstraintValue(constraint, _fieldValue);
    }

    /**
     * @dev Evaluate constraint group
     * @param _groupId Group ID
     * @param _fieldNames Field names array
     * @param _fieldValues Field values array
     * @return Number of satisfied constraints
     */
    function evaluateConstraintGroup(
        bytes32 _groupId,
        string[] memory _fieldNames,
        uint256[] memory _fieldValues
    ) external view groupExists(_groupId) returns (uint256) {
        require(_fieldNames.length == _fieldValues.length, "Field names and values arrays must have same length");
        
        ConstraintGroup storage group = constraintGroups[_groupId];
        
        if (!group.isActive) {
            return 0;
        }
        
        uint256 satisfiedCount = 0;
        
        for (uint i = 0; i < group.constraintIds.length; i++) {
            Constraint storage constraint = constraints[group.constraintIds[i]];
            
            if (constraint.isActive) {
                // Check if there are applicable field values
                for (uint j = 0; j < constraint.applicableFields.length; j++) {
                    for (uint k = 0; k < _fieldNames.length; k++) {
                        if (keccak256(bytes(constraint.applicableFields[j])) == keccak256(bytes(_fieldNames[k]))) {
                            if (_fieldValues[k] > 0) {
                                if (_evaluateConstraintValue(constraint, _fieldValues[k])) {
                                    satisfiedCount++;
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return satisfiedCount;
    }

    /**
     * @dev Evaluate validation rule
     * @param _ruleId Rule ID
     * @param _fieldNames Field names array
     * @param _fieldValues Field values array
     * @return Whether validation passes
     */
    function evaluateValidationRule(
        bytes32 _ruleId,
        string[] memory _fieldNames,
        uint256[] memory _fieldValues
    ) external view ruleExists(_ruleId) returns (bool) {
        require(_fieldNames.length == _fieldValues.length, "Field names and values arrays must have same length");
        
        ValidationRule storage rule = validationRules[_ruleId];
        
        if (!rule.isActive) {
            return false;
        }
        
        uint256 totalScore = 0;
        uint256 maxPossibleScore = 0;
        
        for (uint i = 0; i < rule.groupIds.length; i++) {
            ConstraintGroup storage group = constraintGroups[rule.groupIds[i]];
            
            if (group.isActive) {
                uint256 satisfiedCount = this.evaluateConstraintGroup(rule.groupIds[i], _fieldNames, _fieldValues);
                uint256 groupScore = (satisfiedCount * 100) / group.constraintIds.length;
                totalScore += groupScore;
                maxPossibleScore += 100;
            }
        }
        
        if (maxPossibleScore == 0) {
            return false;
        }
        
        uint256 finalScore = (totalScore * 100) / maxPossibleScore;
        return finalScore >= rule.minScore;
    }

    /**
     * @dev 内部约束值评估函数
     * @param _constraint 约束条件
     * @param _value 字段值
     * @return 是否满足约束
     */
    function _evaluateConstraintValue(
        Constraint storage _constraint,
        uint256 _value
    ) internal view returns (bool) {
        if (_constraint.thresholds.length == 0) {
            return false;
        }
        
        if (_constraint.operator == ConstraintOperator.EQUAL) {
            return _value == _constraint.thresholds[0];
        } else if (_constraint.operator == ConstraintOperator.NOT_EQUAL) {
            return _value != _constraint.thresholds[0];
        } else if (_constraint.operator == ConstraintOperator.GREATER_THAN) {
            return _value > _constraint.thresholds[0];
        } else if (_constraint.operator == ConstraintOperator.GREATER_EQUAL) {
            return _value >= _constraint.thresholds[0];
        } else if (_constraint.operator == ConstraintOperator.LESS_THAN) {
            return _value < _constraint.thresholds[0];
        } else if (_constraint.operator == ConstraintOperator.LESS_EQUAL) {
            return _value <= _constraint.thresholds[0];
        } else if (_constraint.operator == ConstraintOperator.BETWEEN) {
            require(_constraint.thresholds.length >= 2, "BETWEEN requires 2 thresholds");
            return _value >= _constraint.thresholds[0] && _value <= _constraint.thresholds[1];
        } else if (_constraint.operator == ConstraintOperator.NOT_BETWEEN) {
            require(_constraint.thresholds.length >= 2, "NOT_BETWEEN requires 2 thresholds");
            return _value < _constraint.thresholds[0] || _value > _constraint.thresholds[1];
        }
        
        return false;
    }

    /**
     * @dev Initialize default constraints
     */
    function _initializeDefaultConstraints() internal {
        // Statistical constraints
        string[] memory statisticalFields = new string[](3);
        statisticalFields[0] = "mean";
        statisticalFields[1] = "standardDeviation";
        statisticalFields[2] = "dataCount";
        
        uint256[] memory thresholds1 = new uint256[](1);
        thresholds1[0] = 5; // 5%
        
        _createConstraintInternal(
            "Error Threshold",
            "Error threshold not exceeding 5%",
            ConstraintCategory.STATISTICAL,
            ConstraintOperator.LESS_EQUAL,
            thresholds1,
            8,
            30,
            statisticalFields,
            true
        );
        
        // Format constraints
        string[] memory formatFields = new string[](1);
        formatFields[0] = "dataCount";
        
        uint256[] memory thresholds2 = new uint256[](1);
        thresholds2[0] = 0;
        
        _createConstraintInternal(
            "Data Format",
            "Data point count must be greater than 0",
            ConstraintCategory.FORMAT,
            ConstraintOperator.GREATER_THAN,
            thresholds2,
            9,
            25,
            formatFields,
            true
        );
        
        // Range constraints
        string[] memory rangeFields = new string[](2);
        rangeFields[0] = "minValue";
        rangeFields[1] = "maxValue";
        
        uint256[] memory thresholds3 = new uint256[](2);
        thresholds3[0] = 0;
        thresholds3[1] = 1000000;
        
        _createConstraintInternal(
            "Value Range",
            "Value range must be between 0-1000000",
            ConstraintCategory.RANGE,
            ConstraintOperator.BETWEEN,
            thresholds3,
            7,
            20,
            rangeFields,
            true
        );
    }

    /**
     * @dev 获取约束详情
     * @param _constraintId 约束ID
     * @return 约束详情
     */
    function getConstraint(bytes32 _constraintId) external view returns (Constraint memory) {
        return constraints[_constraintId];
    }

    /**
     * @dev 获取约束组详情
     * @param _groupId 组ID
     * @return 约束组详情
     */
    function getConstraintGroup(bytes32 _groupId) external view returns (ConstraintGroup memory) {
        return constraintGroups[_groupId];
    }

    /**
     * @dev 获取验证规则详情
     * @param _ruleId 规则ID
     * @return 验证规则详情
     */
    function getValidationRule(bytes32 _ruleId) external view returns (ValidationRule memory) {
        return validationRules[_ruleId];
    }

    /**
     * @dev 获取所有约束ID
     * @return 约束ID数组
     */
    function getAllConstraintIds() external view returns (bytes32[] memory) {
        return constraintIds;
    }

    /**
     * @dev 获取所有组ID
     * @return 组ID数组
     */
    function getAllGroupIds() external view returns (bytes32[] memory) {
        return groupIds;
    }

    /**
     * @dev 获取所有规则ID
     * @return 规则ID数组
     */
    function getAllRuleIds() external view returns (bytes32[] memory) {
        return ruleIds;
    }

    /**
     * @dev 按类别获取约束
     * @param _category 约束类别
     * @return 约束ID数组
     */
    function getConstraintsByCategory(ConstraintCategory _category) external view returns (bytes32[] memory) {
        return constraintsByCategory[_category];
    }

    /**
     * @dev 按字段获取约束
     * @param _field 字段名
     * @return 约束ID数组
     */
    function getConstraintsByField(string memory _field) external view returns (bytes32[] memory) {
        return constraintsByField[_field];
    }
} 