// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract ProxyAdmin is Ownable{
    
    //获取implementation的合约地址
    function getProxyImplementation(TransparentUpgradeableProxy proxy)public view virtual returns(address){
        // bytes4(keccak256("implementation()")) == 0x5c60da1b
        (bool success,bytes memory returndata)=address(proxy).staticcall(hex"5c60da1b");
        require(success);
        return abi.decode(returndata,(address));
    }

    //获取代理合约的管理员
    function getProxyAdmin(TransparentUpgradeableProxy proxy)public view virtual returns(address){
        (bool success,bytes memory returndata)=address(proxy).staticcall(hex"f851a440");
        require(success);
        return abi.decode(returndata,(address));
    }

    //修改代理合约的管理员
    function changeProxyAdmin(TransparentUpgradeableProxy proxy, address newAdmin) public virtual onlyOwner {
        proxy.changeAdmin(newAdmin);
    }

    //修改要代理的合约
    function upgrade(TransparentUpgradeableProxy proxy, address implementation) public virtual onlyOwner {
        proxy.upgradeTo(implementation);
    }
    
    function upgradeAndCall(TransparentUpgradeableProxy proxy,address implementation,bytes memory data)public payable virtual onlyOwner{
        proxy.upgradeToAndCall{value: msg.value}(implementation, data);
    }

}   