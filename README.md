# octo-bounty
Octo-bounty is a truly decentralised Ethereum bounty system for open-source projects hosted on Github. 

## A few words:
At the moment bounties can only be added for issues opened on public repositories. 

A octo-bounty in itself is a distinct smart contract written in Solidity containing funds. Deploying the contract would require two arguments being sent: the github repository name and the issue number. 
The bounty value is the contract balance, minues the costs required for performing the checks. These checks are perfomed through an oracle service (Oraclize, now provable-things). 

It is recommended to paste a link to the deployed smart contract on a block explorer in the github issue description so contributors can look at the contract and be assured that the funds are there.  
There is no cancelling functionality for the bounty. This is by design, as it assures contributors the maintainer would not remove the placed bounty, regardless of issue state or pull requests being merged in or not.
Deleting the github issue would also not help, as the mentainer still be unable to withdraw the funds deployed as the bounty. This should encourage mentainers to pay the contributors for the pushed work. 
Before placing the bounty, make sure the repo and issue strings are correct.

## How it works:
When the github issue is closed and a pull request has been merged, the .collectAll() method of the contract can be called.
This will:
 - check if the issue state is closed
 - gather all referenced commits
 - try to find ETH address of each contributor
 - calculate the contribution percentt of each contributor with ETH address associated
 - Send the respective bounty percents to the contributors

The logic above is possible through use of oracle services. Internally, the contract relies on the use of oracle services provided by Oraclize to perform API calls to github in order to gather the required data.
Once the issue is closed and referenced by commit messages, the contract would need to query for these commits in order to calculate each contributor's share of the bounty. In order for a contributor to be counted, he/she would need to update his github bio to contain a 'ETH: ETH_ADDRESS' string 

## What is required of contributors (bounty receivers)
The contributors should modify the 'Bio' section of their github account profile in order to provide their ETH receive address.
As string parsing in Solidity is expensive, this string should be placed at the beginning of ther biography section like so:

ETH: 0x881f83D5317a12903472b89ccc54475e2a682d8d
Software developer, crypto enthusiast

Make sure the address is a valid and mainnet one, no further checks would be perfomend on it.

## Motivation:
While there are other systems for placing bounties for github issues, none of the existing solutions is fully transparent and decentralized;
The Octo-Bounty contract does not rely on 3rd parties or other platforms, apart from the oracle service and the github api itself.
There is no fee, apart from that required by the oracle service and the network itself,
On most open-sourced projects, issues can lie opened for quite a long time; Depending on 3rd party platforms could leave the bounty unretrivable.
Apart from reability  

## Authors
* **Vlad Filimon** - [VladFilimon](https://github.com/vladfilimon)

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details

## Acknowledgments

* [Oraclize - now provable-things](https://github.com/provable-things/ethereum-api)
* [Chrisdotn - for the amazing jsmnSol library](https://github.com/chrisdotn/jsmnSol)
* [Nick Johnson - for the very useful solidity-stringutils library](https://github.com/Arachnid/solidity-stringutils)
