// BnetRefunder.sol
//
// owner can publish merkle roots every epoch committing to refund amounts per account
// merkle root can be updated retroactively but claimed indices will remain unclaimable
// no invariant checking is performed on-chain, owner responsible for validating amounts
//
// based on https://github.com/Uniswap/merkle-distributor/blob/master/contracts/MerkleDistributor.sol
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import {MerkleProof} from "./MerkleProof.sol";

contract BnetRefunder is MerkleProof {
    address public owner;
    mapping(uint256 => bytes32) public roots;
    mapping(uint256 => mapping(uint256 => uint256)) public claimedBitMap;
    uint256 epoch;

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function publish(uint256 epoch_, bytes32 root) external payable onlyOwner {
        // desire invariant msg.value = sum(leaf), but this is not checked here
        // if violated, race condition can occur
        // roots can be updated, but only for current epoch
        require(epoch_ >= epoch, "invalid epoch");
        if (epoch_ != epoch) epoch = epoch_;
        roots[epoch_] = root;
    }

    function claim(
        uint256 epoch_,
        uint256 index,
        address payable account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external {
        // check leaf wasn't claimed
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[epoch_][claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        require(claimedWord & mask == 0, "already claimed");

        // mark leaf as claimed
        claimedBitMap[epoch_][claimedWordIndex] = claimedWord | mask;

        // verify proof
        bytes32 leaf = keccak256(abi.encodePacked(index, account, amount));
        require(verifyProof(merkleProof, roots[epoch_], leaf), "invalid proof");

        // pay claim
        account.transfer(amount);
    }
}
