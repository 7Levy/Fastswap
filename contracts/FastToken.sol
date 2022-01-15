// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./utils/Ownable.sol";
import "./utils/Context.sol";
import "./libraries/Address.sol";
import "./interfaces/IERC20.sol";

/**
 * @dev ERC20代币的实现.
 * 分红机制-每笔交易5%给所有代币持有人，7%自动添加进流动性
 * 初始燃烧总量的50%
 * 流动性锁定
 * 预售后放弃所有权
 * @author @7Levy
 */

contract FastToken is Ownable,IERC20{
    using Address for address;

    string private constant _name = "Fastswap";
    string private constant _symbol = "Fast";
    uint8 private constant _decimals = 18;
    uint private _totalSupply;



    uint256 public constant taxFee=3;
    uint256 public constant liquidityFee=3;
    

    function _mint(address to,uint256 amount)internal {
        _totalSupply = _totalSupply.add(value);
        balanceOf[to]=balanceOf[to].add(value);
        emit Transfer(address(0),to,value);
    }

    function _burn(address from,uint value)internal{
        balanceOf[from]=balanceOf[from].sub(value);
        totalSupply=totalSupply.sub(value);
        emit Transfer(from,address(0),value);
    }

    function name()public view returns(string memory){
        return _name;
    }

    function symbol()public view returns(string memory){
        return _symbol;
    }
    function decimals()public view returns(uint8){
        return _decimals;
    }
    function totalSupply()public view returns(uint256){
        return _totalSupply;
    }
    
}