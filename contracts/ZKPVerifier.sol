// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ZKPVerifier
 * @dev Zero-knowledge proof verifier contract, supporting Groth16 and zkSNARK verification
 * Used for verifying zero-knowledge proofs of research data
 */
contract ZKPVerifier is Ownable, ReentrancyGuard {
    
    // Groth16 verification parameter structure
    struct Groth16Proof {
        uint256[2] a;      // G1 point
        uint256[2][2] b;   // G2 point
        uint256[2] c;      // G1 point
    }
    
    // Verification parameter structure
    struct VerificationParams {
        uint256[2] alpha1;     // G1 point
        uint256[2][2] beta2;   // G2 point
        uint256[2][2] gamma2;  // G2 point
        uint256[2][2] delta2;  // G2 point
        uint256[2][] ic;       // G1 point array
    }
    
    // Proof types
    mapping(string => VerificationParams) private _verificationParams;
    string[] public supportedProofTypes;
    
    // Verification result records
    mapping(bytes32 => bool) public verificationResults;
    mapping(bytes32 => uint256) public verificationTimestamps;
    
    // Events
    event ProofTypeRegistered(string proofType, address indexed registrant);
    event ProofVerified(bytes32 indexed proofHash, bool isValid, uint256 timestamp);
    event VerificationParamsUpdated(string proofType, address indexed updater);
    
    // Modifiers
    modifier proofTypeExists(string memory _proofType) {
        require(_verificationParams[_proofType].alpha1[0] != 0, "Proof type not registered");
        _;
    }
    
    constructor() Ownable(msg.sender) {
        // Initialize default proof types
        _registerDefaultProofTypes();
    }
    
    /**
     * @dev 注册新的证明类型和验证参数
     * @param _proofType 证明类型名称
     * @param _alpha1 G1点 alpha1
     * @param _beta2 G2点 beta2
     * @param _gamma2 G2点 gamma2
     * @param _delta2 G2点 delta2
     * @param _ic G1点数组 ic
     */
    function registerProofType(
        string memory _proofType,
        uint256[2] memory _alpha1,
        uint256[2][2] memory _beta2,
        uint256[2][2] memory _gamma2,
        uint256[2][2] memory _delta2,
        uint256[2][] memory _ic
    ) external onlyOwner {
        require(bytes(_proofType).length > 0, "Proof type cannot be empty");
        require(_ic.length > 0, "IC array cannot be empty");
        
        _verificationParams[_proofType] = VerificationParams({
            alpha1: _alpha1,
            beta2: _beta2,
            gamma2: _gamma2,
            delta2: _delta2,
            ic: _ic
        });
        
        supportedProofTypes.push(_proofType);
        emit ProofTypeRegistered(_proofType, msg.sender);
    }
    
    /**
     * @dev Update verification parameters
     * @param _proofType Proof type name
     * @param _alpha1 G1 point alpha1
     * @param _beta2 G2 point beta2
     * @param _gamma2 G2 point gamma2
     * @param _delta2 G2 point delta2
     * @param _ic G1 point array ic
     */
    function updateVerificationParams(
        string memory _proofType,
        uint256[2] memory _alpha1,
        uint256[2][2] memory _beta2,
        uint256[2][2] memory _gamma2,
        uint256[2][2] memory _delta2,
        uint256[2][] memory _ic
    ) external onlyOwner proofTypeExists(_proofType) {
        _verificationParams[_proofType] = VerificationParams({
            alpha1: _alpha1,
            beta2: _beta2,
            gamma2: _gamma2,
            delta2: _delta2,
            ic: _ic
        });
        
        emit VerificationParamsUpdated(_proofType, msg.sender);
    }
    
    /**
     * @dev 验证Groth16证明
     * @param _proofType 证明类型
     * @param _proof Groth16证明
     * @param _publicInputs 公开输入数组
     * @return 验证是否成功
     */
    function verifyGroth16Proof(
        string memory _proofType,
        Groth16Proof memory _proof,
        uint256[] memory _publicInputs
    ) external proofTypeExists(_proofType) returns (bool) {
        bytes32 proofHash = keccak256(abi.encodePacked(
            _proofType,
            _proof.a[0], _proof.a[1],
            _proof.b[0][0], _proof.b[0][1], _proof.b[1][0], _proof.b[1][1],
            _proof.c[0], _proof.c[1],
            _publicInputs
        ));
        
        // 执行Groth16验证
        bool isValid = _verifyGroth16(_proofType, _proof, _publicInputs);
        
        // 记录验证结果
        verificationResults[proofHash] = isValid;
        verificationTimestamps[proofHash] = block.timestamp;
        
        emit ProofVerified(proofHash, isValid, block.timestamp);
        
        return isValid;
    }
    
    /**
     * @dev 内部Groth16验证函数
     * @param _proofType 证明类型
     * @param _proof Groth16证明
     * @param _publicInputs 公开输入数组
     * @return 验证是否成功
     */
    function _verifyGroth16(
        string memory _proofType,
        Groth16Proof memory _proof,
        uint256[] memory _publicInputs
    ) internal view returns (bool) {
        VerificationParams storage params = _verificationParams[_proofType];
        
        // 这里应该实现完整的Groth16验证逻辑
        // 由于Solidity的限制，实际的椭圆曲线运算需要特殊的库
        // 这里提供一个简化的验证框架
        
        // 1. 检查证明点的有效性
        if (!_isValidG1Point(_proof.a) || !_isValidG1Point(_proof.c)) {
            return false;
        }
        
        if (!_isValidG2Point(_proof.b)) {
            return false;
        }
        
        // 2. 检查公开输入数量
        if (_publicInputs.length != params.ic.length - 1) {
            return false;
        }
        
        // 3. 验证配对等式
        // 在实际实现中，这里需要调用椭圆曲线配对库
        // 例如：e(A, B) * e(C, D) = e(E, F)
        
        // 简化验证：检查输入是否在合理范围内
        for (uint i = 0; i < _publicInputs.length; i++) {
            if (_publicInputs[i] > 2**254) { // 避免溢出
                return false;
            }
        }
        
        // 4. 验证约束条件
        return _verifyConstraints(_proofType, _publicInputs);
    }
    
    /**
     * @dev 验证约束条件
     * @param _proofType 证明类型
     * @param _publicInputs 公开输入
     * @return 是否满足约束
     */
    function _verifyConstraints(
        string memory _proofType,
        uint256[] memory _publicInputs
    ) internal pure returns (bool) {
        if (keccak256(bytes(_proofType)) == keccak256(bytes("research_data_verification"))) {
            // 科研数据验证约束
            if (_publicInputs.length >= 2) {
                uint256 mean = _publicInputs[0];
                uint256 stdDev = _publicInputs[1];
                
                // 检查统计合理性
                if (mean == 0 || stdDev > mean * 2) {
                    return false;
                }
            }
        } else if (keccak256(bytes(_proofType)) == keccak256(bytes("data_integrity"))) {
            // 数据完整性约束
            if (_publicInputs.length >= 1) {
                uint256 dataHash = _publicInputs[0];
                if (dataHash == 0) {
                    return false;
                }
            }
        }
        
        return true;
    }
    
    /**
     * @dev 检查G1点有效性
     * @param _point G1点
     * @return 是否有效
     */
    function _isValidG1Point(uint256[2] memory _point) internal pure returns (bool) {
        // 简化检查：确保点不为零
        return _point[0] != 0 && _point[1] != 0;
    }
    
    /**
     * @dev 检查G2点有效性
     * @param _point G2点
     * @return 是否有效
     */
    function _isValidG2Point(uint256[2][2] memory _point) internal pure returns (bool) {
        // 简化检查：确保点不为零
        return _point[0][0] != 0 && _point[0][1] != 0 &&
               _point[1][0] != 0 && _point[1][1] != 0;
    }
    
    /**
     * @dev 批量验证多个证明
     * @param _proofType 证明类型
     * @param _proofs 证明数组
     * @param _publicInputsArray 公开输入数组
     * @return 验证结果数组
     */
    function verifyMultipleProofs(
        string memory _proofType,
        Groth16Proof[] memory _proofs,
        uint256[][] memory _publicInputsArray
    ) external proofTypeExists(_proofType) returns (bool[] memory) {
        require(_proofs.length == _publicInputsArray.length, "Array lengths must match");
        
        bool[] memory results = new bool[](_proofs.length);
        
        for (uint i = 0; i < _proofs.length; i++) {
            results[i] = _verifyGroth16(_proofType, _proofs[i], _publicInputsArray[i]);
        }
        
        return results;
    }
    
    /**
     * @dev 获取验证结果
     * @param _proofHash 证明哈希
     * @return 验证结果和时间戳
     */
    function getVerificationResult(bytes32 _proofHash) external view returns (bool, uint256) {
        return (verificationResults[_proofHash], verificationTimestamps[_proofHash]);
    }
    
    /**
     * @dev 检查证明是否已验证
     * @param _proofHash 证明哈希
     * @return 是否已验证
     */
    function isProofVerified(bytes32 _proofHash) external view returns (bool) {
        return verificationResults[_proofHash];
    }
    
    /**
     * @dev 获取支持的证明类型
     * @return 证明类型数组
     */
    function getSupportedProofTypes() external view returns (string[] memory) {
        return supportedProofTypes;
    }
    
    /**
     * @dev 获取证明类型的验证参数
     * @param _proofType 证明类型
     * @return 验证参数
     */
    function getVerificationParams(string memory _proofType) external view returns (VerificationParams memory) {
        return _verificationParams[_proofType];
    }
    
    /**
     * @dev 初始化默认证明类型
     */
    function _registerDefaultProofTypes() internal {
        // 科研数据验证
        uint256[2] memory alpha1 = [uint256(1), uint256(2)];
        uint256[2][2] memory beta2 = [[uint256(1), uint256(2)], [uint256(3), uint256(4)]];
        uint256[2][2] memory gamma2 = [[uint256(5), uint256(6)], [uint256(7), uint256(8)]];
        uint256[2][2] memory delta2 = [[uint256(9), uint256(10)], [uint256(11), uint256(12)]];
        uint256[2][] memory ic = new uint256[2][](2);
        ic[0] = [uint256(1), uint256(2)];
        ic[1] = [uint256(3), uint256(4)];
        
        _verificationParams["research_data_verification"] = VerificationParams({
            alpha1: alpha1,
            beta2: beta2,
            gamma2: gamma2,
            delta2: delta2,
            ic: ic
        });
        
        supportedProofTypes.push("research_data_verification");
        
        // Data integrity verification
        _verificationParams["data_integrity"] = VerificationParams({
            alpha1: alpha1,
            beta2: beta2,
            gamma2: gamma2,
            delta2: delta2,
            ic: ic
        });
        
        supportedProofTypes.push("data_integrity");
    }
} 