pragma solidity ^0.4.18;
import "./../installed_contracts/oraclize-api/contracts/usingOraclize.sol";
import "./../lib/solidity-stringutils/src/strings.sol";
import "./../lib/jsmnSol/contracts/JsmnSolLib.sol";

contract OctoBounty is usingOraclize {
    using strings for *;
    // Indicates weather collectAll is executing
    bool public isCollecting = false;
    address owner;
    
    string public github_repo;
    string public github_issue;
    bytes32[] public commits;
    
    
    bytes[] public contributorUsernames;
    

    string public fullQuery; //debug
    bytes32 public lastShaStr; //debug
    bytes32 public lastUsername; //debug
    string public lastResponse; //debug
    string public lastBio; //debug
    string public lastBioMatch; //debug

    struct Contributor {
        int statsTotals;
        bytes32 username;
        address receiveAddress;
    }
    
    mapping (bytes32 => Contributor) public contributorsMap;
    mapping (bytes32 => string) public commitsMap;
    int64 public nrContributors;    
    mapping (bytes32 => string) public contributorsTotals;
    
    uint8 constant private QUERY_ISSUE_STATE = 1;
    uint8 constant private QUERY_USER = 2;    
    uint8 constant private QUERY_COMMITS_LIST = 3;
    uint8 constant private QUERY_COMMIT = 4;
    uint8 constant private QUERY_COMMIT_TOTALS = 5;
    uint8 constant private QUERY_COMMIT_USER = 6;
    
    bool public isIssueClosed = false;
    
    enum State { Created, Locked, Inactive } // Enum
    
    mapping(bytes32=>bytes32) commitQueryHash;
    mapping(bytes32=>uint8) pendingQueries;
    mapping(bytes=>uint256) commitsStats;
    mapping(bytes32=>uint64) usersStats;
    mapping(bytes32=>string) usersAddresses;

    event LogBalanceSent(uint256 amount, address sent_address);
    event LogNewProvableQuery(bytes32 id, string description);
    event LogProvableQueryResult(string result);
    event LogProvableQueryFailed(string description);
    event LogBountyWinnerAddrNotFound(string description);
    event LogDebug(bytes32 description);


    function getLastResponse() public view returns(string) { return lastResponse; }
    function OctoBounty (string memory _github_repo, string memory _github_issue) public payable {
        OAR = OraclizeAddrResolverI(0x47ab5854516946ea6d21838B54E477D7a48B0cFf);
        owner = msg.sender;
        github_repo = _github_repo;
        github_issue = _github_issue;
    }
/*
    constructor (string memory _github_repo, string memory _github_issue) public payable {
	OAR = OraclizeAddrResolverI(0x6f485C8BF6fc43eA212E93BBF8ce046C7f1cb475);
        owner = msg.sender;
        github_repo = _github_repo;
        github_issue = _github_issue;
    }
  */  
    function kill() public {
        require(msg.sender == owner);
        selfdestruct(owner);
    }
    
    function collectAll() public payable {
        require(this.isCollecting == false);
        this.queryCommitsList();
    }
    
    function parseUserResponse(string memory _result) {
        uint ielement;
        string memory jsonElement;
        JsmnSolLib.Token[] memory tokens;
        uint actualNum;
        uint returnValue;
        JsmnSolLib.Token memory t;
        bytes32 username;
        bytes bio;
        string memory tmp;
        
        (returnValue, tokens, actualNum) = JsmnSolLib.parse(_result, 3);
        tmp = JsmnSolLib.getBytes(_result, tokens[1].start, tokens[1].end);
        assembly {
          username := mload(add(tmp, 32))
        }
        
        
        tmp = JsmnSolLib.getBytes(_result, tokens[2].start, tokens[2].end);
        /*
        assembly {
          bio := mload(add(tmp, 64))
        }*/
        
        
        
        
        strings.slice memory bio_slice = tmp.toSlice();
        lastBio = bio_slice.toString();
        bio_slice = bio_slice.find("ETH: ".toSlice()).beyond("ETH: ".toSlice());
        //bio_slice.until(bio_slice.copy().find(" ".toSlice()).beyond(" ".toSlice()));
        bio_slice.until(bio_slice.copy().find(" ".toSlice()));
        
        lastBioMatch = bio_slice.toString();
        usersAddresses[username] = bio_slice.toString();
        contributorsMap[username].receiveAddress = parseAddr(bio_slice.toString());
    }    
    
    function parseIssueStateResponse(string memory _state) {
        isIssueClosed = _state.toSlice().equals("closed".toSlice());
    }
    
    function parseCommitResponse(bytes32 _query_id, string memory _result)  public payable {
        lastResponse = _result;
        uint ielement;
        string memory jsonElement;
        JsmnSolLib.Token[] memory tokens;
        uint actualNum;
        uint returnValue;
        JsmnSolLib.Token memory t;
        bytes32 username;
        int statsTotals;
        string memory tmp;
        
        (returnValue, tokens, actualNum) = JsmnSolLib.parse(_result, 4); // deceremet read nodes to 2-3
        
        t = tokens[1];
        tmp = JsmnSolLib.getBytes(_result, t.start, t.end);
        assembly {
          username := mload(add(tmp, 32))
        }
        
        t = tokens[2];
        tmp = JsmnSolLib.getBytes(_result, t.start, t.end);
        assembly {
          statsTotals := mload(add(tmp, 32))
        }
        
        
        lastUsername = username;
        contributorsMap[username].username = username;
        contributorsMap[username].statsTotals += statsTotals;
        
        //commitsStats[bytes(shaStr)] = statsTotals;
    }
    
    function parseCommitsListResponse(string memory _result) {
        emit LogProvableQueryResult(_result);
        uint ielement;
        string memory jsonElement;
        JsmnSolLib.Token[] memory tokens;
        uint actualNum;
        uint returnValue;
        JsmnSolLib.Token memory t;
        bytes32 shaStr;
        uint256 statsTotals;

        string memory tmp;
        strings.slice memory tmp2;
        string memory tmp3;
        /*
        strings.slice memory bio_slice = bio.toSlice();
        bio_slice = bio_slice.find("ETH: ".toSlice()).beyond("ETH: ".toSlice());
        bio_slice.until(bio_slice.copy().find(" ".toSlice()).beyond(" ".toSlice()));
        usersAddresses[username] = bio_slice.toString();
        */
            
        (returnValue, tokens, actualNum) = JsmnSolLib.parse(_result, 7); // ONLY 7 entries
        
        //emit LogDebug(shaStr);
        for(ielement=0; ielement < actualNum; ielement++) {
            t = tokens[ielement];
           
            tmp = JsmnSolLib.getBytes(_result, t.start, t.end);
            tmp2 = tmp.toSlice().copy();
            tmp3 = tmp2.beyond(tmp.toSlice().rfind("/".toSlice())).toString();
            
            shaStr = '';
            assembly {
              shaStr := mload(add(tmp3, 32))
            }
            lastShaStr = shaStr;           
           
            //commits.push(bytes(JsmnSolLib.getBytes(_result, tokens[ielement].start, tokens[ielement].end)));
            //commitsMap[shaStr] = JsmnSolLib.getBytes(_result, tokens[ielement].start, tokens[ielement].end);
            commits.push(shaStr);
        }
    }   

    function __callback(bytes32 _myid,string memory _result) public {
        
        lastResponse = _result;
        emit LogProvableQueryResult(_result);
        if (msg.sender != oraclize_cbAddress()) revert();
        /*
        if (pendingQueries[_myid] == QUERY_ISSUE_STATE) {
            emit LogProvableQueryResult(_result);
            parseIssueStateResponse(_result);
            delete pendingQueries[_myid];
            return;
        }
        */
        if (pendingQueries[_myid] == QUERY_USER) {
            emit LogProvableQueryResult(_result);
            parseUserResponse(_result);
            delete pendingQueries[_myid];
            return;
        }
        
        if (pendingQueries[_myid] == QUERY_COMMIT) {
            emit LogProvableQueryResult(_result);
            parseCommitResponse(_myid, _result);
            delete pendingQueries[_myid];
            return;
        }
        if (pendingQueries[_myid] == QUERY_COMMITS_LIST) {
            emit LogProvableQueryResult(_result);
            parseCommitsListResponse(_result);
            delete pendingQueries[_myid];
            return;
        }
        
        //revert(); // Unknown
    }
    
    function queryCommit(bytes32 commit_hash) public payable {
        uint256 requiredGas = oraclize_getPrice("URL");
        if (requiredGas  > this.balance) {
            emit LogProvableQueryFailed(
                "Provable query was NOT sent, please add some ETH to cover for the query fee"
            );
        } else {
            //bytes32 queryId = oraclize_query("URL", "json(https://api.github.com/repos/vladfilimon/poloniex-market-spread/commits/6a901b52e417e945c30427b07ac1e1e).['author','stats'].['login','total']",6008955);
            //bytes32 queryId = oraclize_query("URL", string(abi.encodePacked("json(https://api.github.com/repos/", github_repo, '/commits/', commit_hash,").['author','stats'].['login','total']")),6008955);
            //bytes32 queryId = oraclize_query("URL", string(abi.encodePacked("json(https://api.github.com/repos/", github_repo, '/commits/', commit_hash,").['author','stats'].['login','total']")),6008955);
            fullQuery = string(abi.encodePacked("json(https://api.github.com/repos/", github_repo, "/commits/", commit_hash,").['author','stats'].['login','total']"));
            //return;
            bytes32 queryId = oraclize_query("URL", fullQuery, 6008955);
            emit LogNewProvableQuery(queryId, "Provable query was sent, standing by for the answer...");
            pendingQueries[queryId] = QUERY_COMMIT;
            commitQueryHash[queryId] = commit_hash;
            
        }
    }
    
    function queryCommitsList() public payable {
        uint256 requiredGas = oraclize_getPrice("URL");
        //this.balance = this.balance + msg.value;
        
        if (requiredGas > this.balance) {
            emit LogProvableQueryFailed(
                "Provable query was NOT sent, please add some ETH to cover for the query fee"
            );
        } else {
            bytes32 queryId = oraclize_query("URL", string(abi.encodePacked("json(https://api.github.com/repos/", github_repo, '/issues/', github_issue,"/events).$[?(@.event == 'referenced')].commit_url")),6008955/*7008955*/);
            emit LogNewProvableQuery(queryId, "Provable query was sent, standing by for the answer...");
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
            bytes32 queryId = oraclize_query("URL", string(abi.encodePacked("json(https://api.github.com/repos/", github_repo, '/issues/', github_issue,").state")));
            emit LogNewProvableQuery(queryId, "Provable query was sent, standing by for the answer...");
            pendingQueries[queryId] = QUERY_ISSUE_STATE;
        }
    }

    function queryUser(string memory username) public payable {
        uint256 requiredGas = oraclize_getPrice("URL");
        if (requiredGas > this.balance) {
            emit LogProvableQueryFailed(
                "Provable query was NOT sent, please add some ETH to cover for the query fee"
            );
        } else {
            bytes32 queryId = oraclize_query("URL", string(abi.encodePacked("json(https://api.github.com/users/", username, ").['login','bio']")), 6008955);
            emit LogNewProvableQuery(queryId, "Provable query was sent, standing by for the answer...");
            pendingQueries[queryId] = QUERY_USER;
        }
    }
}
