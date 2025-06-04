// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {BnetRefunder} from "../src/BnetRefunder.sol";
import {MerkleProof} from "../src/MerkleProof.sol";

contract ProofMaker is MerkleProof {
    bytes32[] proof_stack;

    function makeLeaves(address[] calldata accounts, uint256[] calldata amounts)
        public
        pure
        returns (bytes32[] memory leaves)
    {
        require(accounts.length == amounts.length);
        leaves = new bytes32[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            leaves[i] = keccak256(abi.encodePacked(i, accounts[i], amounts[i]));
        }
    }

    function nextTreeLevel(bytes32[] memory leaves) public pure returns (bytes32[] memory hashes) {
        require(leaves.length > 1);
        hashes = new bytes32[]((leaves.length + 1) / 2);
        for (uint256 i = 0; i < hashes.length - 1; i++) {
            // odd indices hash with left neighbour
            hashes[i] = commutativeKeccak256(leaves[2 * i], leaves[2 * i + 1]);
        }
        if (leaves.length % 2 == 0) {
            // even indices hash with right neighbour
            hashes[hashes.length - 1] = commutativeKeccak256(leaves[leaves.length - 2], leaves[leaves.length - 1]);
        } else {
            // right-pad with 0 for odd length leaves
            hashes[hashes.length - 1] = commutativeKeccak256(leaves[leaves.length - 1], bytes32(0));
        }
    }

    function makeProof(address[] calldata accounts, uint256[] calldata amounts, uint256 account_i)
        external
        returns (bytes32 root, bytes32[] memory proof)
    {
        // single-use contract because we use an in-storage stack to build proof
        require(proof_stack.length == 0);
        bytes32[] memory next = makeLeaves(accounts, amounts);
        while (next.length > 1) {
            if (account_i % 2 == 1) {
                // odd indices hash with left neighbour
                proof_stack.push(next[account_i - 1]);
            } else {
                if (account_i != next.length - 1) {
                    // even indices hash with right neighbour
                    proof_stack.push(next[account_i + 1]);
                } else {
                    // right-pad with 0 for odd length leaves
                    proof_stack.push(bytes32(0));
                }
            }
            // index in next level of tree
            account_i = account_i / 2;
            next = nextTreeLevel(next);
        }
        root = next[0];
        proof = proof_stack;
    }
}

// a humble Bnet user
contract Usr {
    BnetRefunder refunder;

    constructor(BnetRefunder refunder_) {
        refunder = refunder_;
    }

    receive() external payable {}

    function claim(uint256 epoch, uint256 index, uint256 amount, bytes32[] calldata merkleProof) external {
        refunder.claim(epoch, index, payable(address(this)), amount, merkleProof);
    }
}

contract BnetRefunderTest is Test {
    BnetRefunder public refunder;

    address payable ali;
    address payable bob;
    address payable cat;

    address[] accounts;
    uint256[] amounts;

    bytes32 root;

    function setUp() public {
        refunder = new BnetRefunder();

        ali = payable(address(new Usr(refunder)));
        bob = payable(address(new Usr(refunder)));
        cat = payable(address(new Usr(refunder)));

        accounts.push(ali);
        accounts.push(bob);
        accounts.push(cat);

        amounts.push(1 ether);
        amounts.push(2 ether);
        amounts.push(3 ether);

        // calculate root using ali's account (arbitrary)
        (root,) = (new ProofMaker()).makeProof(accounts, amounts, 0);
        refunder.publish{value: 6 ether}(0, root);
    }

    function test_basic_claims() public {
        (, bytes32[] memory aliProof) = (new ProofMaker()).makeProof(accounts, amounts, 0);

        assertEq(ali.balance, 0);
        Usr(ali).claim(0, 0, 1 ether, aliProof);
        assertEq(ali.balance, 1 ether);

        (, bytes32[] memory bobProof) = (new ProofMaker()).makeProof(accounts, amounts, 1);

        assertEq(bob.balance, 0);
        Usr(bob).claim(0, 1, 2 ether, bobProof);
        assertEq(bob.balance, 2 ether);

        (, bytes32[] memory catProof) = (new ProofMaker()).makeProof(accounts, amounts, 2);

        assertEq(cat.balance, 0);
        Usr(cat).claim(0, 2, 3 ether, catProof);
        assertEq(cat.balance, 3 ether);
    }

    function testRevert_no_claim_twice() public {
        (, bytes32[] memory bobProof) = (new ProofMaker()).makeProof(accounts, amounts, 1);

        Usr(bob).claim(0, 1, 2 ether, bobProof);
        vm.expectRevert();
        Usr(bob).claim(0, 1, 2 ether, bobProof);
    }

    function testRevert_no_claim_amount_greater() public {
        (, bytes32[] memory bobProof) = (new ProofMaker()).makeProof(accounts, amounts, 1);

        vm.expectRevert();
        Usr(bob).claim(0, 1, 3 ether, bobProof);
    }
}
