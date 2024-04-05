// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AirdropCDFi {
    using SafeERC20 for IERC20;

    
    bool private distributed;
    IERC20 private token;

    address[] public addresses = [
        0x6224fe0c8067ddb65c8c45eed7c0636511a0f98b,
        0xb6d49402a1bd678dea613cd5521e7d05996d1f18,
        0xb60b0ada4c9ac97cffc84c46d49a0f423c7d181a,
        0x8de6b37f068a571b121fd3e46854d85b10ad87ea,
        0x05708a2e03e979cfa4e2920a6d4dcfbd9fb35d00,
        0xa03c3363df7c84050497b2be8650778673d35b0d,
        0xa8bd03efc349a7c3bdd6095bbd82ba7f1d61da20,
        0x048c10bd59fb29909590c3ce3f37e72f67692aa7,
        0x7a9803f2450e948f63bba32834792ce7aab02515,
        0x4a80abd84dcf1a4d76a2480560229b2ea6d813ac,
        0x0a2265562dae017aa3c19a960cebf98208154b97,
        0xfdfbea492bcb16deb4b1390ea1a3c41464806cbe,
        0x9afc905bfd9dab0ded4359e69b02a859d59b9948,
        0x499dfebb3f0f9375259639dd891bd2ec2aee7496,
        0x000000d40b595b94918a28b27d1e2c66f43a51d3,
        0x24a0c28590950339e46e7da7599765e792752d47,
        0xc68bff79073939c96c8edb1c539b5362be1f64d1,
        0xa47bea3bbfc9a9655e1cad064217d7eb0dcdc579,
        0xbbb216c39ef6ba5409e00e1106ceb1e1aa8a93fb,
        0xaa19b882581723d15034d1e00fb7c6d96acb3710,
        0x000000000000000000000000000000000000dead,
        0x51f52b654379d52d818b38d01233ae2929731721,
        0x78a8dc82c569164605523fbe0b0e763e65f3f033,
        0xaa9cc0fbb75a8cf38327ecaa664c955d75ea70d1,
        0xfb30bed32bca83add1795523234c0e28e0ee48c2,
        0x17b4eaf8010464f9e1b50d598b2e527b4c78e3aa,
        0x420eb87916504753d1e5aa099f3f24a914f9cf26,
        0xf54d276a029a49458e71167ebc25d1cca235ee6f,
        0x725db39f95f32ac03a5f57b8f85e0d8153645aee,
        0x1a4b77aa33f0fcbde2f1a6bdad2004cf938c34b0,
        0x9ce55e2526dfed59085fcb34ae7404fbf0bb29f1,
        0xbecc6278460e04d4eecb6c697ab942f0a8b69ed8,
        0x08af33926b856a5ddc4321fb683805aeb1459896,
        0x4595f404a77ccbda2b5772f28f36b43b20a8f020,
        0x4b9987880ff764c8382cf7de48de4fea5ebf1b52,
        0xf14a244bbbe0a48c6e89017f845030913363881f,
        0x01586990e0a766c70a0f21501f2f514d76e0a4ad,
        0xb8217e5fc22ca5a2aa1e656e0a3aa1511cc4a945,
        0x80b0e01a8c13ac5ba58a3d57c7dfe1f1a99c48af,
        0xb80ba09657c6e162bf03f2f97c8c4c1892d30a84,
        0xaca3e9d3e32a9ab2df4830e83a9abe5c97cd9e30,
        0xcfefd76130ff72781613c9b5530706550695c986,
        0x0da2a82ed2c387d1751ccbaf999a80b65bdb269e,
        0x6b75d8af000000e20b7a7ddf000ba900b4009a80,
        0x4736b02db015dcd1a57a69c889d073b100000000
    ];
    uint256[] public values = [
        57800248750908574266176,
        27291019758922841089771,
        22616284412125624601890,
        14660523545836409992494,
        14097103744306931467567,
        12506745220974664779844,
        11435253847812598876320,
        10607852471034458955628,
        10604535176883997851139,
        10604500000000000000000,
        10039335245576952729504,
        6626372663145083348647,
        5255502413526145095231,
        4389275259453442435084,
        3810428087968807862994,
        2897706169314947469328,
        2823089871094586371570,
        2127781180713632008560,
        2101943961259267058275,
        2001599947896968772943,
        1996632109872167622124,
        1628662807017911572007,
        1077529210641288323708,
        903348847922748137381,
        854182952618537471229,
        851963464797227812428,
        851700036027439395643,
        696778534518294115611,
        543566901723027719664,
        505079698319372727222,
        500115968423940491485,
        390540124122935372931,
        369924826929873768161,
        367344555293248942643,
        329620342205840761917,
        294427963064309945061,
        259230427478622097522,
        213337396304426542889,
        213233552942484885187,
        167891312231666069076,
        100000000000000000000,
        68836378202384910906,
        207130526185711868,
        9563214757824839,
        412078079825260
    ];

    constructor(address _tokenAddress, address _owner) Ownable(_owner) {
        token = IERC20(_tokenAddress);
    }

    function distributeTokens() public onlyOwner {
        require(addresses.length == values.length, "Mismatched arrays");
        require(!distributed, "Distribution allowed only once");
        
        for (uint256 i = 0; i < addresses.length; i++) {
            token.safeTransfer(addresses[i], values[i]);
        }
    }
}
