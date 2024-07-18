// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./AlysNFT.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "forge-std/console.sol";

contract AlysNFTP2PMarket is ReentrancyGuard {
    using Math for uint256;

    AlysNFT public nftContract;
    address public constant platformFeeRecipient = 0xD7609082E71F01C3B178269C76dF76E087307aAE;

    struct Listing {
        uint256 tokenId;
        address seller;
        uint256 price;
        bool isActive;
    }

    struct Offer {
        address buyer;
        uint256 amount;
        uint256 expirationTime;
    }

    struct LoanRequest {
        uint256[] tokenIds;
        address borrower;
        uint256 principal;
        uint256 interestRate;
        uint256 duration;
        uint256 totalValue;
        bool isActive;
    }

    struct LoanOffer {
        address lender;
        uint256 principal;
        uint256 interestRate;
        uint256 duration;
        uint256 expirationTime;
    }

    struct ActiveLoan {
        address borrower;
        address lender;
        uint256[] tokenIds;
        uint256 principal;
        uint256 interestRate;
        uint256 duration;
        uint256 startTime;
        bool isRepaid;
    }

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Offer) public offers;
    mapping(uint256 => LoanRequest) public loanRequests;
    mapping(uint256 => LoanOffer) public loanOffers;
    mapping(uint256 => ActiveLoan) public activeLoans;
    mapping(uint256 => uint256) public nftToActiveLoan;

    uint256 public constant OFFER_DURATION = 24 hours;
    uint256 public constant PLATFORM_FEE_PERCENTAGE = 250; // 2.5%
    uint256 public constant PERCENTAGE_BASE = 10000;
    uint256 public constant MAX_LTV_PERCENTAGE = 8500; // 85%

    uint256 private loanRequestCounter;
    uint256 private activeLoanCounter;

    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTUnlisted(uint256 indexed tokenId, address indexed seller);
    event OfferMade(uint256 indexed tokenId, address indexed buyer, uint256 amount);
    event OfferCancelled(uint256 indexed tokenId, address indexed buyer);
    event OfferAccepted(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 amount);
    event OfferRejected(uint256 indexed tokenId, address indexed buyer, uint256 amount);

    event LoanRequestCreated(uint256 indexed requestId, address indexed borrower, uint256 principal);
    event LoanOfferMade(
        uint256 indexed requestId, address indexed lender, uint256 principal, uint256 interestRate, uint256 duration
    );
    event LoanOfferAccepted(
        uint256 indexed loanId, address indexed borrower, address indexed lender, uint256 principal
    );
    event LoanOfferRejected(uint256 indexed requestId, address indexed lender, uint256 amount);
    event LoanRepaid(uint256 indexed loanId, address indexed borrower, uint256 amountRepaid);
    event CollateralClaimed(uint256 indexed loanId, address indexed lender);

    constructor(address _nftContractAddress) {
        nftContract = AlysNFT(_nftContractAddress);
    }

    function isNFTCollateral(uint256 _tokenId) public view returns (bool) {
        return nftToActiveLoan[_tokenId] != 0;
    }

    function listNFT(uint256 _tokenId, uint256 _price) external {
        require(nftContract.ownerOf(_tokenId) == msg.sender, "You don't own this NFT");
        require(nftContract.getApproved(_tokenId) == address(this), "Marketplace not approved");
        require(!isNFTCollateral(_tokenId), "NFT is currently used as collateral");

        listings[_tokenId] = Listing({tokenId: _tokenId, seller: msg.sender, price: _price, isActive: true});

        emit NFTListed(_tokenId, msg.sender, _price);
    }

    function unlistNFT(uint256 _tokenId) external {
        require(listings[_tokenId].seller == msg.sender, "You're not the seller");
        require(listings[_tokenId].isActive, "NFT not listed");

        delete listings[_tokenId];
        emit NFTUnlisted(_tokenId, msg.sender);
    }

    function makeOffer(uint256 _tokenId) external payable nonReentrant {
        require(listings[_tokenId].isActive, "NFT not listed");
        require(msg.value > 0, "Offer amount must be greater than 0");
        require(
            offers[_tokenId].buyer == address(0) || block.timestamp > offers[_tokenId].expirationTime,
            "Active offer exists"
        );

        offers[_tokenId] =
            Offer({buyer: msg.sender, amount: msg.value, expirationTime: block.timestamp + OFFER_DURATION});

        emit OfferMade(_tokenId, msg.sender, msg.value);
    }

    function acceptOffer(uint256 _tokenId) external nonReentrant {
        require(listings[_tokenId].seller == msg.sender, "You're not the seller");
        require(listings[_tokenId].isActive, "NFT not listed");
        require(offers[_tokenId].buyer != address(0), "No active offer");
        require(block.timestamp <= offers[_tokenId].expirationTime, "Offer expired");

        address buyer = offers[_tokenId].buyer;
        uint256 offerAmount = offers[_tokenId].amount;
        uint256 platformFee = offerAmount.mulDiv(PLATFORM_FEE_PERCENTAGE, PERCENTAGE_BASE);
        uint256 sellerProceeds = offerAmount - platformFee;

        nftContract.transferNFT(buyer, _tokenId);

        (bool successSeller,) = payable(msg.sender).call{value: sellerProceeds}("");
        require(successSeller, "Transfer to seller failed");

        (bool successPlatform,) = payable(platformFeeRecipient).call{value: platformFee}("");
        require(successPlatform, "Transfer of platform fee failed");

        delete listings[_tokenId];
        delete offers[_tokenId];

        emit OfferAccepted(_tokenId, msg.sender, buyer, offerAmount);
    }

    function rejectOffer(uint256 _tokenId) external nonReentrant {
        require(listings[_tokenId].isActive, "NFT not listed");
        require(listings[_tokenId].seller == msg.sender, "Not the seller");
        require(offers[_tokenId].buyer != address(0), "No active offer");
        require(block.timestamp <= offers[_tokenId].expirationTime, "Offer expired");

        address payable buyer = payable(offers[_tokenId].buyer);
        uint256 amount = offers[_tokenId].amount;

        (bool success,) = buyer.call{value: amount}("");
        require(success, "Failed to return funds to buyer");

        delete offers[_tokenId];

        emit OfferRejected(_tokenId, buyer, amount);
    }

    function createLoanRequest(uint256[] memory _tokenIds, uint256 _principal, uint256 _totalValue) external {
        require(_tokenIds.length > 0, "Must include at least one NFT");
        require(_principal > 0, "Principal must be greater than 0");
        require(_totalValue > 0, "Total value must be greater than 0");
        require(_principal <= _totalValue.mulDiv(MAX_LTV_PERCENTAGE, PERCENTAGE_BASE), "Loan-to-value ratio too high");

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(nftContract.ownerOf(_tokenIds[i]) == msg.sender, "You don't own this NFT");
            require(nftContract.getApproved(_tokenIds[i]) == address(this), "Marketplace not approved for NFT");
            require(!isNFTCollateral(_tokenIds[i]), "NFT is already used as collateral");
        }

        uint256 requestId = loanRequestCounter++;
        loanRequests[requestId] = LoanRequest({
            tokenIds: _tokenIds,
            borrower: msg.sender,
            principal: _principal,
            interestRate: 0,
            duration: 0,
            totalValue: _totalValue,
            isActive: true
        });

        emit LoanRequestCreated(requestId, msg.sender, _principal);
    }

    function makeLoanOffer(uint256 _requestId, uint256 _principal, uint256 _interestRate, uint256 _duration)
        external
        payable
    {
        require(loanRequests[_requestId].isActive, "Loan request not active");
        require(_duration > 0, "Duration must be greater than 0");
        require(msg.value == _principal, "Sent value must match the principal");

        LoanRequest storage request = loanRequests[_requestId];

        uint256 maxLoanAmount = request.totalValue.mulDiv(MAX_LTV_PERCENTAGE, PERCENTAGE_BASE);
        require(_principal <= maxLoanAmount, "Offer exceeds maximum LTV");
        require(_principal <= request.principal, "Offer exceeds requested principal");

        loanOffers[_requestId] = LoanOffer({
            lender: msg.sender,
            principal: _principal,
            interestRate: _interestRate,
            duration: _duration,
            expirationTime: block.timestamp + OFFER_DURATION
        });

        emit LoanOfferMade(_requestId, msg.sender, _principal, _interestRate, _duration);
    }

    function acceptLoanOffer(uint256 _requestId) external nonReentrant {
        LoanRequest storage request = loanRequests[_requestId];
        LoanOffer storage offer = loanOffers[_requestId];

        require(request.borrower == msg.sender, "You're not the borrower");
        require(request.isActive, "Loan request not active");
        require(offer.lender != address(0), "No active loan offer");
        require(block.timestamp <= offer.expirationTime, "Loan offer expired");

        uint256 loanId = activeLoanCounter++;
        activeLoans[loanId] = ActiveLoan({
            borrower: msg.sender,
            lender: offer.lender,
            tokenIds: request.tokenIds,
            principal: offer.principal,
            interestRate: offer.interestRate,
            duration: offer.duration,
            startTime: block.timestamp,
            isRepaid: false
        });

        for (uint256 i = 0; i < request.tokenIds.length; i++) {
            uint256 tokenId = request.tokenIds[i];
            require(!isNFTCollateral(tokenId), "NFT is already collateral for another loan");
            nftContract.transferNFT(address(this), tokenId);
            nftToActiveLoan[tokenId] = loanId;
        }

        request.isActive = false;

        (bool success,) = payable(msg.sender).call{value: offer.principal}("");
        require(success, "Transfer of loan principal failed");

        delete loanOffers[_requestId];

        emit LoanOfferAccepted(loanId, msg.sender, offer.lender, offer.principal);
    }

    function rejectLoanOffer(uint256 _requestId) external nonReentrant {
        LoanRequest storage request = loanRequests[_requestId];
        LoanOffer storage offer = loanOffers[_requestId];

        require(request.isActive, "Loan request not active");
        require(request.borrower == msg.sender, "Not the borrower");
        require(offer.lender != address(0), "No active loan offer");
        require(block.timestamp <= offer.expirationTime, "Loan offer expired");

        address payable lender = payable(offer.lender);
        uint256 amount = offer.principal;

        (bool success,) = lender.call{value: amount}("");
        require(success, "Failed to return funds to lender");
        delete loanOffers[_requestId];

        emit LoanOfferRejected(_requestId, lender, amount);
    }

    function repayLoan(uint256 _loanId) external payable nonReentrant {
        ActiveLoan storage loan = activeLoans[_loanId];
        require(loan.borrower == msg.sender, "You're not the borrower");
        require(!loan.isRepaid, "Loan already repaid");

        uint256 elapsedTime = block.timestamp - loan.startTime;
        uint256 actualDuration = elapsedTime > loan.duration ? loan.duration : elapsedTime;

        uint256 interest = calculateInterest(loan.principal, loan.interestRate, actualDuration);
        uint256 totalRepayment = loan.principal + interest;
        require(msg.value >= totalRepayment, "Insufficient repayment amount");

        loan.isRepaid = true;

        for (uint256 i = 0; i < loan.tokenIds.length; i++) {
            uint256 tokenId = loan.tokenIds[i];
            nftContract.transferNFT(msg.sender, tokenId);
            nftToActiveLoan[tokenId] = 0; // Clear the mapping
        }

        (bool success,) = payable(loan.lender).call{value: totalRepayment}("");
        require(success, "Transfer of repayment failed");

        if (msg.value > totalRepayment) {
            (bool refundSuccess,) = payable(msg.sender).call{value: msg.value - totalRepayment}("");
            require(refundSuccess, "Refund of excess payment failed");
        }

        emit LoanRepaid(_loanId, msg.sender, totalRepayment);
    }

    function claimCollateral(uint256 _loanId) external nonReentrant {
        ActiveLoan storage loan = activeLoans[_loanId];
        require(loan.lender == msg.sender, "You're not the lender");
        require(!loan.isRepaid, "Loan is repaid");
        require(block.timestamp > loan.startTime + loan.duration, "Loan duration not expired");

        for (uint256 i = 0; i < loan.tokenIds.length; i++) {
            uint256 tokenId = loan.tokenIds[i];
            nftContract.transferNFT(msg.sender, tokenId);
            nftToActiveLoan[tokenId] = 0; // Clear the mapping
        }

        loan.isRepaid = true;

        emit CollateralClaimed(_loanId, msg.sender);
    }

    function calculateInterest(uint256 _principal, uint256 _interestRate, uint256 _duration)
        internal
        pure
        returns (uint256)
    {
        return _principal.mulDiv(_interestRate, PERCENTAGE_BASE).mulDiv(_duration, 365 days);
    }

    function getActiveListing(uint256 _tokenId) external view returns (Listing memory) {
        require(listings[_tokenId].isActive, "NFT not listed");
        return listings[_tokenId];
    }

    function getActiveOffer(uint256 _tokenId) external view returns (Offer memory) {
        require(
            offers[_tokenId].buyer != address(0) && block.timestamp <= offers[_tokenId].expirationTime,
            "No active offer"
        );
        return offers[_tokenId];
    }

    function getLoanRequest(uint256 _requestId) external view returns (LoanRequest memory) {
        return loanRequests[_requestId];
    }

    function getLoanOffer(uint256 _requestId) external view returns (LoanOffer memory) {
        return loanOffers[_requestId];
    }

    function getActiveLoan(uint256 _loanId) external view returns (ActiveLoan memory) {
        return activeLoans[_loanId];
    }

    receive() external payable {}
}
