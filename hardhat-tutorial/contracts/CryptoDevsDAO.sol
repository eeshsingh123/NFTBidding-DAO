// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

//interfaces goes here

interface IFakeNFTMarketplace {
    function getPrice() external view returns(uint256);

    function available(uint256 _tokenId) external view returns(bool);

    function purchase(uint256 _tokenId) external payable;
}

interface ICryptoDevsNFT {
    /// @dev balanceOf returns the number of NFTs owned by the given address
    /// @param owner - address to fetch number of NFTs for
    /// @return Returns the number of NFTs owned
    function balanceOf(address owner) external view returns (uint256);

    /// @dev tokenOfOwnerByIndex returns a tokenID at given index for owner
    /// @param owner - address to fetch the NFT TokenID for
    /// @param index - index of NFT in owned tokens array to fetch
    /// @return Returns the TokenID of the NFT
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
    
}


// actual contract
contract CryptoDevsDAO is Ownable {

    struct Proposal {
        uint256 nftTokenId;
        uint256 deadline;
        uint256 yayvotes;
        uint256 nayvotes;
        bool executed;

        mapping(uint256 => bool) voters;
    }

    mapping(uint256 => Proposal) public proposals;
    uint256 public numProposals;

    enum Vote {YAY, NAY} // YAY = 0, NAY = 1 Enums directly represent the idx of the element it has

    IFakeNFTMarketplace nftMarketplace;
    ICryptoDevsNFT cryptoDevsNFT;

    constructor(address _nftMarketplace, address _cryptoDevsNFT) payable {
        nftMarketplace = IFakeNFTMarketplace(_nftMarketplace);
        cryptoDevsNFT = ICryptoDevsNFT(_cryptoDevsNFT);
    }

    // makes sure that only the holders of nft can do certain operations
    modifier nftHolderOnly() {
        require(cryptoDevsNFT.balanceOf(msg.sender) > 0, "NOT A DAO MEMBER");
        _;
    }

    modifier activeProposalOnly(uint256 proposalIndex) {
        require(proposals[proposalIndex].deadline > block.timestamp, "DEADLINE_EXCEEDED");
        _;
    }

    modifier inactiveProposalOnly(uint256 proposalIndex) {
        require(proposals[proposalIndex].deadline <= block.timestamp, "DEADLINE_NOT_EXCEEDED");
        require(proposals[proposalIndex].executed == false, "PROPOSAL_ALREADY_EXECUTED");
        _;
    }

    function createProposal(uint256 _nftTokenId) external nftHolderOnly returns(uint256) {
        
        // the NFT should be available on the marketplace to create a proposal
        require(nftMarketplace.available(_nftTokenId), "NFT_NOT_FOR_SALE");

        // initializing the Proposal structure and adding it to the map for tracking
        Proposal storage proposal = proposals[numProposals];
        
        proposal.nftTokenId = _nftTokenId;
        proposal.deadline = block.timestamp + 5 minutes;

        // incrementing since we just created a proposal
        numProposals++;

        return numProposals - 1;
    }

    function voteOnProposal(uint256 proposalIndex, Vote vote) 
        external
        nftHolderOnly
        activeProposalOnly(proposalIndex)
    {
        Proposal storage proposal = proposals[proposalIndex];

        uint256 voterNFTBalance = cryptoDevsNFT.balanceOf(msg.sender);
        uint256 numVotes = 0;

        for (uint i = 0; i< voterNFTBalance; i++) {
            uint256 tokenId = cryptoDevsNFT.tokenOfOwnerByIndex(msg.sender, i);
            if (proposal.voters[tokenId] == false){
                numVotes++;
                proposal.voters[tokenId] = true;
            }
        }

        require(numVotes > 0, "ALREADY_VOTED");

        if (vote == Vote.YAY) {
            proposal.yayvotes += numVotes;
        } else {
            proposal.nayvotes += numVotes;
        }

    }

    function executeProposal(uint256 proposalIndex)
        external
        nftHolderOnly
        inactiveProposalOnly(proposalIndex)
    {
        Proposal storage proposal = proposals[proposalIndex];

        if (proposal.yayvotes > proposal.nayvotes) {
            uint256 nftPrice = nftMarketplace.getPrice();
            require(address(this).balance >= nftPrice, "NOT_ENOUGH_FUNDS");
            nftMarketplace.purchase{value: nftPrice}(proposal.nftTokenId);
        }
        proposal.executed = true;

    }

    function withdrawEther() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    receive() external payable {}

    fallback() external payable {}




}