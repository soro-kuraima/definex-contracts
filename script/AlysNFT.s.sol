// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/AlysNFT.sol";
import "../src/AlysNFTMarketplace.sol";

contract AlysNFTScript is Script {
    function run() external {
        // Retrieve the private key from the environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the AlysNFT contract
        // The msg.sender (derived from the private key) will be set as the initial owner
        AlysNFT alysNFT = new AlysNFT(vm.addr(deployerPrivateKey));

        console.log("AlysNFT deployed at:", address(alysNFT));

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}
