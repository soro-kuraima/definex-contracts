// script/Deploy.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/AlysNFT.sol";
import "../src/AlysNFTP2PMarket.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        

        // Deploy AlysNFT contract
        address deployer = vm.addr(deployerPrivateKey);
        AlysNFT alysNFT = new AlysNFT(deployer);
        console.log("AlysNFT deployed to:", address(alysNFT));

        // Deploy AlysNFTP2PMarket contract with AlysNFT address
        AlysNFTP2PMarket alysMarket = new AlysNFTP2PMarket(address(alysNFT));
        console.log("AlysNFTP2PMarket deployed to:", address(alysMarket));

        vm.stopBroadcast();
    }
}

