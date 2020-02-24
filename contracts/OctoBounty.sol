pragma solidity ^0.4.18;
import "./../installed_contracts/oraclize-api/contracts/usingOraclize.sol";
import "./../lib/solidity-stringutils/src/strings.sol";
import "./../lib/jsmnSol/contracts/JsmnSolLib.sol";

contract OctoBounty is usingOraclize {
    using strings for *;

    address owner;
    
    string public github_repo;
    string public github_issue;
    string[] public commits;
    
    uint16 constant private ISSUE_RETRY_TIME = 900;

    uint8 constant private QUERY_ISSUE = 1;
    uint8 constant private QUERY_USER = 2;    
    uint8 constant private QUERY_COMMITS_LIST = 3;
    uint8 constant private QUERY_COMMIT = 4;
    
    string public issue_url;
    bool public isIssueClosed = false;
    
    enum State { Created, Locked, Inactive } // Enum
  
    mapping(bytes32=>uint8) pendingQueries;
    mapping(bytes=>uint256) commitsStats;
    mapping(bytes32=>uint64) usersStats;
    mapping(bytes=>string) usersAddresses;

    event LogBalanceSent(uint256 amount, address sent_address);
    event LogNewProvableQuery(string description);
    event LogProvableQueryResult(string result);
    event LogProvableQueryFailed(string description);
    event LogBountyWinnerAddrNotFound(string description);

    constructor (string memory _github_repo, string memory _github_issue) public payable {
        owner = msg.sender;
        github_repo = _github_repo;
        github_issue = _github_issue;
    }
    
    function parseUserResponse(string memory _result) {
        uint ielement;
        string memory jsonElement;
        JsmnSolLib.Token[] memory tokens;
        uint actualNum;
        uint returnValue;
        JsmnSolLib.Token memory t;
        bytes memory username;
        string memory bio;
        
         (returnValue, tokens, actualNum) = JsmnSolLib.parse(_result, 100);
        
        for(ielement=0; ielement < actualNum-1; ielement++) {
            t = tokens[ielement];
            if (JsmnSolLib.getBytes(_result, t.start, t.end).toSlice().equals("login".toSlice())) {
                username = bytes(JsmnSolLib.getBytes(_result, tokens[ielement + 1].start, tokens[ielement + 1].end));
            }
            
            if (JsmnSolLib.getBytes(_result, t.start, t.end).toSlice().equals("bio".toSlice())) {
                bio = JsmnSolLib.getBytes(_result, tokens[ielement + 1].start, tokens[ielement + 1].end);
            }
        }
        
        
        strings.slice memory bio_slice = bio.toSlice();
        bio_slice = bio_slice.find("ETH: ".toSlice()).beyond("ETH: ".toSlice());
        bio_slice.until(bio_slice.copy().find(" ".toSlice()).beyond(" ".toSlice()));
        
        usersAddresses[username] = bio_slice.toString();
    }    
    
    function parseIssueResponse(string memory _result) {
        uint ielement;
        string memory jsonElement;
        JsmnSolLib.Token[] memory tokens;
        uint actualNum;
        uint returnValue;
        JsmnSolLib.Token memory t;
        string memory shaStr;
        
    
        (returnValue, tokens, actualNum) = JsmnSolLib.parse(_result, 100);
        t = tokens[1];
        shaStr = JsmnSolLib.getBytes(_result, t.start, t.end);
        strings.slice memory closedStr = "closed".toSlice();
        strings.slice memory nextslice;
        
        
        for(ielement=2; ielement < actualNum-1; ielement++) {
            if (JsmnSolLib.getBytes(_result, t.start, t.end).toSlice().equals("state".toSlice())) {
                nextslice = JsmnSolLib.getBytes(_result, tokens[ielement + 1].start, tokens[ielement + 1].end).toSlice(); 
                if (nextslice.equals(closedStr)) {
                    isIssueClosed = true;
                    break;
                }
            }
        }
                    
        if (!isIssueClosed) {
            //@TOO trigger again
        }
    }
    
    function parseCommitResponse(string memory _result) {
        uint ielement;
        string memory jsonElement;
        JsmnSolLib.Token[] memory tokens;
        uint actualNum;
        uint returnValue;
        JsmnSolLib.Token memory t;
        string memory shaStr;
        uint256 statsTotals;
            
        (returnValue, tokens, actualNum) = JsmnSolLib.parse(_result, 20);
        
        t = tokens[1];
        shaStr = JsmnSolLib.getBytes(_result, t.start, t.end);
        
        for(ielement=2; ielement < actualNum-1; ielement++) {
            t = tokens[ielement];
            if (JsmnSolLib.getBytes(_result, t.start, t.end).toSlice().equals("total".toSlice())) {
                statsTotals = parseInt(JsmnSolLib.getBytes(_result, tokens[ielement + 1].start, tokens[ielement + 1].end));
                break;
            }
        }
        
        commitsStats[bytes(shaStr)] = statsTotals;
    }    

    function __callback(bytes32 _myid,string memory _result) public {
        
        if (msg.sender != oraclize_cbAddress()) revert();

        uint ielement;
        string memory jsonElement;
        JsmnSolLib.Token[] memory tokens;
        uint actualNum;
        uint returnValue;
        JsmnSolLib.Token memory t;
        
        if (pendingQueries[_myid] == QUERY_ISSUE) {
            emit LogProvableQueryResult(_result);
            parseIssueResponse(_result);
            delete pendingQueries[_myid];
            return;
        }

        if (pendingQueries[_myid] == QUERY_USER) {
            emit LogProvableQueryResult(_result);
            parseUserResponse(_result);
            delete pendingQueries[_myid];
            return;
        }
        
        if (pendingQueries[_myid] == QUERY_COMMIT) {
            emit LogProvableQueryResult(_result);
            parseCommitResponse(_result);
            delete pendingQueries[_myid];
            return;
        }
        
        revert(); // Unknown
    }
    
    function queryCommit(uint256 commit_hash) public payable {
        uint256 requiredGas = oraclize_getPrice("URL");
        if (requiredGas  > this.balance) {
            emit LogProvableQueryFailed(
                "Provable query was NOT sent, please add some ETH to cover for the query fee"
            );
        } else {
            emit LogNewProvableQuery("Provable query was sent, standing by for the answer...");
            bytes32 queryId = oraclize_query("URL", string(abi.encodePacked("json(https://api.github.com/repos/", github_repo, '/commits/', commit_hash,")")));
            pendingQueries[queryId] = QUERY_COMMIT;
        }
    }
    
    function queryCommitsList() public payable {
        uint256 requiredGas = oraclize_getPrice("URL");
        if (requiredGas > this.balance) {
            emit LogProvableQueryFailed(
                "Provable query was NOT sent, please add some ETH to cover for the query fee"
            );
        } else {
            emit LogNewProvableQuery("Provable query was sent, standing by for the answer...");
            bytes32 queryId = oraclize_query("URL", string(abi.encodePacked("json(https://api.github.com/repos/", github_repo, '/commits/', github_issue,")")));
            pendingQueries[queryId] = QUERY_COMMITS_LIST;
        }
    }

    function queryIssue() public payable {
        uint256 requiredGas = oraclize_getPrice("URL");
        if (requiredGas > this.balance) {
            emit LogProvableQueryFailed(
                "Provable query was NOT sent, please add some ETH to cover for the query fee"
            );
        } else {
            emit LogNewProvableQuery("Provable query was sent, standing by for the answer...");
            bytes32 queryId = oraclize_query("URL", string(abi.encodePacked("json(https://api.github.com/repos/", github_repo, '/issues/', github_issue,")")));
            pendingQueries[queryId] = QUERY_ISSUE;
        }
    }

    function queryUser(string memory username) public payable {
        uint256 requiredGas = oraclize_getPrice("URL");
        if (requiredGas > this.balance) {
            emit LogProvableQueryFailed(
                "Provable query was NOT sent, please add some ETH to cover for the query fee"
            );
        } else {
            emit LogNewProvableQuery("Provable query was sent, standing by for the answer...");
            bytes32 queryId = oraclize_query("URL", string(abi.encodePacked("json(https://api.github.com/users/", username, ")")));
            pendingQueries[queryId] = QUERY_USER;
        }
    }
}
