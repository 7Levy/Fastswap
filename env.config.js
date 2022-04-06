// 变量文件envs/.env.${NODE_ENV}
// 运行时指定环境变量node your_script.js --node-env=test
// 切换环境变量 BASH：export NODE_ENV=${env_name}
require('dotenv-flow').config({ path: 'envs/', default_node_env: 'test', silent: true });


// 网络
const rpcs = {
    dxt: "https://testnet-rpc.dxchain.com",
    rinkeby: "https://rinkeby.infura.io/v3/a52857edcc904d6dbae349e4a5ade517"
}
// 地址及私钥
const accounts = process.env.ACCOUNTS ? process.env.ACCOUNTS.split(",") : []
const accountsKeys = process.env.PRIVATE_KEYS ? process.env.PRIVATE_KEYS.split(",") : []
const contractAddress = {
    People: "0x28da7558c7b7bD6Ff9a6F0dFE6F767809ECd2afa"
}
module.exports = { rpcs, accounts, accountsKeys, contractAddress }


