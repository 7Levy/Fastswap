// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";



contract Logic is Initializable,OwnableUpgradeable{
    
    function initialize()public initializer{
        __Context_init_unchained();
        __Ownable_init_unchained();
    }
    uint256 private peopleAge;

    function getPeopleAge()public pure returns(uint256){
        return 18;
    }
    
}



