pragma solidity ^0.4.22;
import "github.com/provable-things/ethereum-api/provableAPI_0.4.25.sol";
import "github.com/Arachnid/solidity-stringutils/strings.sol";

contract OctoBounty is usingProvable {
    using strings for *;

    address owner;
    address public bountyWinnerAddr;
    
    string public github_repo;
    string public github_issue;

    uint8 constant private QUERY_TYPE_ISSUE = 1;
    uint8 constant private QUERY_TYPE_USER = 2;

    string issue_url;
    string public username;

    mapping(bytes32=>uint8) pendingQueries;

    event LogBalanceSent(uint256 amount, address sent_address);
    event LogNewProvableQuery(string description);
    event LogProvableQueryResult(string result);
    event LogProvableQueryFailed(string description);
    event LogBountyWinnerAddrNotFound(string description);

    constructor (string memory _github_repo, string memory _github_issue) public payable {
        owner = msg.sender;
        github_repo = _github_repo;
        github_issue = _github_issue;
        //checkIssue();
    }

    function __callback(
        bytes32 _myid,
        string memory _result
    )
        public
    {
        
        if (msg.sender != provable_cbAddress()) revert();

        if (pendingQueries[_myid] == QUERY_TYPE_ISSUE) {
            username = _result;
            emit LogProvableQueryResult(_result);
            delete pendingQueries[_myid];
            return;
        }

        if (pendingQueries[_myid] == QUERY_TYPE_USER) {
            emit LogProvableQueryResult(_result);
            strings.slice memory bio = _result.toSlice();
            bio = bio.find("ETH: ".toSlice()).beyond("ETH: ".toSlice());
            bio.until(bio.copy().find(" ".toSlice()).beyond(" ".toSlice()));
            
            //if (!bio.empty()) {
                bountyWinnerAddr = parseAddr(bio.toString());
            //}
            delete pendingQueries[_myid];
            return;
        }
        
        revert(); // Unknown
    }
    
    function sendToBountyWinnerAddr() public payable {
        if (bountyWinnerAddr == address(0)) {
            
            emit LogBountyWinnerAddrNotFound(
                "Bounty winner address not found. Make sure the winner's github bio page contains the string 'ETH: {YOUR_ETH_ADDRESS}' and call again checkUserDepositAddress()"
            );
            revert();
        }
        
        bountyWinnerAddr.transfer(this.balance);
        emit LogBalanceSent(this.balance, bountyWinnerAddr);
    }

    function checkIssue() public payable {
        uint256 requiredGas = provable_getPrice("URL");
        if (requiredGas > this.balance) {
            emit LogProvableQueryFailed(
                "Provable query was NOT sent, please add some ETH to cover for the query fee"
            );
        } else {
            emit LogNewProvableQuery("Provable query was sent, standing by for the answer...");
            //https://api.github.com/repos/vladfilimon/poloniex-market-spread/issues/9
            bytes32 queryId = provable_query("URL", string(abi.encodePacked("json(https://api.github.com/repos/", github_repo, '/issues/', github_issue,").closed_by.login")));
            pendingQueries[queryId] = QUERY_TYPE_ISSUE;
        }
    }

    function checkUserDepositAddress() public payable {
        uint256 requiredGas = provable_getPrice("URL");
        if (requiredGas > this.balance) {
            emit LogProvableQueryFailed(
                "Provable query was NOT sent, please add some ETH to cover for the query fee"
            );
        } else {
            emit LogNewProvableQuery("Provable query was sent, standing by for the answer...");
            bytes32 queryId = provable_query("URL", string(abi.encodePacked("json(https://api.github.com/users/", username, ").bio")));
            pendingQueries[queryId] = QUERY_TYPE_USER;
        }
    }
}
